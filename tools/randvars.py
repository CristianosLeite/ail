"""Check generated code with random programs whose result is computed here.

Usage: randvars.py <compiler> <count> <seed> [top]

Each program is arithmetic on up to 40 variables with nested loops and
blocks, in a function or (with "top") at top level. It is written twice
from one tree: with statements (`add a b as x`, labels and jumps) and
with expressions (`x=a+b`, `x+=e`, `while`, `if` on a comparison). The
same tree is run in Python, with 64-bit wrapping, to get the exit status
that both must give, so the expected result does not come from a
compiler. A program that fails is kept as
build/randvars/seed<seed>[-top]-<n>-<form>.ai. `make test` runs it with a
fixed seed in both modes.
"""
import os
import random
import subprocess
import sys
import tempfile

M = (1 << 64) - 1
# statement: (operator, binding strength, function)
OPS = {
    "mul": ("*", 6, lambda a, b: (a * b) & M),
    "div": ("/", 6, lambda a, b: a // b),
    "mod": ("%", 6, lambda a, b: a % b),
    "add": ("+", 5, lambda a, b: (a + b) & M),
    "sub": ("-", 5, lambda a, b: (a - b) & M),
    "shl": ("<<", 4, lambda a, b: (a << (b & 63)) & M),
    "shr": (">>", 4, lambda a, b: a >> (b & 63)),
    "and": ("&", 3, lambda a, b: a & b),
    "xor": ("^", 2, lambda a, b: a ^ b),
    "or": ("|", 1, lambda a, b: a | b),
    "eq": ("==", 0, lambda a, b: int(a == b)),
    "ne": ("!=", 0, lambda a, b: int(a != b)),
    "lt": ("<", 0, lambda a, b: int(a < b)),
    "le": ("<=", 0, lambda a, b: int(a <= b)),
    "gt": (">", 0, lambda a, b: int(a > b)),
    "ge": (">=", 0, lambda a, b: int(a >= b)),
}
ARITH = ["mul", "add", "sub", "shl", "shr", "and", "xor", "or", "div", "mod"]
CMP = ["eq", "ne", "lt", "le", "gt", "ge"]
NTEMP = 4   # temporaries of the statement form, one per level of an expression


class Gen:
    def __init__(self, rng):
        self.rng = rng
        self.names = ["v%d" % i for i in range(rng.randint(3, 40))]
        self.ncnt = 0

    def leaf(self, defined):
        r = self.rng
        if defined and r.random() < 0.8:
            return r.choice(sorted(defined))
        return r.choice([str(r.randint(0, 9))] * 6 + ["255", "4096", "-1", "0x100000000",
                                                      "0xffffffffffffffff", "63", "64"])

    def expr(self, defined, depth):
        """a value: a leaf, or (statement, left, right)"""
        r = self.rng
        if depth >= NTEMP - 1 or r.random() < 0.45:
            return self.leaf(defined)
        op = r.choice(ARITH if r.random() < 0.85 else CMP)
        a = self.expr(defined, depth + 1)
        b = self.expr(defined, depth + 1)
        if op in ("div", "mod"):
            b = ("or", b, "1")          # never zero
        return (op, a, b)

    def block(self, defined, depth, n):
        """statements; `defined` grows with the variables they assign"""
        r = self.rng
        out = []
        for _ in range(n):
            x = r.random()
            if x < 0.72 or depth >= 3:
                dst = r.choice(self.names)
                e = self.expr(defined, 0)
                if dst in defined and r.random() < 0.3 and not isinstance(e, str):
                    e = (e[0], dst, e[2])    # the shape of x op= e
                out.append(("set", dst, e))
                defined.add(dst)
            elif x < 0.88:
                cnt = "c%d" % self.ncnt
                self.ncnt += 1
                # what a round assigns anew is its own: a loop may run no round
                body = self.block(set(defined), depth + 1, r.randint(1, 6))
                out.append(("loop", r.randint(1, 3), cnt, body))
            else:
                if not defined:
                    continue
                cond = (r.choice(CMP), self.leaf(defined), self.leaf(defined)) \
                    if r.random() < 0.7 else self.expr(defined, 1)
                a = self.block(set(defined), depth + 1, r.randint(1, 4))
                b = self.block(set(defined), depth + 1, r.randint(1, 3)) if r.random() < 0.4 else None
                out.append(("if", cond, a, b))
        return out


def val(x, env):
    return env[x] if x in env else int(x, 0) & M


def ev(e, env):
    if isinstance(e, str):
        return val(e, env)
    return OPS[e[0]][2](ev(e[1], env), ev(e[2], env))


def run(block, env):
    for st in block:
        if st[0] == "set":
            env[st[1]] = ev(st[2], env)
        elif st[0] == "loop":
            for _ in range(st[1]):
                run(st[3], env)
        elif ev(st[1], env):
            run(st[2], env)
        elif st[3] is not None:
            run(st[3], env)


class Old:
    """the statement form: one operation a line, labels and jumps"""

    def __init__(self):
        self.lines = []
        self.nlab = 0

    def label(self):
        self.nlab += 1
        return "l%d" % self.nlab

    def value(self, e, k):
        """compute e; return the name or number that holds it"""
        if isinstance(e, str):
            return e
        a = self.value(e[1], k)
        b = self.value(e[2], k + 1)
        self.lines.append("%s %s %s as t%d" % (e[0], a, b, k))
        return "t%d" % k

    def block(self, b):
        for st in b:
            if st[0] == "set":
                e = st[2]
                if isinstance(e, str):
                    self.lines.append("set %s as %s" % (e, st[1]))
                else:
                    a = self.value(e[1], 0)
                    c = self.value(e[2], 1)
                    self.lines.append("%s %s %s as %s" % (e[0], a, c, st[1]))
            elif st[0] == "loop":
                l = self.label()
                self.lines.append("set %d as %s" % (st[1], st[2]))
                self.lines.append("label " + l)
                self.block(st[3])
                self.lines.append("sub %s 1 as %s" % (st[2], st[2]))
                self.lines.append("jnz %s %s" % (st[2], l))
            else:
                l = self.label()
                self.lines.append("jz %s %s" % (self.value(st[1], 0), l))
                self.block(st[2])
                if st[3] is not None:
                    m = self.label()
                    self.lines.append("jmp " + m)
                    self.lines.append("label " + l)
                    self.block(st[3])
                    self.lines.append("label " + m)
                else:
                    self.lines.append("label " + l)


class New:
    """the expression form: assignments, while and if on a value"""

    def __init__(self, rng):
        self.lines = []
        self.rng = rng

    def text(self, e, strength, right):
        """e as text inside an operator of the given binding strength"""
        if isinstance(e, str):
            return e
        sym, s, _ = OPS[e[0]]
        t = self.text(e[1], s, False) + sym + self.text(e[2], s, True)
        # needed: a looser operator inside, or one of the same strength on the right
        if s < strength or (s == strength and right) or self.rng.random() < 0.15:
            return "(" + t + ")"
        return t

    def block(self, b):
        for st in b:
            if st[0] == "set":
                dst, e = st[1], st[2]
                if not isinstance(e, str) and e[1] == dst and e[0] in ARITH and self.rng.random() < 0.7:
                    self.lines.append("%s%s=%s" % (dst, OPS[e[0]][0], self.text(e[2], -1, False)))
                else:
                    self.lines.append("%s=%s" % (dst, self.text(e, -1, False)))
            elif st[0] == "loop":
                self.lines.append("%s=%d" % (st[2], st[1]))
                self.lines.append("while " + st[2])
                self.block(st[3])
                self.lines.append("%s-=1" % st[2])
                self.lines.append("end")
            else:
                self.lines.append("if " + self.text(st[1], -1, False))
                self.block(st[2])
                if st[3] is not None:
                    self.lines.append("else")
                    self.block(st[3])
                self.lines.append("end")


def program(rng, top):
    """the two sources of one random program, its exit status, and how
    many variables its larger form uses"""
    g = Gen(rng)
    params = [] if top else ["p%d" % i for i in range(rng.randint(0, 6))]
    defined = set(params)
    body = g.block(defined, 0, rng.randint(5, 40))
    args = [rng.randint(0, 1000) for _ in params]
    env = dict(zip(params, args))
    run(body, env)
    final = sorted(defined)
    h = 0
    for v in final:
        h = (h + env[v]) & M
    want = h % 251
    old, new = Old(), New(rng)
    old.block(body)
    new.block(body)
    old.lines.append("set 0 as h")
    for v in final:
        old.lines.append("add h %s as h" % v)
    old.lines.append("mod h 251 as h")
    new.lines.append("h=(%s)%%251" % "+".join(final) if final else "h=0")
    out = []
    for lines in (old.lines, new.lines):
        if top:
            src = lines + ["sys 60 h"]
        else:
            src = ["fn f " + " ".join(params)] + lines + ["ret h", "end",
                   "call f %s as r" % " ".join(map(str, args)), "sys 60 r"]
        out.append("\n".join(src) + "\n")
    return out[0], out[1], want, len(g.names) + len(params) + g.ncnt + NTEMP + 1


def main():
    cc, n, seed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    top = len(sys.argv) > 4
    rng = random.Random(seed)
    tmp = tempfile.mkdtemp()
    exe = os.path.join(tmp, "prog")
    what = "randvars %d programs, seed %d%s" % (n, seed, ", top level" if top else "")
    bad = done = 0

    def keep(i, form, src):
        os.makedirs("build/randvars", exist_ok=True)
        path = "build/randvars/seed%d%s-%d-%s.ai" % (seed, "-top" if top else "", i, form)
        open(path, "w").write(src)
        return path

    for i in range(n):
        old, new, want, nv = program(rng, top)
        if nv > 60:      # too many variables for a scope
            continue
        done += 1
        for form, src in (("statements", old), ("expressions", new)):
            p = subprocess.run([cc], input=src.encode(), capture_output=True)
            if p.returncode != 0:
                print("FAIL randvars %d as %s: does not compile: %s (kept as %s)"
                      % (i, form, p.stderr.decode().strip(), keep(i, form, src)))
                bad += 1
                continue
            open(exe, "wb").write(p.stdout)
            os.chmod(exe, 0o755)
            try:
                got = subprocess.run([exe], timeout=10).returncode
            except subprocess.TimeoutExpired:
                got = "deadline"
            if got != want:
                print("FAIL randvars %d as %s: status %s, expected %d (kept as %s)"
                      % (i, form, got, want, keep(i, form, src)))
                bad += 1
    if not bad:
        print("ok   %s (%d run, as statements and as expressions)" % (what, done))
    if os.path.exists(exe):
        os.remove(exe)
    os.rmdir(tmp)
    sys.exit(1 if bad else 0)


main()

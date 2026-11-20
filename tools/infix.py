"""Rewrite an AIL source from statements to expressions.

Usage: infix.py in.ai out.ai

Three rewrites, each of which leaves what the program does as it was:

1. A statement that computes is spelled as an assignment: `add a b as x`
   becomes `x=a+b`, or `x+=b` when `a` is `x`; `set a as x` becomes `x=a`;
   `iflt a b` becomes `if a<b`.
2. A loop written as a label, a jump out on a condition, lines and a jump
   back becomes `while` with the opposite condition, when nothing else
   jumps to the label.
3. A variable that is assigned on one line and read exactly once, on the
   next, and not again before it is assigned anew on any path, is folded
   into that next line: `t=a+b` and `store p t` become `store p a+b`.
   Two assignments to one variable in a row, the second of the form
   `x+=f`, become one. This is repeated, so chains of such lines become
   one expression. A `while` takes no value this way, since it reads its
   value every round, and a line with a comment is not folded away.

Lines with a string are left alone, as are signed and float statements,
which have no operator. Comments stay on the lines that stay.
"""
import re
import sys

OPS = {"mul": ("*", 6), "div": ("/", 6), "mod": ("%", 6), "add": ("+", 5), "sub": ("-", 5),
       "shl": ("<<", 4), "shr": (">>", 4), "and": ("&", 3), "xor": ("^", 2), "or": ("|", 1),
       "eq": ("==", 0), "ne": ("!=", 0), "lt": ("<", 0), "le": ("<=", 0), "gt": (">", 0),
       "ge": (">=", 0)}
PREC = {s: p for s, p in OPS.values()}
ARITH = {"*", "/", "%", "+", "-", "<<", ">>", "&", "^", "|"}
NEG = {"==": "!=", "!=": "==", "<": ">=", ">=": "<", "<=": ">", ">": "<="}
JCC = {"j" + k: OPS[k][0] for k in ("eq", "ne", "lt", "le", "gt", "ge")}
IFCC = {"if" + k: OPS[k][0] for k in ("eq", "ne", "lt", "le", "gt", "ge")}
SJCC = {"jslt", "jsle", "jsgt", "jsge"}
DEFS = {"fn", "buf", "data", "var", "const", "use", "local", "label", "else", "end"}
NAME = re.compile(r"^[a-z][a-z0-9_]*$")
TOKEN = re.compile(r"0x[0-9a-fA-F]+|\d+|[a-z][a-z0-9_]*|<<|>>|==|!=|<=|>=|[-+*/%&^|<>()]")
MAXLINE = 100


def parse(text):
    """an expression as a tree: a string, or (operator, left, right)"""
    toks = TOKEN.findall(text)
    if "".join(toks) != text:
        raise ValueError(text)
    pos = [0]

    def atom():
        t = toks[pos[0]]
        pos[0] += 1
        if t == "(":
            e = expr(0)
            if toks[pos[0]] != ")":
                raise ValueError(text)
            pos[0] += 1
            return e
        if t == "-":                       # a negative number
            t += toks[pos[0]]
            pos[0] += 1
        return t

    def expr(low):
        left = atom()
        while pos[0] < len(toks) and toks[pos[0]] in PREC and PREC[toks[pos[0]]] >= low:
            o = toks[pos[0]]
            pos[0] += 1
            left = (o, left, expr(PREC[o] + 1))
        return left

    e = expr(0)
    if pos[0] != len(toks):
        raise ValueError(text)
    return e


def show(e, strength=-1, right=False):
    if isinstance(e, str):
        return e
    o, a, b = e
    p = PREC[o]
    t = show(a, p, False) + o + show(b, p, True)
    return "(" + t + ")" if p < strength or (p == strength and right) else t


def names(e, out=None):
    """the names read by an expression, with repetition"""
    out = [] if out is None else out
    if isinstance(e, str):
        if NAME.match(e):
            out.append(e)
    else:
        names(e[1], out)
        names(e[2], out)
    return out


def subst(e, v, by):
    if isinstance(e, str):
        return by if e == v else e
    return (e[0], subst(e[1], v, by), subst(e[2], v, by))


class Line:
    """kind: 'asg' (target, op or None, tree), 'stmt' (keyword, values as
    trees, fixed words around them), or 'raw' (text kept as it is)"""

    def __init__(self, text):
        self.text = text
        self.kind = "raw"
        self.comment = ""
        self.kw = None
        code = text
        i = text.find("#")
        if i >= 0 and '"' not in text[:i]:
            code, self.comment = text[:i].rstrip(), text[i:]
            self.pad = text[len(code):i]
        self.words = code.split()
        self.was = code
        if '"' in code or not self.words:
            return
        w = self.words
        self.kw = w[0]
        m = re.match(r"^([a-z][a-z0-9_]*)(\*|/|%|\+|-|<<|>>|&|\^|\|)?=(.+)$", w[0])
        try:
            if m and len(w) == 1 and not m.group(3).startswith("="):
                self.kind, self.target, self.op, self.tree = "asg", m.group(1), m.group(2), parse(m.group(3))
                self.kw = None
                return
            if self.kw in DEFS or self.kw in ("at", "len", "args"):
                return
            # the words that are values: not the name of a function, the
            # number of a syscall, a label, or what follows as
            vals = w[1:]
            self.after = []
            if "as" in vals:
                i = vals.index("as")
                vals, self.after = vals[:i], vals[i:]
            self.before = []
            if self.kw in ("call", "tail", "ref", "sys"):
                self.before, vals = vals[:1], vals[1:]
            self.label = None
            if self.kw == "jmp" or self.kw in ("jz", "jnz") or self.kw in JCC or self.kw in SJCC:
                self.label, vals = vals[-1], vals[:-1]
            self.vals = [parse(v) for v in vals]
            self.kind = "stmt"
        except (ValueError, IndexError, RecursionError):
            self.kind = "raw"

    def render(self):
        if self.kind == "raw":
            return self.text
        if self.kind == "asg":
            code = "%s%s=%s" % (self.target, self.op or "", show(self.tree))
        else:
            code = " ".join([self.kw] + self.before + [show(v) for v in self.vals]
                            + ([self.label] if self.label else []) + self.after)
        if not self.comment:
            return code
        # the comment stays in its column if the code still ends before it
        pad = self.pad if code == self.was else " " * max(2, len(self.was) + len(self.pad) - len(code))
        return code + pad + self.comment

    def reads(self):
        if self.kind == "asg":
            r = names(self.tree)
            return r + [self.target] if self.op else r
        if self.kind == "stmt":
            r = []
            for v in self.vals:
                names(v, r)
            return r
        if self.kw in ("at", "len") and len(self.words) > 1:
            return [x for x in self.words[1:self.words.index("as")] if NAME.match(x)] \
                if "as" in self.words else []
        return []

    def writes(self):
        if self.kind == "asg":
            return [self.target]
        if self.kind == "stmt":
            return self.after[1:]
        if self.kw in ("at", "len", "args") and "as" in self.words:
            return self.words[self.words.index("as") + 1:]
        return []

    def opens(self):
        return self.kw == "while" or (self.kw or "").startswith("if")


def scopes(lines):
    """the lines of each function, and of the top level, as index lists"""
    out, top, cur = [], [], None
    depth = 0
    for i, l in enumerate(lines):
        if l.kw == "fn":
            cur, depth = [i], 0
            continue
        if cur is None:
            top.append(i)
            continue
        cur.append(i)
        if l.opens():
            depth += 1
        elif l.kw == "end":
            if depth == 0:
                out.append(cur)
                cur = None
            else:
                depth -= 1
    out.append(top)
    return out


def blocks(lines, sc):
    """for every line of the scope that opens, continues or closes a block,
    the positions it belongs with: (opener, else or None, end)"""
    info, stack = {}, []
    for n, i in enumerate(sc):
        l = lines[i]
        if l.opens():
            stack.append([n, None])
        elif l.kw == "else" and stack:
            stack[-1][1] = n
        elif l.kw == "end" and stack:
            o, e = stack.pop()
            for x in (o, e, n):
                if x is not None:
                    info[x] = (o, e, n)
    return info


def successors(lines, sc, blk, pos, n):
    l = lines[sc[n]]
    k = l.kw
    if n in blk:
        o, e, c = blk[n]
        if n == o:
            return [n + 1, (e if e is not None else c) + 1]
        if n == e:
            return [c + 1]
        return [o] if lines[sc[o]].kw == "while" else [n + 1]
    if k == "end" or k in ("ret", "tail"):
        return []
    if l.kind == "stmt" and l.label:
        if l.label not in pos:
            return None                     # a jump out of what we see
        return [pos[l.label]] if k == "jmp" else [n + 1, pos[l.label]]
    return [n + 1]


def dead_after(lines, sc, blk, pos, start, v):
    """no way from position start reads v before writing it"""
    seen, todo = set(), [start]
    while todo:
        n = todo.pop()
        if n >= len(sc) or n in seen:
            continue
        seen.add(n)
        l = lines[sc[n]]
        if v in l.reads():
            return False
        if v in l.writes():
            continue
        s = successors(lines, sc, blk, pos, n)
        if s is None:
            return False
        todo.extend(s)
    return True


def spell(lines):
    n = 0
    for l in lines:
        if l.kind != "stmt":
            continue
        k, v = l.kw, l.vals
        if k == "set" and len(v) == 1 and len(l.after) == 2:
            l.kind, l.target, l.op, l.tree = "asg", l.after[1], None, v[0]
        elif k in OPS and len(v) == 2 and len(l.after) == 2:
            o, x = OPS[k][0], l.after[1]
            if v[0] == x and o in ARITH:
                l.kind, l.target, l.op, l.tree = "asg", x, o, v[1]
            else:
                l.kind, l.target, l.op, l.tree = "asg", x, None, (o, v[0], v[1])
        elif k in IFCC and len(v) == 2:
            l.kw, l.vals = "if", [(IFCC[k], v[0], v[1])]
        else:
            continue
        if l.kind == "asg":
            l.kw = None
        n += 1
    return n


def loops(lines):
    """label L / jump out on a condition / ... / jmp L / label X"""
    made = 0
    changed = True
    while changed:
        changed = False
        for sc in scopes(lines):
            pos, refs = {}, {}
            for n, i in enumerate(sc):
                l = lines[i]
                if l.kw == "label" and len(l.words) == 2:
                    pos[l.words[1]] = n
                if l.kind == "stmt" and l.label:
                    refs.setdefault(l.label, []).append(n)
            best = None
            for name, a in pos.items():
                r = refs.get(name, [])
                if len(r) != 1 or r[0] <= a + 1 or lines[sc[r[0]]].kw != "jmp":
                    continue
                b = r[0]
                head, tail = lines[sc[a]], lines[sc[a + 1]]
                if head.comment or tail.kind != "stmt" or b + 1 >= len(sc):
                    continue
                if tail.kw in JCC and len(tail.vals) == 2:
                    cond = (NEG[JCC[tail.kw]], tail.vals[0], tail.vals[1])
                elif tail.kw == "jz" and len(tail.vals) == 1:
                    cond = tail.vals[0]
                elif tail.kw == "jnz" and len(tail.vals) == 1:
                    cond = ("==", tail.vals[0], "0")
                else:
                    continue
                last = lines[sc[b + 1]]
                if last.kw != "label" or last.words[1:] != [tail.label] or lines[sc[b]].comment:
                    continue
                depth, ok = 0, True
                for n in range(a + 2, b):
                    l = lines[sc[n]]
                    if l.opens():
                        depth += 1
                    elif l.kw == "end":
                        depth -= 1
                        if depth < 0:
                            ok = False
                    elif l.kw == "else" and depth == 0:
                        ok = False
                if not ok or depth:
                    continue
                if best is None or b - a < best[1] - best[0]:
                    best = (a, b, cond, tail, len(refs.get(tail.label, [])) == 1)
            if best:
                a, b, cond, tail, alone = best
                tail.kw, tail.vals, tail.label = "while", [cond], None
                lines[sc[a]] = None
                lines[sc[b]] = Line("end")
                if alone and not lines[sc[b + 1]].comment:
                    lines[sc[b + 1]] = None
                lines[:] = [l for l in lines if l is not None]
                made += 1
                changed = True
                break
    return made


def fold(lines, gvars):
    made = 0
    changed = True
    while changed:
        changed = False
        for sc in scopes(lines):
            blk = blocks(lines, sc)
            pos = {lines[i].words[1]: n for n, i in enumerate(sc)
                   if lines[i].kw == "label" and len(lines[i].words) == 2}
            for n in range(len(sc) - 1):
                a, b = lines[sc[n]], lines[sc[n + 1]]
                if a.kind != "asg" or a.comment or a.target in gvars:
                    continue
                if a.op:
                    # t*=e and then t+=f: t=t*e+f
                    if b.kind == "asg" and b.op and b.target == a.target and not b.comment \
                            and a.target not in names(b.tree):
                        new = (b.op, (a.op, a.target, a.tree), b.tree)
                        if len(show(new)) + len(a.target) <= MAXLINE:
                            b.op, b.tree = None, new
                            lines[sc[n]] = None
                            lines[:] = [l for l in lines if l is not None]
                            made += 1
                            changed = True
                            break
                        # too long for one line: the lines stay two, since
                        # t=e+f below would be without the t*
                        continue
                t = a.target
                if b.kind == "asg" and b.op and b.target == t and t not in names(b.tree) \
                        and not b.comment:
                    # t=e and then t+=f: one assignment
                    new = (b.op, a.tree, b.tree)
                    if len(show(new)) + len(t) <= MAXLINE:
                        b.op, b.tree = None, new
                        lines[sc[n]] = None
                        lines[:] = [l for l in lines if l is not None]
                        made += 1
                        changed = True
                        break
                    continue
                if b.kind == "raw" or b.kw == "while" or b.reads().count(t) != 1:
                    continue
                if b.kind == "asg" and b.op and b.target == t:
                    continue
                if t in b.writes():
                    s = successors(lines, sc, blk, pos, n + 1)
                    dead = s is not None        # written again at once
                else:
                    s = successors(lines, sc, blk, pos, n + 1)
                    dead = s is not None and all(dead_after(lines, sc, blk, pos, x, t) for x in s)
                if not dead:
                    continue
                # what t holds after line a
                held = (a.op, t, a.tree) if a.op else a.tree
                if b.kind == "asg":
                    new = subst(b.tree, t, held)
                    if len(show(new)) + len(b.target) > MAXLINE:
                        continue
                    b.tree = new
                else:
                    new = [subst(v, t, held) for v in b.vals]
                    if sum(len(show(v)) for v in new) > MAXLINE:
                        continue
                    b.vals = new
                lines[sc[n]] = None
                lines[:] = [l for l in lines if l is not None]
                made += 1
                changed = True
                break
            if changed:
                break
    return made


def main():
    # bytes as they are: a source may hold any byte in a string or comment
    text = open(sys.argv[1], encoding="latin-1", newline="").read()
    tail = "\n" if text.endswith("\n") else ""
    lines = [Line(t) for t in text.split("\n")]
    if tail:
        lines.pop()
    gvars = set()
    for l in lines:
        if l.kw == "var":
            gvars |= set(l.words[1:])
    a = spell(lines)
    b = loops(lines)
    c = fold(lines, gvars)
    open(sys.argv[2], "w", encoding="latin-1", newline="").write(
        "\n".join(l.render() for l in lines) + tail)
    print("spelled %d, loops %d, folded %d" % (a, b, c), file=sys.stderr)


main()

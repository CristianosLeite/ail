"""Time each example against its C, Rust and assembly equivalent.

Usage: tools/perf.py [--cpu N] [--quick] [name ...]   (default: every program)
Run from the top of the repository after `make`. Needs gcc and rustc.

The AIL program is build/<name>; the others are built from bench/ into
build/perf/ with the flags below. A language without a source for a
program is left out of its row. Every binary must give the expected
output and exit status before anything is timed. A run is posix_spawn
plus waitpid with stdin from a file and stdout to /dev/null, on one
CPU, the languages in a shuffled order in every round; the figure is
the median, with the quartiles after it.

Startup programs do almost nothing, so their time is the cost of
starting a process; they are reported apart from the CPU-bound ones,
for which the ratio to C and its geometric mean are given.
"""
import os
import random
import struct
import subprocess
import sys
from pathlib import Path
from statistics import median
from time import perf_counter_ns

CFLAGS = ["gcc", "-O3"]
RSFLAGS = ["rustc", "-O"]
LANGS = ["AIL", "C", "Rust", "asm"]
OUT = Path("build/perf")
SLOW = 1.10  # a CPU-bound program this much slower than C is marked

BYTES = bytes(range(256)) * 16
# name: (kind, stdin, expected stdout or None for "whatever C prints",
#        expected exit status)
PROGRAMS = {
    "hello": ("startup", b"", b"hello world\n", 0),
    "echo": ("startup", BYTES, BYTES, 0),
    "count": ("startup", BYTES, b"4096\n", 0),
    "fact": ("startup", b"", b"", 120),
    "loop": ("startup", b"", b"0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n", 0),
    "compute": ("cpu", struct.pack("<Q", 0x123456789ABCDEF0), None, 0),
    "sieve": ("cpu", struct.pack("<Q", 16000000), None, 0),
    "collatz": ("cpu", struct.pack("<Q", 500000), None, 0),
    "fnv": ("cpu", BYTES * 256, None, 0),
    "isort": ("cpu", struct.pack("<Q", 0x123456789ABCDEF0), None, 0),
}


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def build(name):
    """Return {language: path of the executable} for one program."""
    bins = {"AIL": Path("build", name)}
    if not bins["AIL"].exists():
        sys.exit("perf: build/%s is missing, run make first" % name)
    c, rs, s = (Path("bench", name + e) for e in (".c", ".rs", ".s"))
    if c.exists():
        bins["C"] = OUT / (name + ".c.bin")
        run(*CFLAGS, "-o", bins["C"], c)
    if rs.exists():
        bins["Rust"] = OUT / (name + ".rs.bin")
        run(*RSFLAGS, "-o", bins["Rust"], rs)
    if s.exists():
        bins["asm"] = OUT / (name + ".s.bin")
        run("as", "-o", OUT / (name + ".o"), s)
        run("ld", "-o", bins["asm"], OUT / (name + ".o"))
    return bins


def check(name, bins):
    _, data, want, status = PROGRAMS[name]
    order = [l for l in ("C", "Rust", "asm", "AIL") if l in bins]
    for lang in order:
        r = subprocess.run([str(bins[lang])], input=data,
                           stdout=subprocess.PIPE, check=False)
        if r.returncode != status:
            sys.exit("perf: %s %s: exit status %d, expected %d"
                     % (name, lang, r.returncode, status))
        if want is None:
            want = r.stdout
        if r.stdout != want:
            sys.exit("perf: %s %s: wrong output" % (name, lang))


def measure(name, bins, rng, quick):
    kind, data, _, status = PROGRAMS[name]
    warmups, rounds = (2, 15) if kind == "cpu" else (25, 500)
    if quick:
        warmups, rounds = (1, 3) if kind == "cpu" else (5, 50)
    path = OUT / (name + ".input")
    path.write_bytes(data)
    samples = {lang: [] for lang in bins}
    env = os.environ.copy()
    with path.open("rb") as src, open(os.devnull, "wb") as null:
        actions = [(os.POSIX_SPAWN_DUP2, src.fileno(), 0),
                   (os.POSIX_SPAWN_DUP2, null.fileno(), 1)]
        for i in range(warmups + rounds):
            order = list(bins)
            rng.shuffle(order)
            for lang in order:
                src.seek(0)
                b = str(bins[lang])
                start = perf_counter_ns()
                pid = os.posix_spawn(b, [b], env, file_actions=actions)
                _, st = os.waitpid(pid, 0)
                t = perf_counter_ns() - start
                if os.waitstatus_to_exitcode(st) != status:
                    sys.exit("perf: %s %s: failed while timed" % (name, lang))
                if i >= warmups:
                    samples[lang].append(t)
    out = {}
    for lang, s in samples.items():
        s.sort()
        out[lang] = (median(s), s[len(s) // 4], s[3 * len(s) // 4])
    return out


def first_line(*cmd):
    return subprocess.run(cmd, stdout=subprocess.PIPE, text=True,
                          check=True).stdout.splitlines()[0]


def cpu_model():
    for line in open("/proc/cpuinfo"):
        if line.startswith("model name"):
            return line.split(":", 1)[1].strip()
    return "unknown"


def table(kind, results, unit, scale):
    names = [n for n in results if PROGRAMS[n][0] == kind]
    if not names:
        return
    title = "CPU-bound" if kind == "cpu" else "Startup"
    print("\n%s, median elapsed %s (first and third quartile)\n" % (title, unit))
    head = "| program | " + " | ".join(LANGS) + " |"
    rule = "|---|" + "---:|" * len(LANGS)
    if kind == "cpu":
        head += " AIL / C |"
        rule += "---:|"
    print(head)
    print(rule)
    ratios = []
    for n in names:
        r = results[n]
        cells = []
        for lang in LANGS:
            if lang in r:
                m, lo, hi = (v / scale for v in r[lang])
                cells.append("%.2f (%.2f, %.2f)" % (m, lo, hi))
            else:
                cells.append("")
        row = "| %s | %s |" % (n, " | ".join(cells))
        if kind == "cpu":
            if "C" in r:
                q = r["AIL"][0] / r["C"][0]
                ratios.append(q)
                row += " %.3f%s |" % (q, " slow" if q > SLOW else "")
            else:
                row += " |"
        print(row)
    if ratios:
        g = 1.0
        for q in ratios:
            g *= q
        g **= 1.0 / len(ratios)
        print("\nGeometric mean of AIL / C over %d CPU-bound program%s: %.3f"
              % (len(ratios), "" if len(ratios) == 1 else "s", g))


def main():
    args = sys.argv[1:]
    quick = "--quick" in args
    if quick:
        args.remove("--quick")
    cpu = 2
    if "--cpu" in args:
        i = args.index("--cpu")
        cpu = int(args[i + 1])
        del args[i:i + 2]
    names = args or list(PROGRAMS)
    for n in names:
        if n not in PROGRAMS:
            sys.exit("perf: unknown program %s" % n)
    OUT.mkdir(parents=True, exist_ok=True)
    if cpu not in os.sched_getaffinity(0):
        cpu = min(os.sched_getaffinity(0))
    os.sched_setaffinity(0, {cpu})
    print("CPU: %s, pinned to CPU %d" % (cpu_model(), cpu))
    print("C: `%s`, %s" % (" ".join(CFLAGS), first_line("gcc", "--version")))
    print("Rust: `%s`, %s" % (" ".join(RSFLAGS), first_line("rustc", "--version")))
    print("asm: GNU as and ld; AIL: build/ailc")
    rng = random.Random(77)
    results = {}
    for n in names:
        bins = build(n)
        check(n, bins)
        results[n] = measure(n, bins, rng, quick)
    table("startup", results, "in microseconds", 1_000)
    table("cpu", results, "in milliseconds", 1_000_000)


main()

"""Check and time the task programs of bench/par against their sequential forms.

Usage: tools/par.py [--check] [--runs N] [name ...]   (default: every program)
Run from the top of the repository after `make`.

A program is bench/par/<name>_seq.ai and bench/par/<name>_par.ai, the
same work written without and with spawn and join; both are compiled
by build/ailc into build/par/. The sequential one reads its size from
stdin, the other the size, the number of threads that run tasks and
the number of tasks. Every run must print what the sequential program
prints.

--check runs small sizes at several thread and task counts and times
nothing; make test does that. Without it the sizes below are timed:
the median of the runs, on all processors, each run a new process.
Three tables are printed: elapsed time by threads, elapsed time by
the number of tasks the same work is cut into, and the tokens of both
sources (counted by build/tools/tokens, if it is built and the files it
reads are there: make tools, tools/pin.sh; see tools/tokens.sh).
"""
import os
import struct
import subprocess
import sys
from pathlib import Path
from statistics import median
from time import perf_counter_ns

OUT = Path("build/par")
AILC = "build/ailc"
# name: (size timed, size checked)
PROGRAMS = {
    "collatz": (3000000, 3000),
    "primes": (3000000, 3000),
    "memsum": (16777216, 5000),
}
THREADS = [1, 2, 4, 8, 14, 20]
TASKS = 160  # tasks in the table by threads
SWEEP = [20, 200, 2000, 20000, 200000, 1000000]  # tasks in the table by tasks
SWEEP_THREADS = [1, 20]
CHECKS = [(1, 1), (1, 7), (2, 2), (4, 64), (20, 1000), (3, 5000)]


def build(name):
    bins = []
    for kind in ("seq", "par"):
        src = Path("bench/par", "%s_%s.ai" % (name, kind))
        exe = OUT / ("%s_%s" % (name, kind))
        with open(src, "rb") as i, open(exe, "wb") as o:
            subprocess.run([AILC], stdin=i, stdout=o, check=True)
        exe.chmod(0o755)
        bins.append(exe)
    return bins


def run(exe, *numbers, timed=False):
    """Run exe with the numbers on stdin; its output, or its time in ns."""
    data = struct.pack("<%dQ" % len(numbers), *numbers)
    t = perf_counter_ns()
    r = subprocess.run([str(exe)], input=data, stdout=subprocess.PIPE,
                       check=False, timeout=120)
    t = perf_counter_ns() - t
    if r.returncode != 0:
        sys.exit("par: %s %s: exit status %d" % (exe, numbers, r.returncode))
    return (t, r.stdout) if timed else r.stdout


def time(exe, want, runs, *numbers):
    times = []
    for _ in range(runs):
        t, out = run(exe, *numbers, timed=True)
        if out != want:
            sys.exit("par: %s %s: wrong output" % (exe, numbers))
        times.append(t)
    return median(times) / 1e6


def check(names):
    fail = 0
    for name in names:
        seq, par = build(name)
        n = PROGRAMS[name][1]
        want = run(seq, n)
        bad = [c for c in CHECKS if run(par, n, *c) != want]
        print("%s par %s" % ("FAIL" if bad else "ok  ", name))
        for threads, tasks in bad:
            print("     %d threads, %d tasks: not the sequential output"
                  % (threads, tasks))
        fail |= bool(bad)
    sys.exit(fail)


def tokens(names):
    paths = ["bench/par/%s_%s.ai" % (name, k) for name in names for k in ("seq", "par")]
    try:
        out = subprocess.run(["build/tools/tokens", "-c", "#"] + paths, check=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout
    except (OSError, subprocess.CalledProcessError):
        print("\n(no token table: build/tools/tokens is not built or lacks its pinned files)")
        return
    count = [int(line.split()[0]) for line in out.splitlines()]
    print("\n| program | sequential | tasks | lines added |")
    print("|---|---:|---:|---:|")
    for i, name in enumerate(names):
        a, b = (sum(1 for l in open(p) if l.split("#")[0].strip()) for p in paths[2 * i:2 * i + 2])
        print("| %s | %d | %d | %d |" % (name, count[2 * i], count[2 * i + 1], b - a))


def main():
    args = sys.argv[1:]
    runs = 7
    checking = "--check" in args
    if checking:
        args.remove("--check")
    if "--runs" in args:
        i = args.index("--runs")
        runs = int(args[i + 1])
        del args[i:i + 2]
    names = args or list(PROGRAMS)
    for name in names:
        if name not in PROGRAMS:
            sys.exit("par: no program %s" % name)
    OUT.mkdir(parents=True, exist_ok=True)
    if checking:
        check(names)

    rows, sweeps = [], []
    for name in names:
        seq, par = build(name)
        n = PROGRAMS[name][0]
        want = run(seq, n)
        base = time(seq, want, runs, n)
        rows.append((name, base,
                     [time(par, want, runs, n, w, TASKS) for w in THREADS]))
        for w in SWEEP_THREADS:
            sweeps.append((name, w, base, [time(par, want, runs, n, w, t)
                                           for t in SWEEP]))

    print("Elapsed milliseconds, %d tasks, median of %d runs; "
          "below, the sequential time divided by it\n" % (TASKS, runs))
    print("| program | sequential | " + " | ".join(map(str, THREADS)) + " |")
    print("|---|---:|" + "---:|" * len(THREADS))
    for name, base, ts in rows:
        print("| %s | %.1f | %s |" % (name, base,
              " | ".join("%.1f" % t for t in ts)))
        print("| | | %s |" % " | ".join("%.2f" % (base / t) for t in ts))

    print("\nElapsed milliseconds by the number of tasks\n")
    print("| program | threads | sequential | "
          + " | ".join(map(str, SWEEP)) + " |")
    print("|---|---:|---:|" + "---:|" * len(SWEEP))
    for name, w, base, ts in sweeps:
        print("| %s | %d | %.1f | %s |" % (name, w, base,
              " | ".join("%.1f" % t for t in ts)))
    tokens(names)


main()

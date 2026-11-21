#!/usr/bin/env python3
"""Time NumPy on the kernels of the array programs, for docs/performance.md.

The same operations on arrays of the same sizes as the rows of
tools/perf.aw for ndelem, ndreduce and ndmatmul, each into a result
that is there before the clock starts, where NumPy allows one. The
numbers are not those of the harness: only the time is compared, the
results are compared by tests/lib_nd_ref_*. One thread, so that the
product of matrices is not spread over the cores by the BLAS; pin the
process as perf does:

    taskset -c 2 python3 tests/nd/bench.py

Prints the median of 15 rounds after 2 that are not counted, in
milliseconds for the runs perf makes in one process. Not run by make
test.
"""
import os

for name in ("OMP", "OPENBLAS", "MKL"):
    os.environ[name + "_NUM_THREADS"] = "1"

import time

import numpy as np


def med(f, runs):
    times = []
    for _ in range(17):
        b = time.perf_counter_ns()
        for _ in range(runs):
            f()
        times.append(time.perf_counter_ns() - b)
    times = sorted(times[2:])
    return times[len(times) // 2] / 1e6


def main():
    rng = np.random.default_rng(7)
    print("NumPy", np.__version__)
    for n, runs in ((1000, 20000), (1000000, 20)):
        a = rng.uniform(-512, 512, n)
        b = rng.uniform(-512, 512, n)
        r = np.empty(n)
        k = b[0]
        print(f"ndelem add, {n} x {runs}: {med(lambda: np.add(a, b, out=r), runs):.2f}")
        print(f"ndelem mul, {n} x {runs}: {med(lambda: np.multiply(a, b, out=r), runs):.2f}")
        print(f"ndelem scale, {n} x {runs}: {med(lambda: np.multiply(a, k, out=r), runs):.2f}")
    for n, runs in ((100, 1000), (1000, 20)):
        a = rng.uniform(-512, 512, (n, n))
        b = rng.uniform(-512, 512, (n, n))
        r = np.empty(n)
        x = a.reshape(n * n)
        y = b.reshape(n * n)
        print(f"ndreduce sum, {n} x {runs}: {med(lambda: a.sum(), runs):.2f}")
        print(f"ndreduce cols, {n} x {runs}: {med(lambda: a.sum(axis=0, out=r), runs):.2f}")
        print(f"ndreduce dot, {n} x {runs}: {med(lambda: x @ y, runs):.2f}")
    for n, runs in ((100, 20), (1000, 1)):
        a = rng.uniform(-512, 512, (n, n))
        b = rng.uniform(-512, 512, (n, n))
        r = np.empty((n, n))
        print(f"ndmatmul, {n} x {runs}: {med(lambda: np.matmul(a, b, out=r), runs):.2f}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Write tests/lib/ndfix.aiw, the reference results for lib/nd.

The inputs and what NumPy computes of them are written as data lines,
8 bytes a number, least significant byte first, 8 numbers a line. The
tests tests/lib_nd_ref_* name the file with use and compare what the
library computes with it, so make test needs neither Python nor
NumPy. The file was written with NumPy 2.3.5 and Python 3; another
version of NumPy may give other last digits for the sums, which the
tests allow for, and must give the same bytes for everything else.

Run from the top of the repository:  python3 tests/nd/gen.py
It refuses to run with another NumPy unless given --any.
"""
import struct
import sys

import numpy as np

PINNED = "2.3.5"
OUT = "tests/lib/ndfix.aiw"


def rows(name, array):
    """The data lines of an array, the last index fastest."""
    a = np.ascontiguousarray(array)
    if a.dtype == np.int64:
        raw = b"".join(struct.pack("<q", int(v)) for v in a.ravel())
    else:
        raw = b"".join(struct.pack("<d", float(v)) for v in a.ravel())
    lines = []
    for i in range(0, len(raw), 64):
        head = "data " + (name + " " if i == 0 else "")
        lines.append(head + " ".join(str(b) for b in raw[i:i + 64]))
    return lines


def main():
    if np.__version__ != PINNED and "--any" not in sys.argv:
        sys.exit(f"gen.py: NumPy {np.__version__}, the fixtures are of {PINNED}")
    rng = np.random.default_rng(20261121)
    fix = []

    def put(name, array):
        fix.append((name, np.asarray(array)))

    # element by element
    a = rng.uniform(-10, 10, (4, 5))
    b = rng.uniform(-10, 10, (4, 5))
    row = rng.uniform(-10, 10, 5)
    col = rng.uniform(-10, 10, (4, 1))
    t = rng.uniform(-10, 10, (2, 3, 4))
    u = rng.uniform(-10, 10, (3, 1))
    put("fxea", a)
    put("fxeb", b)
    put("fxeadd", a + b)
    put("fxesub", a - b)
    put("fxemul", a * b)
    put("fxediv", a / b)
    put("fxerow", row)
    put("fxecol", col)
    put("fxerowadd", a + row)
    put("fxecolmul", a * col)
    put("fxescal", 2.5 - a)
    put("fxet", t)
    put("fxeu", u)
    put("fxetu", t / u)
    put("fxeview", a[::-1, 1:5:2] * b[:, 3:1:-1])

    # sums and means
    big = rng.uniform(-1, 1, 10000) * 10.0 ** rng.integers(-8, 8, 10000)
    put("fxrsum", a.sum())
    put("fxrmean", a.mean())
    put("fxrs0", a.sum(axis=0))
    put("fxrs1", a.sum(axis=1))
    put("fxrm0", a.mean(axis=0))
    put("fxrm1", a.mean(axis=1))
    put("fxrts1", t.sum(axis=1))
    put("fxrtm2", t.mean(axis=2))
    put("fxrvs", a[::-1, 1:5:2].sum(axis=0))
    put("fxrbig", big)
    put("fxrbigsum", big.sum())
    put("fxrbigmean", big.mean())

    # products
    pa = rng.uniform(-10, 10, (6, 7))
    pb = rng.uniform(-10, 10, (7, 5))
    px = rng.uniform(-10, 10, 100)
    py = rng.uniform(-10, 10, 100)
    put("fxpa", pa)
    put("fxpb", pb)
    put("fxpab", pa @ pb)
    put("fxpata", pa.T @ pa)
    put("fxpview", pa[::2, ::-1] @ pb)
    put("fxpx", px)
    put("fxpy", py)
    put("fxpdot", px @ py)
    put("fxpdotv", px[::-2] @ py[1::2])

    # infinities, what is no number, and zeros with a sign
    inf = np.inf
    nan = np.nan
    sa = np.array([inf, -inf, nan, 0.0, -0.0, 1.0, -1.0, 1e308])
    sb = np.array([inf, inf, 1.0, 0.0, 0.0, -inf, nan, 1e308])
    with np.errstate(all="ignore"):
        put("fxsa", sa)
        put("fxsb", sb)
        put("fxsadd", sa + sb)
        put("fxssub", sa - sb)
        put("fxsmul", sa * sb)
        put("fxsdiv", sa / sb)
        put("fxss1", sa.reshape(2, 4).sum(axis=1))
        put("fxss0", sb.reshape(2, 4).sum(axis=0))
        put("fxsm0", sb.reshape(2, 4).mean(axis=0))

    # integers
    ia = rng.integers(-1000, 1000, (3, 4), dtype=np.int64)
    ib = rng.integers(-1000, 1000, (3, 4), dtype=np.int64)
    ia[0, 0] = 2**63 - 1
    ia[1, 2] = -2**63
    ib[0, 0] = 3
    ib[2, 3] = 2**62
    fa = np.array([-2.75, -1.0, -0.5, 0.5, 1.999, 123456789.25])
    with np.errstate(all="ignore"):
        put("fxia", ia)
        put("fxib", ib)
        put("fxiadd", ia + ib)
        put("fxisub", ia - ib)
        put("fximul", ia * ib)
        put("fxisum", ia.sum())
        put("fxis0", ia.sum(axis=0))
        put("fximm", ia @ ib.T)
        put("fxifa", fa)
        put("fxitoi", np.trunc(fa).astype(np.int64))
        put("fxitof", ia.astype(np.float64))
        put("fximean", ia[:, 1].mean())

    out = [
        "# tests/lib/ndfix.aiw -- inputs and the results NumPy " + PINNED,
        "# computed of them, for the tests lib_nd_ref_*. Written by",
        "# tests/nd/gen.py, which says what each name is; not edited by hand.",
    ]
    for name, array in fix:
        shape = " ".join(str(n) for n in array.shape) or "one number"
        out.append(f"# {name}: {shape}")
        out.extend(rows(name, array))
    with open(OUT, "w") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()

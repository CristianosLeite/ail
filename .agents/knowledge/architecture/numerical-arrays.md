---
title: Numerical arrays (lib/nd)
last-verified: 2026-11-21
sources: [conversation 2026-11-21, docs/TODO.md, docs/language.md, docs/performance.md, lib/nd/, tests/lib_nd_*, tests/nd/gen.py, tests/lib/ndfix.aw, bench/algo/harness.aw, tools/perf.aw, tests/algo.sh]
status: current
---
# Numerical arrays (lib/nd)

**Summary.** `lib/nd/` is arrays of doubles or 64-bit integers on the model of NumPy:
a descriptor of 176 bytes owned by the caller, views that move no element, elementwise
kernels with broadcasting into a result the caller made, sums, means, dot and matrix
products. It is checked against results of NumPy 2.3.5 that are committed as data, and
timed against C: 3.65 times the time of plain C loops in the geometric mean of 14 kernels.

## Facts
- The descriptor: address of the element at index 0, kind (1 doubles, 2 integers, 0 no
  array), up to 8 axes, address and bytes of the storage, an owned mark, 8 lengths, 8 signed
  strides in bytes. All zero is no array. `ndnew` owns its storage, `ndwrap` borrows the
  caller's; both refuse an axis or a count of 2^60 or more and write the descriptor last.
- Views (`ndslice`, `ndtrans`, `ndswap`, `ndreshape`) never own storage unless written in
  place of the array that does. `ndslice` is one axis, `lo` up to `hi`, signed step; a
  negative step walks down from `hi-1`. `ndreshape` needs `ndcontig`.
- Every kernel goes over elements with one walk (`ndwalk`, `ndwarg`, `ndstep`): 384 bytes
  in a `local`, the lengths of the result, and up to three arrays whose stride is 0 on an
  axis they have not got or have with length 1. That is the whole of broadcasting.
- The result of a kernel is given, never made: nothing allocates. It may be exactly one of
  its operands; any other meeting of address ranges is refused, which also refuses views
  whose elements alternate. A result with a stride of 0 on an axis longer than 1 is refused.
- A sum adds in the order of the indices from 0, as a C loop does, not in pairs as NumPy
  does; `ndsumpw` adds in pairs. The sum of nothing is 0, its mean 0/0. Decided on
  2026-11-21 to keep `ndsum` in order although pairs are 20 to 30% faster and more exact:
  the order is what makes results comparable byte for byte with C.
- Integers wrap at 64 bits. Their quotient is cut off towards 0 (NumPy's `//` floors); a
  divisor array with a 0 is refused before anything is written; the lowest integer by -1
  stays what it is. A mean is always a double. Kinds are never mixed but by `ndtoi`/`ndtof`.
- `tests/nd/gen.py` is the one Python file of the repository. It writes `tests/lib/ndfix.aw`
  and is never run by `make test`; `tests/nd/bench.py` times NumPy for the docs.
- The array programs `ndelem`, `ndreduce`, `ndmatmul` call `algonum` of the harness, which
  gives every language the same doubles (20 bits / 1024 - 512), so results are the same
  bytes in AIL, C and Rust. C must not be built with `-ffast-math` for that to hold.
- Measured 2026-11-21 (i7-12700H): 1.24 times C where memory is the limit (a million
  numbers), 6 times at a thousand, 10 times for an array times one number (it takes the
  loop with strides), 3.5 times for sums and dot, 5 times for the product of matrices.
  The likely cause for most of it is that each double passes through a general register.

## Open
- The fifth item of the backlog: blocking and tasks for the product, a loop over words for
  a number as an operand, and whether packed instructions are worth adding.

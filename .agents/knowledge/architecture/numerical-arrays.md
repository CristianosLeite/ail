---
title: Numerical arrays (lib/nd)
last-verified: 2026-11-21
sources: [conversation 2026-11-21, docs/BACKLOG.md, docs/language.md, docs/performance.md, lib/nd/, tests/lib_nd_*, tests/nd/gen.py, tests/lib/ndfix.aiw, bench/algo/harness.aiw, tools/perf.aiw, tests/algo.sh]
status: current
---
# Numerical arrays (lib/nd)

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aiw`,
> `tools/par.aiw`, `tools/tokens.aiw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aiw`, `tools/lib/fmt.aiw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aiw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aiw` there.

**Summary.** `lib/nd/` is arrays of doubles or 64-bit integers on the model of NumPy:
a descriptor of 176 bytes owned by the caller, views that move no element, elementwise
kernels with broadcasting into a result the caller made, sums, means, dot and matrix
products. It is checked against results of NumPy 2.3.5 that are committed as data, and
timed against C: 3.65 times the time of plain C loops in the geometric mean of 14 kernels
when first measured, 2.18 times since the loops take two doubles at once.

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
- `tests/nd/gen.py` is the one Python file of the repository. It writes `tests/lib/ndfix.aiw`
  and is never run by `make test`; `tests/nd/bench.py` times NumPy for the docs.
- The array programs `ndelem`, `ndreduce`, `ndmatmul` call `algonum` of the harness, which
  gives every language the same doubles (20 bits / 1024 - 512), so results are the same
  bytes in AIL, C and Rust. C must not be built with `-ffast-math` for that to hold.
- Measured 2026-11-21 (i7-12700H): 1.24 times C where memory is the limit (a million
  numbers), 6 times at a thousand, 10 times for an array times one number (it takes the
  loop with strides), 3.5 times for sums and dot, 5 times for the product of matrices.
  The likely cause for most of it is that each double passes through a general register.

- After the measurements (2026-11-21): the gap to C was mostly the way of each double
  through a general register, not the missing vector instructions (AIL was 2.3 to 3.5 times
  behind C built with `-fno-tree-vectorize`). `padd`, `psub`, `pmul`, `pdiv`, `pmadd` are
  rows of `optab` that work from memory to memory on two doubles with the bits of one at a
  time; the library uses them where each element of the result is computed alone.
- `ndsum`, `ndmean` and `nddot` keep the order of adding, so they cannot be packed. They
  were 3.5 times C as loops of `fadd`; `fsum a p n s as x` and `fdot a p q n as x`, rows of
  `optab` whose code is the whole loop with the sum in `xmm0`, bring them to 1.00 to 1.03
  times C with the same bits (`ndacc` is an `fsum`). A statement that is a loop was chosen
  over floating-point registers for variables, which would change the allocator.
- `ndrun` turns a run round when the result has the stride -8 and the others -8 or 0, so
  views taken backwards use the packed loops: 3.7 to 4.0 times less time at a thousand
  numbers. Mixed strides still go one element at a time.
- `ndelem` has a short way (`ndlike`) for doubles on one axis apart from the result: 19 ns
  a call instead of 64 at 16 elements. The harness clock was a system call in AIL until 2026-11-21, 91 ns a
  run against 12 ns in C: rows of `perf` with many short runs measured before overstate
  AIL / C by that. It is now the vDSO function, 13 ns a run.
- `ndaxpy` takes four `pmadd` a round: 19 to 22% less time for the product at sides 100 and
  300, 12% at 1000, nothing at 30.
- Blocks in `ndmatmul` gained 4% at a side of 1000 and were left out: the loop computes,
  it does not wait for memory. `ndmatmulp` (`lib/nd/par.aiw`) runs disjoint rows as tasks,
  5.5 times faster at a side of 1000 on 20 processors, slower than one task at a side of 30
  with 64 tasks.
- Tasks for a product (`bench/nd/mmtasks.sh`): with the pool started they pay from 13
  microseconds of work (8 tasks, not 64); the first call starts threads, 60 to 180
  microseconds, and pays from a side of about 100. As many tasks as threads; more only
  where a task is milliseconds. A task is a run of rows, so few long rows share out badly.
- `ndruns` cuts the rows into runs of the rows divided by the tasks, rounded up, so fewer
  tasks are made than asked for where that does not go round (16 rows, 14 asked: 8). A
  balanced split with a block for every task asked for was measured on 2026-11-21: 5% to 19%
  faster where a task is 10 microseconds or more, up to 58% slower where it is one, the
  same on the geometric mean; the split was kept.
- A program that ran tasks must end with `sys exit_group` or at its last line; a test that
  ended with `sys exit` hung with its workers alive.
- Left out until a program needs them: elements of 32 bits, indexing by arrays, `.npy`,
  linear algebra, FFTs, array syntax (a call is 5 to 7 tokens; the descriptors are the cost).
- `ndsumpw` adds a run of up to 128 doubles that lie one behind the other two at a time
  (`ndpack`, 2026-11-21): sixteen sums in a `local`, eight `padd` a round. With four sums it
  was slower than `fsum` at 10000 and a million elements (4401 and 342890 ns a call against
  3856 and 327931), since a `padd` on memory waits for the store of the one before on the
  same sums; with sixteen it is 271, 3279 and 265725 ns at a thousand, 10000 and a million
  against 414, 3856 and 327931, and `ndsum` 448, 4385 and 439458. A million times 0.1 is
  then exactly 100000; `tests/lib_nd_sum` requires every count from 1 to 300 to give the
  exact sum. Integers and other strides keep `ndacc`.

## Open
- None.

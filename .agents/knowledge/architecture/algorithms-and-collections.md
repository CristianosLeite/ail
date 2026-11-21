---
title: Algorithm benchmarks and collections
last-verified: 2026-11-20
sources: [conversation 2026-11-20, docs/TODO.md, docs/performance.md, bench/algo/, tools/perf.aw, tests/algo.sh, lib/vec.aw, lib/queue.aw, lib/heap.aw, lib/map.aw]
status: current
---
# Algorithm benchmarks and collections

**Summary.** Six algorithm programs (`quicksort`, `mergesort`, `heapsort`, `bsearch`,
`hashtab`, `graph`) exist in AIL, C and Rust over one harness, and `perf` times their kernels
apart from their setup: AIL takes 1.75 times as long as C in the geometric mean of 48 kernel
times, against 1.04 on the five CPU-bound programs. `lib/` has a vector, a bounded queue, a
min-heap and a hash map.

## Facts
- A program is its kernel and the call of `bench/algo/harness.aw` (`harness.h`, `harness.rs`):
  five words on stdin (seed, count, shape, runs, mode), input from splitmix64, the monotonic
  clock around the kernel only; mode 0 writes a checksum and the nanoseconds of each kernel,
  1 the input, 2 the result. A short input or a count of 2^28 or more is status 1.
- `tests/algo.sh` (in `make test`, which therefore depends on `make all`) checks AIL, and C
  if there is a `gcc`, against `sort(1)` and awk at the counts 0, 1, 2, 3 and 1000. Rust is
  only compared with C, by `perf` and `tools/bench.sh`.
- Words are compared as 16 hexadecimal digits: awk has no 64-bit integers, and digits of a
  fixed width sort as the numbers do. The script writes its input with octal escapes, since
  the `printf` of dash has no `\x`.
- Measured on 2026-11-20 (i7-12700H, gcc 15.2 `-O3`): `bsearch` within 10% of C; sorts on
  random input 1.3 to 1.8 times; `hashtab` and `graph` at a thousand elements up to 3.8 times.
  The likely cause, not measured, is calls of small functions in inner loops (`place`, `sift`),
  which gcc puts in line, and loops over arrays with several live variables.
- `quicksort` (median of three, three-way pass) takes five to seven times as long on a
  million words in order as on random ones, in every language.
- The collections: descriptors owned by the caller, empty when all zero; a size is checked
  before it is multiplied (`n>>61` before `n*8`); a descriptor changes only after `alloc`
  succeeded; a second result says whether there was a value, since 0 is one. `heap` stores in
  a `vec`. `map` marks a key taken out and rebuilds at three quarters of places used or marked.
- `tests/lib_vec_no_memory` and `tests/lib_map_no_memory` reach a refused `alloc` by limiting
  the address space with `setrlimit` (64 MiB), which is not a built-in syscall name: the test
  declares `const setrlimit 160`.

- Follow-up of the same day, AIL against C over the 48 kernel times after each step: 1.753 at
  first, 1.639 with scaled indexes in loads and stores (`xaddr`, `xms`), 1.325 with registers
  given by weight (`vment`, `vms`, `alloc`), 1.257 with a `while` on two comparisons joined by
  `&` as two jumps (`xjcond`, `xsc`). `mergesort` is at 1.06, `bsearch` 0.97, `hashtab` 1.61.
- With registers by weight, `place` of `hashtab` written in line by hand is faster in 11 of
  12 kernel times (up to 47%); with registers in order of definition it had been up to 30%
  slower. Splitting a compound loop condition likewise only paid after that change.
- Statements and the expressions that say the same must mention variables equally often, or
  `randvars` finds other bytes: the list of mentions drops none (a first version that
  dropped mentions out of source order failed there).
- `build/tools/par --grid`: tasks of 30 microseconds to 3 milliseconds gain alike at every
  number of threads; one task a thread loses a sixth to a quarter at 14 and 20 threads.

## Why
- **A shared harness instead of programs that stand alone:** the token count of an example is
  then that of the algorithm, and the three languages cannot differ in their input. The
  examples of this kind are the first with a `use` line.
- **The time taken inside the program:** elapsed time of a process has its start and the
  making of the input in it, which at a thousand elements is most of it.
- **Rust as well as C** although the backlog asked for C: chosen by the user when asked, so
  that `tools/bench.sh` and the token table keep their columns.
- **The ten-program corpus is unchanged:** its totals are what earlier measurements and the
  criteria of the redesign refer to; the six are tabled apart.
- **No token column in `perf`:** `tools/tokens.sh` lists the same files; a second count would
  be a second place to keep right.
- **`vecset` beside the proposed names:** a vector that cannot be written by index needs a
  pop and a push for every change.

## Open
- Inlining of small functions in the compiler (item 5 of the performance follow-up).
- `bsearch` at a thousand elements became 22 to 24% slower with registers by weight (still ahead of C); not looked into.
- Stack slots are addressed with a 4-byte displacement, and a value stored to a slot is loaded again on the next line.
- `tests/algo.sh` does not run the Rust programs.
- No collection has been timed on its own.

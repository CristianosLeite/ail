---
title: Algorithm benchmarks and collections
last-verified: 2026-11-21
sources: [conversation 2026-11-20, commits 2ba9ed2 91d8f7b, docs/BACKLOG.md, docs/performance.md, bench/algo/, tools/perf.aw, tests/algo.sh, lib/std/vec.aw, lib/std/queue.aw, lib/std/heap.aw, lib/std/map.aw]
status: current
---
# Algorithm benchmarks and collections

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aw`,
> `tools/par.aw`, `tools/tokens.aw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aw`, `tools/lib/fmt.aw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aw` there.

**Summary.** Six algorithm programs (`quicksort`, `mergesort`, `heapsort`, `bsearch`,
`hashtab`, `graph`) exist in AIL, C and Rust over one harness, and `perf` times their kernels
apart from their setup: AIL takes 1.75 times as long as C in the geometric mean of 48 kernel
times, against 1.04 on the five CPU-bound programs. `lib/` has a vector, a bounded queue, a
min-heap and a hash map.

## Facts
- Since 2026-11-21 the kernels are in `lib/algo/` (`sort.aw`, `search.aw`, `hash.aw`,
  `graph.aw`, a prefix a file since the harness owns `algo`) and a program of `examples/` is
  `use` lines, at most an adapter, and the call of the harness. The six programs compile to
  the bytes they had with the kernels in them, because the library is used where the kernel
  stood, behind the harness. `isort` calls `sortins` and carries the three other sorts too.
  The six callers are 260 tokens (C 1613, Rust 1783); the library functions 1793, more than
  the kernels were (about 1300), since every name has a prefix. The fixed corpus of ten is
  941 tokens with the new `isort`, from 990.
- A program is its kernel and the call of `bench/algo/harness.aw` (`harness.h`, `harness.rs`):
  five words on stdin (seed, count, shape, runs, mode), input from splitmix64, the monotonic
  clock around the kernel only; mode 0 writes a checksum and the nanoseconds of each kernel,
  1 the input, 2 the result. A short input or a count of 2^28 or more is status 1.
- The clock in AIL is `__vdso_clock_gettime`, found by `algoclk` through `/proc/self/auxv`
  and the ELF tables of the vDSO and called with `callp f 0 1 algots` (values after the
  address go to `rax`, `rdi`, `rsi`); the system call is the fallback. An empty kernel
  costs 13 ns a run, as in C and Rust (12), where the system call cost 91. AIL does not
  align the stack at a call; the vDSO has no aligned store to it (`tests/algo_clock`).
- `tests/algo.sh` (in `make test`, which therefore depends on `make all`) checks AIL, C
  if there is a `gcc` and, since 2026-11-21, Rust if there is a `rustc`, against `sort(1)`
  and awk at the counts 0, 1, 2, 3 and 1000; the nine Rust programs passed at once. A
  check knows its program by the name of the file, so the Rust builds are in a directory
  of their own. `perf` compares Rust with C besides. `hashtab` is also run at 8 keys of
  few values and at 261 keys, where a lookup goes round the end of the table; the function
  `wraps` of the script proves that with a table in shell, so a change to the harness that
  loses the wrap fails the test instead of passing unseen.
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
- The compiler changes that followed, and the figure after each (1.753 to 1.201), are on
  [their own page](generated-code-follow-up.md).

- The collections are timed since 2026-11-21 by `examples/collseq.aw` (vec, queue, heap) and
  `examples/collmap.aw` (put, get, del on one map), with C (by hand, `malloc`) and Rust (`Vec`,
  `VecDeque`, `BinaryHeap`, `HashMap`) in `bench/`, over `algocoll` of the harness, rows of
  `perf`, references in `tests/algo.sh`. Chosen by the user: against C and Rust, not AIL alone.
  At a million keys AIL / C is 1.07 (heap), 1.12 to 1.73 (map), 2.0 to 2.2 (vec, queue). At a
  thousand keys it is 16 (vec), 10 (queue), 7 (put), because every `alloc` is an `mmap` and
  every `free` a `munmap`: 10000 pairs in 2000 runs of `collseq`, 34 system calls in all in C
  (`strace -c`). Geometric mean over 21 kernel times 2.816. A collection made and dropped in
  a loop is better made once and used again; an allocator that reuses blocks is not in the language.

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
- None.

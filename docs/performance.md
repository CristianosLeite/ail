# Performance

`tools/perf.aw`, built as `build/tools/perf` by `make tools`, times every example against the C, Rust and assembly program in `bench/` that does the same. It is the measurement behind the performance goal of the redesign: elapsed time on CPU-bound programs close to C built with `-O3`. For the six algorithm programs it also reports the time of the kernel alone, on several inputs each ([below](#algorithms-2026-11-20)).

```
make all tools
build/tools/perf              # every program
build/tools/perf compute      # some programs only
build/tools/perf --quick      # few rounds, to see that it runs
build/tools/perf --cpu 4      # another CPU than 2
build/tools/perf --qsort      # the sorts against the qsort of the C library too
```

## Method

- C is built with `gcc -O3`, Rust with `rustc -O`, assembly with `as` and `ld`; the AIL program is `build/<name>`, so run `make` first. A language without a source for a program is left out of its row.
- Every executable must give the expected output and exit status for the input before anything is timed. Where the output is a computed value, all languages must give the same bytes as C.
- A run is a child process of `lib/proc.aw` and the wait for it (`fork`, `dup2`, `execve`, `wait4`), timed with the monotonic clock, with stdin from a file and stdout to `/dev/null`, the tool pinned to one CPU. Until 2026-11-20 the tool was a Python script that started the child with `posix_spawn`; [the two are compared below](#the-measuring-tool-in-ail-2026-11-20). Each round runs every language once, in an order shuffled from a fixed seed, so that drift of the machine falls on all of them alike.
- The figure is the median, followed by the first and third quartile, which show the variation from run to run.
- The input is read at run time, so no compiler can compute the result while compiling.

The programs are of two kinds, reported apart:

- **Startup**: `hello`, `echo`, `count`, `fact` and `loop` do almost nothing, so their time is the cost of starting a process. 25 warm-up rounds and 500 timed ones, in microseconds.
- **CPU-bound**: five programs that read their input, compute and write a 64-bit result. 2 warm-up rounds and 15 timed ones, in milliseconds. For these the table gives the ratio of AIL to C and, below it, the geometric mean of the ratios; a ratio above 1.10 is marked `slow`.

- **Algorithms**: `quicksort`, `mergesort`, `heapsort`, `bsearch`, `hashtab` and `graph` are a kernel each and its call of `bench/algo/harness.aw`. They are run on several inputs, take the time of the kernel themselves and are reported in tables of their own; [the section below](#algorithms-2026-11-20) says how. The same rounds as the CPU-bound programs.

| program | what it does | what it exercises |
|---|---|---|
| `compute` | a hundred million steps of `x = (x ^ (x >> 13)) * 1664525 + 1013904223` | arithmetic in one dependent chain |
| `sieve` | counts the primes below 16000000 in a table of bytes | byte stores at a stride, a nested loop |
| `collatz` | adds up the lengths of the Collatz sequences from 1 to 500000 | a branch that cannot be predicted, `% 2`, `/ 2`, `* 3` |
| `fnv` | hashes a megabyte a hundred times with FNV-1a | byte loads, a multiplication per byte |
| `isort` | sorts 30000 numbers by insertion | 64-bit loads and stores, a comparison per step |

The last four have no assembly equivalent, and neither have the algorithm programs. At the baseline below the four were written as the language then was, one operation a line with labels and jumps, and at top level with at most six variables, since a seventh would live in memory there.

## Baseline, 2026-11-20

12th Gen Intel Core i7-12700H, CPU 2 (a performance core), Linux 7.0; gcc 15.2.0, rustc 1.99.0.

Startup, microseconds:

| program | AIL | C | Rust | asm |
|---|---:|---:|---:|---:|
| hello | 74.66 (65.37, 80.18) | 232.38 (222.04, 241.62) | 320.15 (309.77, 336.92) | 75.53 (67.61, 81.14) |
| echo | 76.67 (68.32, 83.16) | 229.88 (218.91, 241.64) | 316.27 (304.98, 335.08) | 74.43 (66.48, 81.54) |
| count | 79.57 (70.92, 85.16) | 233.25 (225.81, 242.72) | 323.65 (316.54, 334.15) | 77.70 (69.66, 83.83) |
| fact | 74.44 (65.55, 79.72) | 224.76 (219.08, 233.25) | 313.32 (308.01, 320.15) | 74.28 (64.93, 79.14) |
| loop | 79.44 (70.12, 85.42) | 231.97 (222.72, 239.93) | 323.82 (311.43, 332.38) | 78.31 (71.04, 83.72) |

An AIL program starts in a third of the time of the C one and a quarter of the Rust one, like the assembly program: it is a static file of a few hundred bytes with no loader and no runtime to set up.

CPU-bound, milliseconds:

| program | AIL | C | Rust | asm | AIL / C |
|---|---:|---:|---:|---:|---:|
| compute | 134.38 (133.89, 134.75) | 131.70 (131.59, 131.81) | 131.90 (131.78, 132.73) | 131.42 (131.32, 131.94) | 1.020 |
| sieve | 60.77 (60.46, 61.51) | 50.82 (50.62, 51.40) | 52.41 (51.95, 52.97) |  | 1.196 slow |
| collatz | 325.56 (325.21, 325.86) | 77.92 (77.80, 78.49) | 57.66 (57.54, 57.76) |  | 4.178 slow |
| fnv | 92.76 (92.43, 93.21) | 92.73 (92.60, 93.20) | 93.01 (92.84, 93.51) |  | 1.000 |
| isort | 158.28 (158.11, 158.94) | 50.36 (50.25, 50.59) | 70.79 (70.63, 71.08) |  | 3.143 slow |

Geometric mean of AIL / C: 1.742.

What the figures say about the code the compiler writes today:

- `compute` and `fnv` are within 2% of C although AIL runs three times the instructions: the loop of `compute` is 22 against 7, every operand copied to `rax` or `rdi`, `13` and the two constants loaded on every step, and `jnz` testing its value again. The steps depend on each other, so the time is the latency of the shift, the multiplication and the additions in a row, and the extra moves run beside them. One program of that shape had made the compiler look finished.
- `collatz` is four times slower. `mod x 2` and `div x 2` are a 64-bit `div` each, where C tests a bit and shifts; and C computes `3x + 1` with one `lea` and folds the halving that must follow an odd step into it.
- `isort` is three times slower: its inner loop has nothing but moves, a load, a store, a comparison and two jumps, so the copies through `rax` and `rdi` and the jump to the test at the top are the whole cost.
- `sieve` is 20% slower for the same reason, less so because its inner loop waits for memory.

At that point the work was in three places: a constant operand used as an immediate, with division and remainder by a power of two as a shift and a mask; operands used where they are instead of copied; and a loop with its test at the end.

## After instruction selection, 2026-11-20

Same machine, same compilers, and the same sources of the examples, still written with one operation a line, labels and jumps. What changed is the compiler: immediate operands, variables used where they live, an assignment computed in the register of its variable, statements compiled like the expressions that say the same, a test left out behind the instruction that computed its value, and loads and stores with the address as the operand of the instruction.

| program | AIL | C | Rust | asm | AIL / C | before |
|---|---:|---:|---:|---:|---:|---:|
| compute | 131.72 (131.52, 132.47) | 131.79 (131.71, 132.16) | 132.02 (131.83, 132.46) | 131.58 (131.51, 132.10) | 0.999 | 1.020 |
| sieve | 53.01 (52.81, 53.69) | 50.91 (50.50, 51.35) | 52.19 (51.89, 52.78) |  | 1.041 | 1.196 |
| collatz | 95.69 (95.61, 95.89) | 78.09 (77.90, 78.31) | 57.56 (57.49, 57.69) |  | 1.225 slow | 4.178 |
| fnv | 92.59 (92.37, 93.22) | 93.08 (92.86, 93.66) | 92.97 (92.93, 93.15) |  | 0.995 | 1.000 |
| isort | 79.55 (79.44, 79.98) | 50.18 (50.11, 50.33) | 70.66 (70.58, 71.03) |  | 1.585 slow | 3.143 |

Geometric mean of AIL / C: 1.150, from 1.742. Startup is unchanged, 67 to 72 microseconds against 209 to 217 for C.

Three programs are within 5% of C. Two are not, and the disassembly says why:

- `isort`: the inner loop is 11 instructions with three jumps a round against 7 with two in C. The source has the loop as a label with two tests and a `jmp` back, so the jump back is a third jump; it compares the place with the start of the table by loading that address every round (`lea` / `cmp`), where C keeps it in a register; and it moves the place through a second variable (`sub p 8 as q` ... `set q as p`), where C indexes with a scale.
- `collatz`: C tests the low bit, computes `3x+1` with one `lea`, and lets the halving that must follow an odd step run in the same round. AIL takes the two branches of the block as written, each ending in a jump, and the time of this loop moves by 8% with where its code happens to lie, since its one branch cannot be predicted.

Part of that is in how the examples are written and goes away when they are written with `while` and expressions; that is measured after the examples are rewritten. What would remain needs analysis across statements, which this compiler does not do: keeping an address that does not change in a loop in a register, and a scaled index.

## With the examples rewritten, 2026-11-20

The examples now use expressions, `while` and loads and stores with an address expression; `collatz` and `isort` have their loops as `while` blocks, `isort` leaving its inner one by a jump when the place is found.

| program | AIL | C | Rust | asm | AIL / C |
|---|---:|---:|---:|---:|---:|
| compute | 132.38 (132.10, 132.46) | 132.53 (132.37, 132.60) | 132.67 (132.58, 132.94) | 132.43 (132.20, 133.38) | 0.999 |
| sieve | 52.35 (52.19, 53.17) | 50.74 (50.62, 50.94) | 52.42 (52.08, 52.59) |  | 1.032 |
| collatz | 88.24 (88.15, 88.31) | 78.44 (78.35, 78.72) | 57.96 (57.88, 58.04) |  | 1.125 slow |
| fnv | 92.99 (92.80, 93.16) | 93.48 (93.08, 93.85) | 93.62 (93.40, 94.23) |  | 0.995 |
| isort | 53.44 (52.41, 54.18) | 50.39 (50.31, 50.54) | 70.88 (70.81, 71.06) |  | 1.061 |

Geometric mean of AIL / C: 1.041, within the 5% the redesign set as its first threshold. `isort` went from 1.59 to 1.06 by being written as it would be in any language with a loop statement: the test of the loop at its end, and `load p-8 as v` instead of a second variable for the place; it is a quarter faster than the Rust program, which checks its indexes. `collatz` is the one program more than 10% behind C, for the reason given above: C folds the halving after an odd step into the same round and computes `3x+1` with one `lea`, and AIL compiles the two branches as written.

## Against the criteria of the redesign, 2026-11-20

`REDESIGN.md` set four criteria. This is where each stands, measured with the final compiler, the one written with expressions and built from seed 2.

**Source cost: met.** The corpus is fixed at ten programs, the six that existed and four added for arithmetic, control flow and memory access. AIL was 970 tokens, Rust 1191, C 1118, with AIL below C in all ten programs and above Rust in two, `count` (118 against 102) and `fnv` (141 against 126). Since the examples are indented, later the same day, AIL is 990: still below Rust, below C in nine and two tokens above it in `collatz` (121 against 119), with `fnv` at 144; [tokens.md](tokens.md) lists every program.

**CPU performance: the threshold is met, parity is not.** Geometric mean of elapsed time against `gcc -O3` over the five CPU-bound programs: 1.039, inside the 5% set as the first threshold.

| program | AIL | C | Rust | asm | AIL / C |
|---|---:|---:|---:|---:|---:|
| compute | 131.56 (131.19, 131.91) | 131.68 (131.38, 132.19) | 131.81 (131.73, 132.35) | 131.51 (131.23, 131.62) | 0.999 |
| sieve | 52.34 (52.08, 52.75) | 50.62 (50.51, 50.98) | 52.41 (52.09, 53.05) |  | 1.034 |
| collatz | 87.70 (87.59, 87.91) | 77.90 (77.71, 78.06) | 57.55 (57.47, 57.93) |  | 1.126 slow |
| fnv | 92.24 (92.14, 92.64) | 92.48 (92.42, 92.79) | 92.79 (92.49, 92.95) |  | 0.997 |
| isort | 52.20 (51.54, 52.90) | 50.02 (50.01, 50.17) | 70.38 (70.31, 70.48) |  | 1.043 |

One program is more than 10% slower than C and is reported as the criterion asks: `collatz`, 12.6%. Every figure is a median of 15 runs with its quartiles, on runtime input, after each executable gave the result of the C program; the compilers, flags and machine are those at the top of this page. Startup is reported apart: 68 to 73 microseconds for AIL, as for assembly, against 210 to 216 for C and 293 to 304 for Rust.

**Authoring effort: met.** `count` writes each digit in one line (`storeb out+1 48+n/100%10`) with no variable for a digit or an address, and `compute` is a `while` around one assignment, with no label. Beyond the representative routines the criterion asks for, the whole compiler was rewritten by `tools/infix.py` (now `tools/infix.aw`): 21% fewer tokens, 725 intermediate variables gone, 12 loops as `while`.

**Bootstrap: met.** `stage0/ailc.s` is removed. A clean worktree with an empty build directory and no local seed fetches seed 2 by the checksum in `seed/MANIFEST`, builds the compiler in three generations, passes `make test` (2065 checks) and has `build/ailc` and `build/ailc2` as one file.

Where the work departed from the document:

- **Expressions have no spaces.** The document sketched `x = (x ^ (x >> 13)) * 1664525 + 1013904223` with a comma between arguments and left the boundaries to be settled by counting. The count chose `x=(x^x>>13)*1664525+1013904223`, with spaces separating arguments as before: 975 tokens for the corpus against 1104 for the sketched form.
- **Three generations, not two.** The document builds the sources with the seed and then with the result, and compares those two. Once the compiler writes other code than its seed did, those two differ in bytes without differing in behaviour, so the comparison is between the second and a third build.
- **No intermediate representation across statements.** Expressions are parsed into a list of nodes and lowered together, each statement on its own, as the document says to start. What remains behind C would need more: an address that does not change in a loop kept in a register, a scaled index, and the folding of one branch into another that C does in `collatz`.
- **A step was added**, loads and stores with the address as an operand, when the measurements after instruction selection showed where `isort` and `sieve` lost.
- **The old forms were not kept as copies of the examples.** The statements remain in the language and compile to the same code as the expressions that say the same, which `tools/randvars.aw` checks byte for byte; about 900 tests are still written with them.
- **The seed is a release of a private repository**, so fetching it needs `gh` and a login, or a local copy; `curl` alone works once the repository is public.

Not done: the comparison of these token counts, taken with an OpenAI encoding, with Claude's tokenizer, which stays an open item.

## The measuring tool in AIL, 2026-11-20

The figures above were taken by `tools/perf.py`, a Python script. The tool is now `tools/perf.aw`, which checks, times and reports as the script did: the same programs, inputs and expected results, the same rounds, the median and quartiles of the same samples, the same tables. Two things differ, and one of them touches the figures.

- **How a child is started.** The script called `posix_spawn` from the Python interpreter; the tool calls `procstart` of `lib/proc.aw`, which is `fork` and then `dup2` and `execve` in the child. The time of a run includes that start, and for the startup programs it is most of what is measured. Both tools were run one after the other, twice, on the same machine and CPU as above (median of 500 rounds, microseconds):

| program | AIL, script | AIL, tool | C, script | C, tool |
|---|---:|---:|---:|---:|
| hello | 70.84, 72.69 | 71.78, 69.30 | 218.92, 227.86 | 223.00, 214.42 |
| echo | 75.25, 76.79 | 74.16, 71.81 | 229.78, 231.85 | 223.72, 215.26 |
| count | 76.64, 80.91 | 71.99, 70.31 | 226.71, 242.46 | 218.25, 211.25 |
| fact | 72.75, 74.69 | 68.95, 67.40 | 229.67, 231.28 | 211.91, 206.97 |
| loop | 78.93, 78.21 | 71.80, 70.44 | 235.43, 231.46 | 214.94, 209.74 |

  Taking the two runs of each together, the tool's figures are lower than the script's: by 1 to 8 microseconds for AIL and by 5 to 21 for C, between 2 and 10 percent. For AIL that is within the quartiles of either tool, which lie 4 to 9 microseconds from the median; for C it is beyond them in three of the five programs. A `fork` of a process of a few pages costs less than a `posix_spawn` out of an interpreter, and a parent that runs no interpreter between two children leaves them warmer caches, which a program that loads a C library uses more of. The ratio between the languages is what it was, an AIL program starting in about a third of the time of the C one with either tool (`hello` 0.32 and 0.32, `count` 0.34 and 0.33). So startup figures taken by the tool are not to be mixed with the older tables above, only compared within a table; the CPU-bound figures, in milliseconds, do not see the difference. The script's start could have been matched with `clone` and `CLONE_VFORK`, but not its interpreter, so the plain `fork` stays and the figures are marked by date.
- **The order of a round** is shuffled with splitmix64 (`tools/lib/rng.aw`) from the seed 77, where the script used Python's generator with that seed: other orders, drawn the same way.

The geometric mean is the n-th root by Newton's steps in doubles, where Python used `pow`; on 20000 random products of up to ten ratios the two print the same three digits. A run of every program with the tool gave 1.000, 1.029, 1.126, 0.999 and 1.043 for the five CPU-bound programs and a geometric mean of 1.038.

## Algorithms, 2026-11-20

The five CPU-bound programs above are loops over a few variables. The six algorithm programs ask what the compiler makes of code that calls functions and walks arrays: three sorts, a binary search, a hash table and a graph traversal, each the same algorithm with the same arrays in AIL, C and Rust.

A program reads five words from stdin: a seed, a count, a shape, a number of runs and a mode (`bench/algo/harness.aw`, with `harness.h` and `harness.rs` for the other two languages). It makes its input from the seed with splitmix64, so the three languages work on the same words, and then runs its kernel that many times, each time on a fresh copy of the input. The copy, the making of the input, the clearing of a table and the checksum are outside the timed region: the monotonic clock is read just before and just after each call of the kernel (`clock_gettime` in AIL and C, `Instant` in Rust), and the sum over the runs is written behind a checksum of the last result. `perf` sends that output to a file, reads it after every run, requires the checksum of C in it, and reports the time of the kernel apart from the elapsed time of the process, which also has the start of the process and the setup in it.

The inputs are rows of a table in `tools/perf.aw`: a thousand elements with enough runs for some tens of milliseconds, and a million with one to four runs, in up to four shapes. `random` is words of 64 bits; `sorted` and `reversed` rise and fall by steps below 65536; `few` is values below 16 for a sort, steps below 2 for `bsearch`, 128 distinct keys for `hashtab` and at most one neighbour a vertex for `graph`, where `random` is up to 15. A small array lies in the first cache and shows the instructions; a large one shows the memory as well.

Before anything is timed the whole result, not its checksum, must be the same bytes as that of C at the counts 0, 1 and 1000 in the shape of the row. That the results are right, and not only alike, is checked by `tests/algo.sh` in `make test`: the sorts against `sort(1)`, the others against awk programs, the empty and the one-element array among the counts.

The time of the kernels (same machine, CPU and compilers as above; the column `C qsort` is `bench/qsort.c`, the sort of the C library with a comparison function, on the same input):

| program, input, count x runs | AIL | C | Rust | C qsort | AIL / C |
|---|---:|---:|---:|---:|---:|
| quicksort, random, 1000 x 1000 | 24.66 (24.53, 25.47) | 13.65 (13.41, 14.07) | 20.63 (20.44, 20.78) | 33.19 (32.75, 33.41) | 1.807 slow |
| quicksort, sorted, 1000 x 1000 | 26.76 (26.50, 27.09) | 10.89 (10.85, 10.95) | 13.92 (13.89, 14.01) | 14.02 (13.96, 14.14) | 2.457 slow |
| quicksort, reversed, 1000 x 1000 | 22.93 (22.69, 23.14) | 9.46 (9.42, 9.51) | 12.27 (12.11, 12.34) | 15.40 (15.32, 15.45) | 2.425 slow |
| quicksort, few, 1000 x 1000 | 6.11 (6.07, 6.16) | 2.85 (2.83, 2.88) | 2.93 (2.89, 2.94) | 25.94 (25.56, 26.34) | 2.145 slow |
| quicksort, random, 1000000 x 1 | 84.08 (83.80, 84.37) | 66.06 (65.90, 66.52) | 72.07 (71.96, 72.36) | 94.63 (94.37, 95.57) | 1.273 slow |
| quicksort, sorted, 1000000 x 1 | 603.89 (598.82, 608.61) | 342.10 (338.97, 355.07) | 361.18 (356.02, 362.84) | 26.58 (26.37, 26.72) | 1.765 slow |
| quicksort, reversed, 1000000 x 1 | 427.82 (425.07, 438.50) | 240.25 (218.28, 254.84) | 237.76 (235.80, 248.70) | 28.63 (28.43, 28.88) | 1.781 slow |
| quicksort, few, 1000000 x 4 | 59.12 (58.88, 59.38) | 45.78 (45.46, 46.04) | 48.57 (48.36, 48.93) | 237.17 (236.64, 237.79) | 1.291 slow |
| mergesort, random, 1000 x 1000 | 29.95 (29.69, 30.32) | 18.27 (17.91, 18.69) | 15.80 (15.69, 15.98) | 33.18 (32.66, 33.46) | 1.640 slow |
| mergesort, sorted, 1000 x 1000 | 14.32 (14.22, 14.44) | 5.25 (5.23, 5.29) | 5.14 (5.11, 5.19) | 14.04 (14.03, 14.07) | 2.726 slow |
| mergesort, reversed, 1000 x 1000 | 14.92 (14.85, 15.01) | 5.14 (5.12, 5.14) | 4.64 (4.63, 4.67) | 14.53 (14.43, 14.59) | 2.904 slow |
| mergesort, few, 1000 x 1000 | 17.55 (17.49, 17.69) | 8.80 (8.75, 8.91) | 8.52 (8.48, 8.53) | 24.87 (24.77, 25.31) | 1.994 slow |
| mergesort, random, 1000000 x 1 | 100.33 (100.08, 101.05) | 67.39 (66.88, 67.84) | 66.61 (66.28, 66.82) | 94.53 (94.34, 94.64) | 1.489 slow |
| mergesort, sorted, 1000000 x 1 | 30.52 (29.94, 31.10) | 10.98 (10.76, 11.08) | 11.40 (11.10, 11.75) | 27.55 (27.21, 27.89) | 2.778 slow |
| mergesort, reversed, 1000000 x 1 | 31.20 (29.99, 32.06) | 10.92 (10.75, 11.20) | 10.87 (10.62, 11.08) | 29.90 (28.62, 30.15) | 2.858 slow |
| mergesort, few, 1000000 x 1 | 50.84 (50.14, 51.10) | 31.04 (30.54, 31.49) | 30.64 (30.40, 31.16) | 60.24 (60.06, 60.74) | 1.638 slow |
| heapsort, random, 1000 x 1000 | 26.81 (25.79, 27.26) | 18.06 (17.72, 18.63) | 16.53 (16.04, 16.79) | 33.78 (33.25, 34.64) | 1.485 slow |
| heapsort, sorted, 1000 x 1000 | 27.80 (26.89, 28.33) | 13.72 (13.46, 18.10) | 21.15 (20.97, 21.28) | 14.39 (14.30, 14.48) | 2.025 slow |
| heapsort, reversed, 1000 x 1000 | 20.02 (19.04, 20.98) | 11.60 (11.23, 11.71) | 19.51 (19.16, 19.70) | 14.78 (14.63, 15.09) | 1.726 slow |
| heapsort, few, 1000 x 1000 | 17.94 (17.46, 20.37) | 15.45 (15.20, 17.33) | 16.44 (16.35, 16.75) | 24.72 (24.55, 24.94) | 1.161 slow |
| heapsort, random, 1000000 x 1 | 105.62 (105.13, 106.08) | 80.14 (79.61, 80.86) | 71.33 (70.70, 71.55) | 94.67 (94.44, 94.96) | 1.318 slow |
| heapsort, sorted, 1000000 x 1 | 47.75 (47.63, 48.04) | 35.92 (35.89, 36.18) | 31.08 (30.96, 31.28) | 26.31 (26.20, 26.44) | 1.330 slow |
| heapsort, reversed, 1000000 x 1 | 50.74 (50.59, 50.80) | 35.37 (35.09, 35.49) | 30.80 (30.67, 31.14) | 28.65 (28.52, 28.88) | 1.434 slow |
| heapsort, few, 1000000 x 1 | 53.76 (53.45, 54.01) | 38.92 (38.75, 39.10) | 34.54 (34.34, 34.79) | 60.64 (60.46, 61.10) | 1.381 slow |
| bsearch, random, 1000 x 2000 | 57.77 (57.19, 59.35) | 54.37 (53.98, 55.05) | 41.91 (41.40, 42.36) |  | 1.063 |
| bsearch, few, 1000 x 2000 | 57.32 (57.03, 58.56) | 52.88 (52.30, 53.65) | 39.35 (39.08, 39.81) |  | 1.084 |
| bsearch, random, 1000000 x 1 | 132.63 (130.53, 133.97) | 121.01 (119.84, 121.33) | 125.85 (125.19, 127.86) |  | 1.096 |
| bsearch, few, 1000000 x 1 | 131.14 (130.12, 131.83) | 119.44 (118.84, 120.24) | 124.79 (123.83, 126.37) |  | 1.098 |
| hashtab insert, random, 1000 x 5000 | 11.65 (11.61, 11.78) | 5.50 (5.46, 5.60) | 5.81 (5.70, 6.06) |  | 2.117 slow |
| hashtab hit, random, 1000 x 5000 | 13.02 (12.98, 13.05) | 8.61 (8.53, 8.67) | 7.17 (7.13, 7.20) |  | 1.514 slow |
| hashtab miss, random, 1000 x 5000 | 14.71 (14.66, 14.78) | 9.49 (9.40, 9.61) | 10.39 (10.30, 10.48) |  | 1.550 slow |
| hashtab insert, few, 1000 x 5000 | 9.44 (9.42, 9.52) | 4.19 (4.04, 4.33) | 4.69 (4.62, 4.96) |  | 2.253 slow |
| hashtab hit, few, 1000 x 5000 | 11.49 (11.38, 11.53) | 3.38 (3.36, 3.40) | 5.04 (5.03, 5.07) |  | 3.403 slow |
| hashtab miss, few, 1000 x 5000 | 13.20 (13.18, 13.37) | 3.47 (3.44, 3.52) | 5.20 (5.17, 5.23) |  | 3.805 slow |
| hashtab insert, random, 1000000 x 2 | 29.82 (29.47, 30.74) | 21.06 (20.54, 21.98) | 21.40 (21.20, 22.08) |  | 1.416 slow |
| hashtab hit, random, 1000000 x 2 | 34.69 (34.33, 36.15) | 23.65 (23.39, 24.33) | 25.33 (25.07, 26.03) |  | 1.467 slow |
| hashtab miss, random, 1000000 x 2 | 62.36 (61.09, 65.37) | 41.81 (41.27, 42.35) | 41.15 (40.76, 42.08) |  | 1.492 slow |
| hashtab insert, few, 1000000 x 4 | 7.32 (7.30, 7.37) | 3.46 (3.39, 3.47) | 4.13 (4.05, 4.18) |  | 2.115 slow |
| hashtab hit, few, 1000000 x 4 | 10.57 (10.51, 10.62) | 4.58 (4.49, 4.70) | 6.37 (6.25, 6.41) |  | 2.309 slow |
| hashtab miss, few, 1000000 x 4 | 48.45 (47.97, 49.40) | 26.93 (26.68, 27.16) | 30.18 (29.61, 30.61) |  | 1.799 slow |
| graph bfs, random, 1000 x 2000 | 21.76 (21.43, 22.16) | 10.93 (10.72, 11.06) | 9.80 (9.78, 10.05) |  | 1.991 slow |
| graph dfs, random, 1000 x 2000 | 45.77 (45.17, 46.08) | 15.32 (14.99, 15.87) | 18.74 (18.62, 19.21) |  | 2.988 slow |
| graph bfs, few, 1000 x 5000 | 14.55 (14.52, 14.56) | 8.05 (8.01, 8.10) | 8.80 (8.78, 8.82) |  | 1.807 slow |
| graph dfs, few, 1000 x 5000 | 17.79 (17.72, 17.90) | 7.28 (7.26, 7.33) | 14.03 (14.01, 14.22) |  | 2.443 slow |
| graph bfs, random, 1000000 x 1 | 90.59 (89.93, 91.37) | 57.51 (57.01, 58.56) | 74.07 (72.84, 77.64) |  | 1.575 slow |
| graph dfs, random, 1000000 x 1 | 149.44 (147.44, 156.63) | 128.77 (127.87, 135.46) | 135.24 (132.86, 139.69) |  | 1.160 slow |
| graph bfs, few, 1000000 x 2 | 31.65 (30.66, 32.00) | 26.30 (25.60, 27.02) | 27.81 (27.65, 27.98) |  | 1.204 slow |
| graph dfs, few, 1000000 x 2 | 33.30 (33.12, 34.56) | 26.43 (26.15, 26.93) | 30.46 (30.34, 30.58) |  | 1.260 slow |

Geometric mean of AIL / C over 48 kernel times: 1.753

The elapsed time of the same processes:

| program, input, count x runs | AIL | C | Rust | C qsort | AIL / C |
|---|---:|---:|---:|---:|---:|
| quicksort, random, 1000 x 1000 | 25.36 (25.20, 26.15) | 14.10 (13.83, 14.51) | 21.13 (20.99, 21.30) | 33.59 (33.15, 33.82) | 1.798 slow |
| quicksort, sorted, 1000 x 1000 | 27.41 (27.15, 27.80) | 11.30 (11.26, 11.43) | 14.42 (14.36, 14.65) | 14.41 (14.38, 14.60) | 2.425 slow |
| quicksort, reversed, 1000 x 1000 | 23.62 (23.39, 23.84) | 9.90 (9.85, 10.00) | 12.75 (12.60, 12.89) | 15.83 (15.71, 15.88) | 2.385 slow |
| quicksort, few, 1000 x 1000 | 6.81 (6.77, 6.87) | 3.27 (3.24, 3.31) | 3.41 (3.38, 3.46) | 26.33 (25.98, 26.75) | 2.082 slow |
| quicksort, random, 1000000 x 1 | 91.21 (91.06, 91.69) | 72.21 (71.94, 72.72) | 78.98 (78.88, 79.42) | 100.99 (100.59, 101.51) | 1.263 slow |
| quicksort, sorted, 1000000 x 1 | 611.83 (606.55, 616.39) | 348.36 (345.54, 361.69) | 368.20 (362.39, 369.98) | 33.01 (32.69, 33.23) | 1.756 slow |
| quicksort, reversed, 1000000 x 1 | 435.77 (433.10, 446.62) | 246.93 (224.36, 261.02) | 244.20 (242.34, 255.91) | 35.10 (34.97, 35.47) | 1.765 slow |
| quicksort, few, 1000000 x 4 | 67.74 (67.24, 68.71) | 52.82 (52.42, 53.36) | 56.81 (56.25, 57.05) | 245.07 (244.29, 245.72) | 1.283 slow |
| mergesort, random, 1000 x 1000 | 30.63 (30.37, 30.99) | 18.68 (18.35, 19.08) | 16.29 (16.18, 16.47) | 33.58 (33.07, 33.85) | 1.640 slow |
| mergesort, sorted, 1000 x 1000 | 14.99 (14.87, 15.09) | 5.64 (5.60, 5.70) | 5.60 (5.56, 5.66) | 14.43 (14.40, 14.46) | 2.658 slow |
| mergesort, reversed, 1000 x 1000 | 15.59 (15.49, 15.66) | 5.52 (5.50, 5.56) | 5.09 (5.08, 5.11) | 14.89 (14.81, 14.98) | 2.824 slow |
| mergesort, few, 1000 x 1000 | 18.20 (18.16, 18.35) | 9.21 (9.14, 9.35) | 9.00 (8.97, 9.05) | 25.27 (25.18, 25.69) | 1.975 slow |
| mergesort, random, 1000000 x 1 | 108.05 (107.44, 108.50) | 73.79 (73.30, 74.31) | 73.63 (73.30, 73.98) | 100.64 (100.18, 101.02) | 1.464 slow |
| mergesort, sorted, 1000000 x 1 | 38.36 (37.61, 38.97) | 17.64 (17.39, 18.00) | 18.41 (17.86, 18.98) | 34.03 (33.69, 34.44) | 2.175 slow |
| mergesort, reversed, 1000000 x 1 | 39.15 (37.64, 40.02) | 17.54 (17.31, 17.68) | 17.79 (17.39, 18.01) | 36.14 (34.96, 36.32) | 2.233 slow |
| mergesort, few, 1000000 x 1 | 58.24 (57.44, 58.73) | 37.53 (37.00, 38.11) | 37.47 (37.27, 38.51) | 66.40 (65.74, 66.59) | 1.552 slow |
| heapsort, random, 1000 x 1000 | 27.48 (26.46, 28.04) | 18.57 (18.17, 19.06) | 17.05 (16.55, 17.36) | 34.21 (33.72, 35.06) | 1.480 slow |
| heapsort, sorted, 1000 x 1000 | 28.46 (27.58, 29.03) | 14.16 (13.88, 18.54) | 21.71 (21.50, 21.83) | 14.83 (14.73, 14.91) | 2.010 slow |
| heapsort, reversed, 1000 x 1000 | 20.70 (19.70, 21.64) | 12.00 (11.73, 12.18) | 20.13 (19.66, 20.25) | 15.21 (15.05, 15.50) | 1.724 slow |
| heapsort, few, 1000 x 1000 | 18.63 (18.12, 21.07) | 15.85 (15.61, 17.73) | 16.95 (16.88, 17.35) | 25.12 (24.96, 25.37) | 1.175 slow |
| heapsort, random, 1000000 x 1 | 112.73 (112.33, 113.53) | 86.33 (85.71, 87.05) | 78.31 (77.60, 78.63) | 101.13 (100.64, 101.26) | 1.306 slow |
| heapsort, sorted, 1000000 x 1 | 54.73 (54.48, 55.02) | 41.89 (41.76, 42.22) | 37.35 (36.86, 37.75) | 32.30 (31.99, 32.60) | 1.306 slow |
| heapsort, reversed, 1000000 x 1 | 57.79 (57.54, 58.01) | 41.15 (40.88, 41.62) | 37.26 (37.04, 37.52) | 34.64 (34.24, 34.76) | 1.404 slow |
| heapsort, few, 1000000 x 1 | 61.07 (60.39, 61.34) | 45.05 (44.58, 45.35) | 41.44 (41.07, 41.58) | 66.55 (66.13, 67.69) | 1.356 slow |
| bsearch, random, 1000 x 2000 | 58.15 (57.54, 59.78) | 54.75 (54.39, 55.49) | 42.50 (41.92, 42.89) |  | 1.062 |
| bsearch, few, 1000 x 2000 | 57.66 (57.40, 58.97) | 53.24 (52.72, 54.02) | 39.97 (39.62, 40.41) |  | 1.083 |
| bsearch, random, 1000000 x 1 | 142.05 (139.81, 143.39) | 129.53 (128.66, 129.89) | 134.41 (133.76, 136.80) |  | 1.097 |
| bsearch, few, 1000000 x 1 | 140.49 (139.45, 141.30) | 128.00 (127.29, 128.99) | 133.14 (132.33, 134.90) |  | 1.098 |
| hashtab, random, 1000 x 5000 | 62.36 (61.10, 65.30) | 24.79 (24.65, 25.03) | 24.83 (24.46, 24.97) |  | 2.516 slow |
| hashtab, few, 1000 x 5000 | 57.34 (56.26, 66.13) | 12.09 (11.99, 12.33) | 16.26 (16.10, 16.47) |  | 4.742 slow |
| hashtab, random, 1000000 x 2 | 155.35 (154.03, 160.21) | 105.87 (105.00, 108.50) | 109.16 (107.96, 109.98) |  | 1.467 slow |
| hashtab, few, 1000000 x 4 | 107.51 (107.06, 109.32) | 56.08 (55.88, 57.44) | 62.69 (61.88, 63.32) |  | 1.917 slow |
| graph, random, 1000 x 2000 | 70.06 (69.42, 70.59) | 26.80 (26.19, 27.42) | 29.13 (29.02, 29.87) |  | 2.614 slow |
| graph, few, 1000 x 5000 | 38.54 (38.48, 38.66) | 15.89 (15.83, 15.97) | 23.46 (23.41, 23.64) |  | 2.425 slow |
| graph, random, 1000000 x 1 | 285.61 (281.74, 290.74) | 223.39 (222.66, 234.80) | 272.08 (268.99, 276.05) |  | 1.279 slow |
| graph, few, 1000000 x 2 | 78.99 (78.20, 81.58) | 63.56 (63.09, 65.50) | 73.00 (72.81, 73.51) |  | 1.243 slow |

Geometric mean of AIL / C over 36 inputs: 1.714

What the figures say:

- AIL takes 1.75 times as long as C in the geometric mean of the kernels, where the five CPU-bound programs take 1.04. The goal of the redesign was set and met on loops; these programs are where it is not met.
- `bsearch` is within 10% of C at both sizes. Its inner loop is a load, a comparison and a branch that cannot be predicted.
- The small inputs are mostly behind by more than the large ones: the sorts on random input take 1.5 to 1.8 times as long as C at a thousand elements and 1.3 to 1.5 times at a million, the two traversals 2.0 and 3.0 times against 1.6 and 1.2. At a million a part of the time is the memory, which costs every language the same; at a thousand everything is in the first cache and the instructions are all there is.
- Where C is far ahead the kernel calls a small function in its inner loop, which `gcc -O3` puts in line and the AIL compiler does not: `place` in `hashtab` (1.5 to 3.8 times at a thousand keys), `sift` in `heapsort`. That is the likely cause, not a measured one; the merge loop of `mergesort`, which calls nothing, is 1.6 to 2.9 times behind as well, so the code of a loop with five variables in memory operands and two branches is part of it.
- `quicksort` on a million words in order takes five to seven times as long as on random ones, in the three languages alike. The likely cause is the pass that keeps equal words in the middle: it brings the words from the end to the front one by one, which leaves the larger side of an ordered input out of order with its smallest word last, where the median of three picks a poor pivot. The `qsort` of the C library, a merge sort, is 13 times faster there than the C quicksort, and 5 times slower on few values, where the three-way pass has little to do.
- Against the library's `qsort`, which a C program gets without writing a sort, the AIL kernels are faster on random input at both sizes except `mergesort` and `heapsort` at a million, and slower on input in order.

The source of each program, in tokens (`tools/tokens.sh`, the kernel and the two or three lines that hand it to the harness, without comments):

| program | AIL | C | Rust |
|---|---:|---:|---:|
| quicksort | 264 | 297 | 324 |
| mergesort | 309 | 298 | 340 |
| heapsort | 211 | 237 | 271 |
| bsearch | 129 | 156 | 163 |
| hashtab | 230 | 280 | 280 |
| graph | 373 | 345 | 405 |
| total | 1516 | 1613 | 1783 |
| relative to AIL | 1.00 | 1.06 | 1.18 |

## Scaled indexes, 2026-11-20

The first step of the follow-up in the backlog. A load or store whose address ends in a variable times 2, 4 or 8, as `load p+i*8` and `load a+c*8+8`, was an `imul`, an `add` and a `mov`; it is one `mov` now, with the variable as a scaled index in the memory operand (`[rbx+rbp*8+8]`), and a number and an index are both taken into the operand where one of them was before. The same full run of `perf` before and after, AIL against C in the geometric mean of the kernel times of each program:

| program | before | after |
|---|---:|---:|
| quicksort | 1.818 | 1.856 |
| mergesort | 2.175 | 2.068 |
| heapsort | 1.462 | 1.227 |
| bsearch | 1.085 | 0.882 |
| hashtab | 1.993 | 1.883 |
| graph | 1.709 | 1.695 |
| all 48 kernel times | 1.753 | 1.639 |

`heapsort` and `bsearch` index an array in their inner loops and gain most: the kernel of `heapsort` takes 14 to 31% less time, and `bsearch` on a thousand elements 30% less, which puts it ahead of C there (0.74 and 0.76), while on a million, where the memory decides, it gains 6%. `hashtab` gains 4 to 9% and `mergesort` up to 17% on input in order. `quicksort` walks pointers and has one such address outside its loops, so its times moved by less than 2% either way; its ratio differs by what the C times of the two runs differ. `graph` gained up to 7% at a thousand vertices and lost 7% in one row at a million (`bfs`, few neighbours), within what that row varies between runs of the earlier table. The five CPU-bound programs stay at 1.04 (1.038 and 1.039).

## Registers by weight, 2026-11-20

The second step. A function has six registers for its variables, and they went to the first six that were defined, which are the parameters: in `lookup` of `hashtab` the table, the mask and the three arrays had registers, each read once a round, and the key, its place, the value and the word just loaded lived on the stack. The registers now go to the variables that are mentioned most, a mention in a loop counting 8 times for each loop around it ([how](compiler.md)). In the executable of `hashtab` the instructions that name `rsp` went from 228 to 143, and its code from 4613 to 3941 bytes. AIL against C in the geometric mean of the kernel times of each program, before the follow-up, with scaled indexes, and with both:

| program | before | scaled indexes | and registers by weight |
|---|---:|---:|---:|
| quicksort | 1.818 | 1.856 | 1.214 |
| mergesort | 2.175 | 2.068 | 1.200 |
| heapsort | 1.462 | 1.227 | 1.127 |
| bsearch | 1.085 | 0.882 | 0.977 |
| hashtab | 1.993 | 1.883 | 1.835 |
| graph | 1.709 | 1.695 | 1.341 |
| all 48 kernel times | 1.753 | 1.639 | 1.325 |

- `quicksort` and `mergesort`, each one function with ten or more variables, take 13 to 56% less time: on input in order about half, and `quicksort` on a million such words is level with C (1.01 and 1.02).
- `graph` takes up to 53% less (`dfs` at a thousand vertices) and `heapsort` up to 27% less at a thousand elements; at a million `heapsort` is as it was, within 2%.
- `bsearch` at a thousand elements takes 22 and 24% more time than with scaled indexes alone, and is still ahead of C (0.92). Its functions have six and seven variables, so at most one of them changed its place; why that costs so much in a loop of a load, a comparison and a branch was not looked into. At a million it is unchanged.
- `hashtab` gains up to 12% at a thousand keys and loses 4 to 5% in the three kernels on a million random keys, where the time is the memory. It stays the furthest from C, since its loops are calls of `place`.
- The five CPU-bound programs are at top level, where nothing changed: 1.037.

**Inlining, evaluated.** `hashtab` was written a second time with `place` in the two loops by hand and timed the same way, 15 rounds, against the form with the call (kernel times in milliseconds, both built by the compiler with registers by weight):

| kernel, input | with the call | written in line | |
|---|---:|---:|---:|
| insert, random, 1000 x 5000 | 10.34 | 8.57 | -17% |
| hit, random, 1000 x 5000 | 10.98 | 8.48 | -23% |
| miss, random, 1000 x 5000 | 13.36 | 11.01 | -18% |
| insert, few, 1000 x 5000 | 8.84 | 6.49 | -27% |
| hit, few, 1000 x 5000 | 9.31 | 6.52 | -30% |
| miss, few, 1000 x 5000 | 12.03 | 6.42 | -47% |
| insert, random, 1000000 x 2 | 28.91 | 29.82 | +3% |
| hit, random, 1000000 x 2 | 33.57 | 31.98 | -5% |
| miss, random, 1000000 x 2 | 60.37 | 57.10 | -5% |
| insert, few, 1000000 x 4 | 6.88 | 5.16 | -25% |
| hit, few, 1000000 x 4 | 8.89 | 7.15 | -20% |
| miss, few, 1000000 x 4 | 47.15 | 38.60 | -18% |

The code is 102 bytes longer (4035 against 3933) and names `rsp` 151 times against 143. With the registers in order of definition the same rewriting had made the lookups that miss 30% slower, because the loop then had more variables on the stack than the call had cost; with the registers by weight it is faster in 11 of the 12 times and 3% slower in one, within what that row varies. Against C the inlined form is at 1.46 in the geometric mean of the twelve, the form with the call at 1.84. So inlining is worth having in the compiler now and was not before; it is a backlog item of its own, since a function is compiled from its source in two passes with no tree to copy.

## Two comparisons in a while, 2026-11-20

The third step. `while (i<p)&(j<q)` computed both comparisons as 1 or 0 and tested their `and`: two `cmp`, two `setcc`, two `movzx`, an `and` and a jump in every round. Two layouts with a jump for each comparison were tried by writing the loop of `mergesort` with labels and jumps, which gives exactly the code a lowering would, and timing them like any other form, twice each (kernel times, percent against the loop as it was compiled, mean of the two runs):

| input | both tests at the head, one jump back | tests before the loop and at its end |
|---|---:|---:|
| random, 1000 x 1000 | -2% | -3% |
| sorted, 1000 x 1000 | -12% | -11% |
| reversed, 1000 x 1000 | -1% | -17% |
| few, 1000 x 1000 | -1% | -10% |
| random, 1000000 x 1 | +1% | 0% |
| sorted, 1000000 x 1 | -18% | -17% |
| reversed, 1000000 x 1 | -9% | -18% |
| few, 1000000 x 1 | -6% | -8% |

The second is never slower and is what a `while` already is for one comparison, a test before the loop and one at its end, so the compiler now writes it: the first comparison jumps out when it fails, the second jumps back while it holds. An earlier trial of split branches, with the registers still in order of definition, had been up to 18% slower on small random input; with the loop's variables in registers that loss is gone. Only a `while` on exactly two comparisons joined by `&`, without a division, is compiled so: there the two forms cannot be told apart, since a comparison neither traps nor assigns. A full run, AIL against C in the geometric mean of the kernel times:

| program | registers by weight | and two jumps |
|---|---:|---:|
| mergesort | 1.200 | 1.056 |
| hashtab | 1.835 | 1.614 |
| all 48 kernel times | 1.325 | 1.257 |

`mergesort` takes 2 to 17% less time in its eight rows and is within 6% of C in the mean, behind by 22% only on few values at a thousand elements. `hashtab`, whose `place` has the loop `while (x!=0)&(x!=k)`, takes 4 to 22% less in its twelve. The other four programs have no such loop and are where they were, as are the five CPU-bound programs (1.036). Since the first measurement the 48 kernel times went from 1.753 times those of C to 1.257.

## Calls compiled in place, 2026-11-20

The fourth step. A `call` in a function, of a short function that stands before it, is now the body of that function ([how](compiler.md#functions)): in `hashtab` the two loops hold the lines of `place`, in `bsearch` the loop of `search` holds `lower`. `sift` of `heapsort` is 165 bytes of code, over the limit of 160, and stays a call.

**Where the code lies moves the time.** The first run after the change had `heapsort` at a thousand elements 15 to 34% slower, though its two functions were the same bytes as before: only the harness in front of them had become longer. A line of `data` before the first function, which moves all code behind it, showed it. `heapsort` on a thousand random words, the unchanged compiler, kernel time against the bytes the code was moved by:

| moved by | 0 | 6 | 8 | 12 | 16 | 20 | 24 | 28 | 32 | 36 | 38 | 64 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ms | 20.4 | 18.6 | 18.0 | 23.5 | 23.8 | 22.9 | 23.1 | 21.7 | 20.7 | 15.5 | 16.0 | 20.5 |

The time repeats every 32 bytes and lies between 15.5 and 23.8 ms. So at a thousand elements a difference of a fifth between two builds may be nothing but the place of a loop among the 32-byte lines of the processor, and a comparison of two compilers must not rest on one place. `bsearch` at a thousand elements moves between 38 and 69 ms the same way; the rows of a million elements, where the time is the memory, move by 2 to 5%. The 22 to 24% that `bsearch` lost with [the registers by weight](#registers-by-weight-2026-11-20) are of this kind.

**The comparison, over eight places.** Each program was therefore built eight times by each compiler, with 1, 5, 9, ... 29 bytes of `data` before its first function, every executable run five times in turn on one CPU, and the median of each taken. Kernel times in milliseconds, the least, the median and the greatest of the eight places, with the call and with the body in place; the last column compares the medians:

| kernel, input | with the call | in place | |
|---|---:|---:|---:|
| `hashtab` insert, random, 1000 x 5000 | 9.20, 9.32, 9.79 | 6.19, 6.58, 6.97 | -29% |
| `hashtab` hit, random, 1000 x 5000 | 9.54, 9.69, 10.07 | 7.63, 7.78, 7.90 | -20% |
| `hashtab` miss, random, 1000 x 5000 | 11.40, 13.47, 14.95 | 9.43, 10.09, 12.28 | -25% |
| `hashtab` insert, few, 1000 x 5000 | 8.33, 8.44, 8.57 | 5.29, 5.40, 5.64 | -36% |
| `hashtab` hit, few, 1000 x 5000 | 8.24, 8.27, 8.81 | 6.10, 6.20, 6.62 | -25% |
| `hashtab` miss, few, 1000 x 5000 | 10.26, 10.53, 11.05 | 7.13, 7.68, 8.02 | -27% |
| `hashtab` insert, random, 1000000 x 2 | 26.06, 26.16, 27.24 | 22.43, 23.02, 23.40 | -12% |
| `hashtab` hit, random, 1000000 x 2 | 30.01, 30.55, 31.37 | 28.14, 28.43, 29.09 | -7% |
| `hashtab` miss, random, 1000000 x 2 | 47.44, 48.25, 49.21 | 44.88, 45.88, 46.55 | -5% |
| `hashtab` insert, few, 1000000 x 4 | 6.06, 6.41, 7.06 | 4.31, 4.98, 5.28 | -22% |
| `hashtab` hit, few, 1000000 x 4 | 8.34, 8.62, 9.31 | 6.86, 7.51, 8.40 | -13% |
| `hashtab` miss, few, 1000000 x 4 | 38.53, 40.68, 41.77 | 34.70, 36.52, 37.43 | -10% |
| `bsearch`, random, 1000 x 2000 | 45.11, 47.69, 57.46 | 38.17, 48.70, 68.92 | +2% |
| `bsearch`, few, 1000 x 2000 | 42.51, 47.74, 55.24 | 35.77, 46.75, 70.17 | -2% |
| `bsearch`, random, 1000000 x 1 | 122.11, 124.12, 126.09 | 122.94, 124.88, 127.53 | +1% |
| `bsearch`, few, 1000000 x 1 | 121.21, 121.79, 125.29 | 121.90, 124.74, 129.27 | +2% |

- `hashtab` takes 5 to 36% less time in all twelve, and in ten of them the slowest place of the new code is faster than the fastest of the old; in the misses on a thousand random keys and the hits on a million keys of few values the ranges meet. A round of its loops was a call, six pushes and pops and a return around a probe of one or two loads.
- `bsearch` is the same within what its place does. A call of `lower` runs ten rounds at a thousand elements and twenty at a million, so the call was a small part.
- `heapsort` with the limit raised to 200 bytes, so that `sift` is in place twice: 21.8 against 21.1 ms at a thousand random words (medians; the eight places span 16.3 to 25.4 and 18.2 to 23.0), and 98.5 against 92.3 ms at a million, 7% slower at every place. A call of `sift` runs a loop of up to twenty rounds, and in `heapsort` its seven variables come to those of the caller: eight are then in use in the loop for six registers, where `sift` alone has seven. The limit of 160 bytes is what separates the three functions measured, no more than that.

A parameter that the body only reads is the caller's variable itself, so `insert` with `place` in it is, instruction for instruction, the loop that was [written by hand](#registers-by-weight-2026-11-20) before. The executables of the six programs grew by 850 to 1117 bytes each (`hashtab` from 4087 to 5204), most of it the short functions of the harness at their calls. The compiler, compiled by itself, is 630 bytes longer than without (48779 against 48149) and compiles its own source in 5.4 ms against 5.7.

The full run, at one place each, AIL against C in the geometric mean of the kernel times:

| program | two jumps | and calls in place |
|---|---:|---:|
| quicksort | 1.215 | 1.201 |
| mergesort | 1.056 | 1.067 |
| heapsort | 1.138 | 1.263 |
| bsearch | 0.973 | 0.863 |
| hashtab | 1.614 | 1.306 |
| graph | 1.335 | 1.340 |
| all 48 kernel times | 1.257 | 1.201 |

Of these only the row of `hashtab` is the change. `heapsort` and `bsearch` are the same kernels at another place, one slower by it and one faster, which is the reason for the eight places above. The five CPU-bound programs are at top level and unchanged (1.036).

## Tasks, 2026-11-20

`tools/par.aw`, built as `build/tools/par` (until 2026-11-20 the Python script `tools/par.py`, which the figures below were taken with), times the programs of `bench/par/`, each written twice: `<name>_seq.aw` does the work in one call, `<name>_par.aw` cuts it into tasks with `spawn` and `join` (`lib/task.aw`). It is the measurement of the backlog item on parallel execution: what the pool gains at 1, 2, 4, 8, 14 and 20 threads, and how small a task may be before its scheduling costs more than it saves.

```
make all tools
build/tools/par              # the three tables below
build/tools/par --check      # small sizes, outputs only: part of make test
build/tools/par --runs 3 collatz
build/tools/par --grid --runs 3   # every number of threads with every number of tasks
```

| program | what it does | why it is here |
|---|---|---|
| `collatz` | adds up the lengths of the Collatz sequences from 1 to 3000000 | even work, no memory |
| `primes` | counts the primes below 3000000 by trial division | the work grows along the range, so equal pieces are unequal work |
| `memsum` | fills 16777216 words (128 MiB) and adds them up sixteen times | bound by memory: page faults, then reading |

- The sequential program reads its size from stdin; the task program reads the size, the number of threads and the number of tasks. Every timed run must print what the sequential program printed.
- "Threads" is the number of threads that run tasks: the program calls `workers` with one less, because the main thread runs tasks in its joins. It joins the tasks last spawned first, which are the ones most likely still in the queue. At 1 thread there is no worker and every task runs inside its `join`.
- A run is a new process, timed from outside, on all processors; the figure is the median of 7 runs.
- The machine has 20 hardware threads on 14 cores: 6 performance cores with two threads each and 8 efficiency cores. Beyond 6 threads a further thread is a slower core or the second thread of a core, so 20 threads cannot give 20 times.

12th Gen Intel Core i7-12700H, Linux 7.0. Elapsed milliseconds with the work cut into 160 tasks, and below each row the sequential time divided by it:

| program | sequential | 1 | 2 | 4 | 8 | 14 | 20 |
|---|---:|---:|---:|---:|---:|---:|---:|
| collatz | 556.8 | 593.3 | 299.6 | 164.9 | 95.9 | 69.4 | 62.1 |
| | | 0.94 | 1.86 | 3.38 | 5.81 | 8.02 | 8.97 |
| primes | 697.6 | 700.8 | 352.6 | 189.3 | 104.0 | 68.7 | 64.2 |
| | | 1.00 | 1.98 | 3.68 | 6.71 | 10.16 | 10.87 |
| memsum | 201.7 | 201.1 | 122.3 | 83.5 | 69.2 | 62.7 | 61.5 |
| | | 1.00 | 1.65 | 2.41 | 2.92 | 3.22 | 3.28 |

- `collatz` and `primes` gain 1.9 to 2.0 times at 2 threads, 3.4 to 3.7 at 4, 5.8 to 6.7 at 8 and 9 to 11 at 20. The gain per thread falls after the six performance cores are taken, as the machine leads one to expect.
- `memsum` reaches 2.4 times at 4 threads and only 3.3 at 20: its limit is memory, not processors.
- At 1 thread the cost of 160 tasks is not measurable. `collatz` is 6% slower there for another reason: its loop stands at another address in the two programs. The sequential program with `lib/task.aw` merely compiled in, and no task, takes 580 to 600 ms.

Elapsed milliseconds by the number of tasks the same work is cut into (`memsum` has that many in each of its 17 passes):

| program | threads | sequential | 20 | 200 | 2000 | 20000 | 200000 | 1000000 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| collatz | 1 | 556.8 | 584.5 | 589.1 | 610.1 | 619.9 | 628.4 | 681.7 |
| collatz | 20 | 556.8 | 60.8 | 60.2 | 58.8 | 62.8 | 225.4 | 1190.6 |
| primes | 1 | 697.6 | 691.6 | 694.6 | 702.5 | 700.5 | 717.8 | 750.3 |
| primes | 20 | 697.6 | 80.8 | 73.2 | 69.3 | 62.2 | 195.0 | 1176.3 |
| memsum | 1 | 201.7 | 208.8 | 205.3 | 213.7 | 257.6 | 400.4 | 926.2 |
| memsum | 20 | 201.7 | 63.2 | 62.5 | 64.0 | 351.6 | 3389.7 | 16825.1 |

- **A task costs about 0.1 microseconds on one thread**: a million tasks add 97 ms to `collatz` and 59 ms to `primes`. That is `spawn` and `join` with no worker: a record from the free list, the queue, a lock taken three times, no system call.
- **With 20 threads a task costs about 1.2 microseconds** once tasks are so small that the threads meet at the lock: a million tasks take 1.2 s in both programs, about twice the sequential time, for work of 0.6 to 0.7 microseconds a task.
- **Where it turns**: tasks of about 30 microseconds and more (20000 tasks) run at full speed, 9 to 11 times. Tasks of 3 microseconds (200000) still gain 2.5 to 3.6 times. Below about 1 microsecond a task the program is slower than without tasks. `memsum` turns earlier, since its 20000 tasks a pass are 0.6 microseconds each.
- The rule that follows: cut the work into some tens of tasks per thread, not into its smallest pieces. A hundred or a thousand tasks cost nothing and even out unequal work.

### The size of a task at each number of threads

The two tables above vary the threads at one number of tasks and the tasks at 1 and 20 threads. `build/tools/par --grid` times every pair, to say how large a task should be before anything in the pool is changed. Measured on 2026-11-20 with the compiler as it then was, median of 3 runs; a cell is the sequential time divided by the time with tasks, so 1 is no gain. The number of tasks is that of the whole work for `collatz` and `primes` and that of each of the 17 passes for `memsum`.

collatz, sequential 552.0 ms: that time divided by the time with tasks, median of 3 runs

| tasks | 1 | 2 | 4 | 8 | 14 | 20 |
|---:|---:|---:|---:|---:|---:|---:|
| 20 | 0.99 | 1.86 | 3.43 | 5.70 | 7.24 | 8.57 |
| 200 | 0.98 | 1.93 | 3.56 | 6.25 | 8.98 | 9.92 |
| 2000 | 0.98 | 1.92 | 3.54 | 6.27 | 9.24 | 10.05 |
| 20000 | 0.98 | 1.91 | 3.50 | 6.16 | 8.58 | 9.83 |
| 200000 | 0.96 | 1.85 | 3.19 | 5.06 | 4.29 | 2.23 |

primes, sequential 695.6 ms: that time divided by the time with tasks, median of 3 runs

| tasks | 1 | 2 | 4 | 8 | 14 | 20 |
|---:|---:|---:|---:|---:|---:|---:|
| 20 | 1.01 | 1.93 | 3.49 | 5.75 | 7.85 | 9.11 |
| 200 | 1.00 | 1.98 | 3.68 | 6.68 | 10.42 | 10.90 |
| 2000 | 1.00 | 1.97 | 3.70 | 6.89 | 10.89 | 11.39 |
| 20000 | 1.01 | 1.98 | 3.67 | 6.84 | 11.21 | 11.18 |
| 200000 | 0.99 | 1.90 | 3.43 | 5.55 | 4.94 | 3.48 |

memsum, sequential 188.8 ms: that time divided by the time with tasks, median of 3 runs

| tasks | 1 | 2 | 4 | 8 | 14 | 20 |
|---:|---:|---:|---:|---:|---:|---:|
| 20 | 1.01 | 1.56 | 2.31 | 2.65 | 2.81 | 2.93 |
| 200 | 0.96 | 1.41 | 2.26 | 2.95 | 3.08 | 3.12 |
| 2000 | 1.00 | 1.64 | 2.51 | 2.79 | 3.04 | 3.00 |
| 20000 | 0.87 | 1.47 | 1.56 | 0.64 | 0.54 | 0.52 |
| 200000 | 0.51 | 0.33 | 0.10 | 0.07 | 0.06 | 0.06 |

What a task is in time follows from the sequential time: in `collatz` 27.6 ms at 20 tasks, 2.8 ms at 200, 276 microseconds at 2000, 28 at 20000 and 2.8 at 200000; in `primes` a quarter more; in `memsum`, a pass being 11 ms, 555 microseconds at 20 tasks, 55 at 200, 5.5 at 2000, 0.55 at 20000 and 0.055 at 200000.

- **Work bound by the processor: tasks of 30 microseconds to 3 milliseconds.** From 200 to 20000 tasks the gain is the same within a tenth at every number of threads, 9.8 to 11.4 times at 20. That is ten to a thousand tasks for each thread.
- **One task for each thread is too few.** 20 tasks at 20 threads give 8.6 and 9.1 times where 2000 give 10.1 and 11.4, and at 14 threads 7.2 and 7.9 against 9.2 and 10.9: the cores are not equally fast and, in `primes`, the pieces not equally long, and with one piece each nothing evens that out.
- **Tasks of 3 microseconds are worth it up to 8 threads and not beyond.** At 200000 tasks the gain at 8 threads is 5.1 and 5.6 against 6.3 and 6.9, a fifth less; at 14 threads it falls to 4.3 and 4.9 and at 20 to 2.2 and 3.5, what 4 threads give or less, since the threads then wait for each other at the queue.
- **Work bound by memory: tasks of 5 microseconds or more, and few threads.** `memsum` gains 2.3 to 2.5 times at 4 threads and 2.9 to 3.1 at 20 with 20 to 2000 tasks a pass; more threads than the memory can feed buy little. At 0.55 microseconds a task it is slower than without tasks from 8 threads on, and at 0.055 at every number of threads.
- **A starting size**: about ten times as many tasks as threads, each of at least 100 microseconds; make them smaller only if the pieces are unequal, and not below 30 microseconds when more than 8 threads run them. The pool needs no change for any of this: within those sizes its cost cannot be measured.

Source tokens (`o200k_base`), comments left out:

| program | sequential | tasks | lines added |
|---|---:|---:|---:|
| collatz | 109 | 230 | 24 |
| primes | 115 | 236 | 24 |
| memsum | 153 | 278 | 22 |

The task form of a program is 121 to 125 tokens and 22 to 24 lines longer; before the programs were indented it was 107 to 115. In `collatz`, 90 of those 115 are the two loops that cut the range into pieces, keep the handles and add up the results, `spawn` and `join` being 12 of those; the `use` is 6, `call workers` 6, and the rest declares the buffer of handles and reads the two numbers. [The token page](tokens.md#tasks-measured-on-2026-11-20) has the count of the forms.

## Async, 2026-11-20

The programs of `bench/async/` measure the runtime of `lib/async/`, which polls every task on one thread. They are the measurement of the backlog section on asynchronous execution: what a wait costs, what a server on one thread carries, and whether a scheduler on several threads would pay. Machine as above (Core i7-12700H, 20 threads, Linux 7.0); every figure is the median of five runs. The table of the server and the times of its processor were taken again after both servers were made to write without `SIGPIPE`.

```
make
for p in timer echod ping switch mem hop; do build/ailc < bench/async/$p.aw > build/$p && chmod +x build/$p; done
build/switch 1000 1000      # a million waits
build/mem 100000            # bytes a sleeping task
build/hop 100000            # work handed to the pool, one after the other
build/ping 100 2000         # server and clients in one process
build/echod 0 & build/ping 100 2000 <port>
gcc -O2 -o build/echod_c bench/async/echod.c
```

| program | what it does |
|---|---|
| `switch` | tasks that each `await asyncyield` many times: a task made, the asking task put aside, both polled, a record given back |
| `mem` | tasks asleep in a timer, three variables alive in each; resident memory before and after |
| `hop` | `await asyncblock` of a function that does nothing |
| `echod` | a TCP echo server, one task a connection, 4096 bytes of buffer in each task |
| `ping` | load for it: a task a connection sends 64 bytes and reads them back, and times each round trip |
| `echod.c` | the same server on `epoll` by hand in C, one thread, for comparison |

**A wait.**

| | nanoseconds |
|---|---:|
| a wait that gives the thread to another task and gets it back (`switch`, 1000 tasks) | 22 |
| the same with 100000 tasks, whose records no longer fit the cache | 43 |
| work handed to the pool and awaited, 100000 pieces at once (`hop`) | 1100 |
| the same one after the other, the polling thread asleep for each | 3500 |

A wait on the thread is a few tens of instructions: a record from a free list, two entries in a queue, two indirect calls. Handing work to another thread costs 50 to 160 times that, a futex wake for the worker and, if the polling thread sleeps, an `eventfd` write and an `epoll_wait` to get back: `asyncblock` is for work of many microseconds, and the figures for `spawn` above hold for it.

**Memory.** A task asleep in a timer is 272 bytes of resident memory: its record of 128 bytes (64 of the library, the rest for its variables, three here), the timer's event of 128 and 16 in the heap. A connection of `echod` is a record of 8192 bytes, of which 4096 are its buffer and the rest the rounding to a power of two, plus 128 for the descriptor. A hundred thousand waiting tasks are 27 MiB, and none has a stack.

**A server.** Round trips of 64 bytes over loopback, `ping` in one process and the server in another, so each has a processor:

| connections | server | round trips a second | mean | median | 99 of 100 within |
|---:|---|---:|---:|---:|---:|
| 1 | `echod` (AIL) | 119200 | 7 us | 7 us | 17 us |
| 1 | `echod.c` | 120200 | 7 us | 7 us | 16 us |
| 100 | `echod` (AIL) | 297600 | 334 us | 334 us | 381 us |
| 100 | `echod.c` | 295200 | 337 us | 336 us | 433 us |
| 1000 | `echod` (AIL) | 285000 | 3428 us | 3363 us | 4415 us |
| 1000 | `echod.c` | 281500 | 3469 us | 3372 us | 4734 us |

With clients and server as tasks of one thread (`ping` without a port) the same work is 165800, 171700 and 158600 round trips a second, about half, as one processor does both sides.

- **The server written with `async fn` carries what the one written on `epoll` by hand carries.** The time of a round trip with many connections is the wait in line, connections times the service time, and the same for both.
- **Where the time goes**: for a million round trips at 100 connections the AIL server uses 0.31 s in its own code and 2.98 s in the kernel; the C server 0.15 s and 2.93 s. The runtime costs 160 ns a round trip more than code written for this one program, 7% of the processor time of the server, and nine tenths of the time are the kernel's in either.
- **System calls**: for 200000 round trips the AIL server made 208705 calls of `read`, 8605 of which said "not now", 200002 writes (`sendto` with `MSG_NOSIGNAL`, counted when they were still `write`) and 169 of `epoll_wait`. An operation asks the kernel first, so a busy server hardly ever sleeps; the server in C, which waits for an event before each read, cannot make fewer.
- The source of the server is 259 tokens in AIL (`echo.aw` and `echod.aw`, with the reading of the port) and 503 in C; [token cost](tokens.md) has the forms.

### A scheduler on several threads

Tokio polls tasks on a pool of threads, each with a queue of its own that idle threads steal from. The backlog asks whether AIL should, once the single thread is measured.

*What could move.* A task between two polls is its record and nothing else: the variables and locals are in it, the place to go on is in it, and no stack belongs to it. The code the compiler writes for an `async fn` does not care which thread calls it. So a task could be polled by another thread than the last time. Everything around it could not, as it is: the queue, the free lists of records, the heap of timers, the records and lists of the descriptors, the list of what can be cancelled and the cells of a task that say who awaits it are written without a lock or an atomic instruction, by the one thread that polls. An event belongs to the driver of the thread that made it.

*What it would cost.* Every wake, every `await` and every operation on a descriptor would take a lock or become a loop around `cas`, which is paid by programs that never use a second thread, on a wait that costs 22 ns now. The hop measured above is what a task that is woken on another thread pays, 1.1 to 3.5 microseconds, more than a round trip's worth of the runtime's own work. And the larger cost is not in the library: today nothing in a program runs at the same time as anything else, so tasks share `var` cells and buffers freely, which is most of what makes them short to write. With tasks on several threads every program would need `xadd` and `cas` where tasks meet, as code for `spawn` does.

*What it would gain.* The server above spends nine tenths of its time in the kernel, and that part does run in parallel. A second thread would raise what one process carries past the 280000 round trips a second of one processor. Work that computes is already parallel: `asyncblock` gives it to the pool.

*The decision.* No scheduler on several threads for now. One thread carries as much as a server in C on one thread, its limit is the kernel's work on one processor, and the programs stay free of locks. If a program needs more than that, the form to build is a thread per processor with a runtime of its own each, tasks never moving, connections spread by the kernel (`SO_REUSEPORT`): it keeps the rule that the tasks of one runtime never run at the same time. Processes do that today without a change, each started with its own copy of the server; for threads the state of the library would have to be found through the thread instead of in a `buf`, which needs a thread-local cell that the language does not have. Work stealing would be the step after, and only measurement of such a program could ask for it.

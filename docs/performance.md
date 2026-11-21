# Performance

`tools/perf.ai`, built as `build/tools/perf` by `make tools`, times every example against the C, Rust and assembly program in `bench/` that does the same. It is the measurement behind the performance goal of the redesign: elapsed time on CPU-bound programs close to C built with `-O3`.

```
make all tools
build/tools/perf              # every program
build/tools/perf compute      # some programs only
build/tools/perf --quick      # few rounds, to see that it runs
build/tools/perf --cpu 4      # another CPU than 2
```

## Method

- C is built with `gcc -O3`, Rust with `rustc -O`, assembly with `as` and `ld`; the AIL program is `build/<name>`, so run `make` first. A language without a source for a program is left out of its row.
- Every executable must give the expected output and exit status for the input before anything is timed. Where the output is a computed value, all languages must give the same bytes as C.
- A run is a child process of `lib/proc.ai` and the wait for it (`fork`, `dup2`, `execve`, `wait4`), timed with the monotonic clock, with stdin from a file and stdout to `/dev/null`, the tool pinned to one CPU. Until 2026-11-20 the tool was a Python script that started the child with `posix_spawn`; [the two are compared below](#the-measuring-tool-in-ail-2026-11-20). Each round runs every language once, in an order shuffled from a fixed seed, so that drift of the machine falls on all of them alike.
- The figure is the median, followed by the first and third quartile, which show the variation from run to run.
- The input is read at run time, so no compiler can compute the result while compiling.

The programs are of two kinds, reported apart:

- **Startup**: `hello`, `echo`, `count`, `fact` and `loop` do almost nothing, so their time is the cost of starting a process. 25 warm-up rounds and 500 timed ones, in microseconds.
- **CPU-bound**: five programs that read their input, compute and write a 64-bit result. 2 warm-up rounds and 15 timed ones, in milliseconds. For these the table gives the ratio of AIL to C and, below it, the geometric mean of the ratios; a ratio above 1.10 is marked `slow`.

| program | what it does | what it exercises |
|---|---|---|
| `compute` | a hundred million steps of `x = (x ^ (x >> 13)) * 1664525 + 1013904223` | arithmetic in one dependent chain |
| `sieve` | counts the primes below 16000000 in a table of bytes | byte stores at a stride, a nested loop |
| `collatz` | adds up the lengths of the Collatz sequences from 1 to 500000 | a branch that cannot be predicted, `% 2`, `/ 2`, `* 3` |
| `fnv` | hashes a megabyte a hundred times with FNV-1a | byte loads, a multiplication per byte |
| `isort` | sorts 30000 numbers by insertion | 64-bit loads and stores, a comparison per step |

The last four have no assembly equivalent. They are written as the language is written today, one operation a line with labels and jumps, and at top level with at most six variables, since a seventh would live in memory there.

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

**Authoring effort: met.** `count` writes each digit in one line (`storeb out+1 48+n/100%10`) with no variable for a digit or an address, and `compute` is a `while` around one assignment, with no label. Beyond the representative routines the criterion asks for, the whole compiler was rewritten by `tools/infix.py` (now `tools/infix.ai`): 21% fewer tokens, 725 intermediate variables gone, 12 loops as `while`.

**Bootstrap: met.** `stage0/ailc.s` is removed. A clean worktree with an empty build directory and no local seed fetches seed 2 by the checksum in `seed/MANIFEST`, builds the compiler in three generations, passes `make test` (2065 checks) and has `build/ailc` and `build/ailc2` as one file.

Where the work departed from the document:

- **Expressions have no spaces.** The document sketched `x = (x ^ (x >> 13)) * 1664525 + 1013904223` with a comma between arguments and left the boundaries to be settled by counting. The count chose `x=(x^x>>13)*1664525+1013904223`, with spaces separating arguments as before: 975 tokens for the corpus against 1104 for the sketched form.
- **Three generations, not two.** The document builds the sources with the seed and then with the result, and compares those two. Once the compiler writes other code than its seed did, those two differ in bytes without differing in behaviour, so the comparison is between the second and a third build.
- **No intermediate representation across statements.** Expressions are parsed into a list of nodes and lowered together, each statement on its own, as the document says to start. What remains behind C would need more: an address that does not change in a loop kept in a register, a scaled index, and the folding of one branch into another that C does in `collatz`.
- **A step was added**, loads and stores with the address as an operand, when the measurements after instruction selection showed where `isort` and `sieve` lost.
- **The old forms were not kept as copies of the examples.** The statements remain in the language and compile to the same code as the expressions that say the same, which `tools/randvars.ai` checks byte for byte; about 900 tests are still written with them.
- **The seed is a release of a private repository**, so fetching it needs `gh` and a login, or a local copy; `curl` alone works once the repository is public.

Not done: the comparison of these token counts, taken with an OpenAI encoding, with Claude's tokenizer, which stays an open item.

## The measuring tool in AIL, 2026-11-20

The figures above were taken by `tools/perf.py`, a Python script. The tool is now `tools/perf.ai`, which checks, times and reports as the script did: the same programs, inputs and expected results, the same rounds, the median and quartiles of the same samples, the same tables. Two things differ, and one of them touches the figures.

- **How a child is started.** The script called `posix_spawn` from the Python interpreter; the tool calls `procstart` of `lib/proc.ai`, which is `fork` and then `dup2` and `execve` in the child. The time of a run includes that start, and for the startup programs it is most of what is measured. Both tools were run one after the other, twice, on the same machine and CPU as above (median of 500 rounds, microseconds):

| program | AIL, script | AIL, tool | C, script | C, tool |
|---|---:|---:|---:|---:|
| hello | 70.84, 72.69 | 71.78, 69.30 | 218.92, 227.86 | 223.00, 214.42 |
| echo | 75.25, 76.79 | 74.16, 71.81 | 229.78, 231.85 | 223.72, 215.26 |
| count | 76.64, 80.91 | 71.99, 70.31 | 226.71, 242.46 | 218.25, 211.25 |
| fact | 72.75, 74.69 | 68.95, 67.40 | 229.67, 231.28 | 211.91, 206.97 |
| loop | 78.93, 78.21 | 71.80, 70.44 | 235.43, 231.46 | 214.94, 209.74 |

  Taking the two runs of each together, the tool's figures are lower than the script's: by 1 to 8 microseconds for AIL and by 5 to 21 for C, between 2 and 10 percent. For AIL that is within the quartiles of either tool, which lie 4 to 9 microseconds from the median; for C it is beyond them in three of the five programs. A `fork` of a process of a few pages costs less than a `posix_spawn` out of an interpreter, and a parent that runs no interpreter between two children leaves them warmer caches, which a program that loads a C library uses more of. The ratio between the languages is what it was, an AIL program starting in about a third of the time of the C one with either tool (`hello` 0.32 and 0.32, `count` 0.34 and 0.33). So startup figures taken by the tool are not to be mixed with the older tables above, only compared within a table; the CPU-bound figures, in milliseconds, do not see the difference. The script's start could have been matched with `clone` and `CLONE_VFORK`, but not its interpreter, so the plain `fork` stays and the figures are marked by date.
- **The order of a round** is shuffled with splitmix64 (`tools/lib/rng.ai`) from the seed 77, where the script used Python's generator with that seed: other orders, drawn the same way.

The geometric mean is the n-th root by Newton's steps in doubles, where Python used `pow`; on 20000 random products of up to ten ratios the two print the same three digits. A run of every program with the tool gave 1.000, 1.029, 1.126, 0.999 and 1.043 for the five CPU-bound programs and a geometric mean of 1.038.

## Tasks, 2026-11-20

`tools/par.ai`, built as `build/tools/par` (until 2026-11-20 the Python script `tools/par.py`, which the figures below were taken with), times the programs of `bench/par/`, each written twice: `<name>_seq.ai` does the work in one call, `<name>_par.ai` cuts it into tasks with `spawn` and `join` (`lib/task.ai`). It is the measurement of the backlog item on parallel execution: what the pool gains at 1, 2, 4, 8, 14 and 20 threads, and how small a task may be before its scheduling costs more than it saves.

```
make all tools
build/tools/par              # the three tables below
build/tools/par --check      # small sizes, outputs only: part of make test
build/tools/par --runs 3 collatz
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
- At 1 thread the cost of 160 tasks is not measurable. `collatz` is 6% slower there for another reason: its loop stands at another address in the two programs. The sequential program with `lib/task.ai` merely compiled in, and no task, takes 580 to 600 ms.

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
for p in timer echod ping switch mem hop; do build/ailc < bench/async/$p.ai > build/$p && chmod +x build/$p; done
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
- The source of the server is 259 tokens in AIL (`echo.ai` and `echod.ai`, with the reading of the port) and 503 in C; [token cost](tokens.md) has the forms.

### A scheduler on several threads

Tokio polls tasks on a pool of threads, each with a queue of its own that idle threads steal from. The backlog asks whether AIL should, once the single thread is measured.

*What could move.* A task between two polls is its record and nothing else: the variables and locals are in it, the place to go on is in it, and no stack belongs to it. The code the compiler writes for an `async fn` does not care which thread calls it. So a task could be polled by another thread than the last time. Everything around it could not, as it is: the queue, the free lists of records, the heap of timers, the records and lists of the descriptors, the list of what can be cancelled and the cells of a task that say who awaits it are written without a lock or an atomic instruction, by the one thread that polls. An event belongs to the driver of the thread that made it.

*What it would cost.* Every wake, every `await` and every operation on a descriptor would take a lock or become a loop around `cas`, which is paid by programs that never use a second thread, on a wait that costs 22 ns now. The hop measured above is what a task that is woken on another thread pays, 1.1 to 3.5 microseconds, more than a round trip's worth of the runtime's own work. And the larger cost is not in the library: today nothing in a program runs at the same time as anything else, so tasks share `var` cells and buffers freely, which is most of what makes them short to write. With tasks on several threads every program would need `xadd` and `cas` where tasks meet, as code for `spawn` does.

*What it would gain.* The server above spends nine tenths of its time in the kernel, and that part does run in parallel. A second thread would raise what one process carries past the 280000 round trips a second of one processor. Work that computes is already parallel: `asyncblock` gives it to the pool.

*The decision.* No scheduler on several threads for now. One thread carries as much as a server in C on one thread, its limit is the kernel's work on one processor, and the programs stay free of locks. If a program needs more than that, the form to build is a thread per processor with a runtime of its own each, tasks never moving, connections spread by the kernel (`SO_REUSEPORT`): it keeps the rule that the tasks of one runtime never run at the same time. Processes do that today without a change, each started with its own copy of the server; for threads the state of the library would have to be found through the thread instead of in a `buf`, which needs a thread-local cell that the language does not have. Work stealing would be the step after, and only measurement of such a program could ask for it.

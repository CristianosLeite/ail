# Performance

`tools/perf.py` times every example against the C, Rust and assembly program in `bench/` that does the same. It is the measurement behind the performance goal of the redesign: elapsed time on CPU-bound programs close to C built with `-O3`.

```
make
python3 tools/perf.py              # every program
python3 tools/perf.py compute      # some programs only
python3 tools/perf.py --quick      # few rounds, to see that it runs
python3 tools/perf.py --cpu 4      # another CPU than 2
```

## Method

- C is built with `gcc -O3`, Rust with `rustc -O`, assembly with `as` and `ld`; the AIL program is `build/<name>`, so run `make` first. A language without a source for a program is left out of its row.
- Every executable must give the expected output and exit status for the input before anything is timed. Where the output is a computed value, all languages must give the same bytes as C.
- A run is `posix_spawn` and `waitpid` with stdin from a file and stdout to `/dev/null`, the script pinned to one CPU. Each round runs every language once, in an order shuffled from a fixed seed, so that drift of the machine falls on all of them alike.
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


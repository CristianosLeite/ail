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
- **CPU-bound**: `compute` runs a hundred million dependent steps of `x = (x ^ (x >> 13)) * 1664525 + 1013904223` on a 64-bit value read from stdin and writes the result. 2 warm-up rounds and 15 timed ones, in milliseconds. For these the table gives the ratio of AIL to C and, below it, the geometric mean of the ratios; a ratio above 1.10 is marked `slow`.

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
| compute | 134.54 (133.83, 135.15) | 132.05 (131.67, 132.64) | 131.89 (131.71, 132.96) | 131.91 (131.48, 132.19) | 1.019 |

The loop of `compute` is 22 instructions in AIL against 7 in the assembly program: every operand is copied to `rax` or `rdi`, `13` and the two constants are loaded on every step, and `jnz` tests its value again. It still runs within 2% of C because the steps depend on each other: the time is the latency of the shift, the multiplication and the additions in a row, and the extra moves run beside them. One program of that shape says little about loops that are not one chain, so the corpus needs more CPU-bound programs before the ratio means much.

---
title: Token cost measurement
last-verified: 2026-11-20
sources: [conversation 2026-11-19, conversation 2026-11-20, tools/tokens.sh, tools/perf.py, docs/tokens.md, docs/performance.md]
status: current
---
# Token cost measurement

**Summary.** `tools/tokens.sh` counts tokens with `tiktoken` (`o200k_base`) for the ten examples
and their C, Rust and assembly equivalents in `bench/`. Since the examples use expressions AIL is
13% cheaper than C and 19% cheaper than Rust (it was 17% and 10% dearer written as statements). Lines and numbers are what cost; keywords do not.
`tools/perf.ai` (until 2026-11-20 the Python script `tools/perf.py`) times the same programs.

## Facts
- With the examples rewritten in expressions and `while` (2026-11-20, later the same day): AIL
  970, C 1118, Rust 1191; AIL is cheaper than C in every program and dearer than Rust only in
  `count` and `fnv`. Time against `gcc -O3`: geometric mean 1.041 (`collatz` 1.13, `isort` 1.06,
  `sieve` 1.03, the other two 1.00), from 1.742.
- Totals without comments on 2026-11-20 before that, ten programs written as statements: AIL 1313, C 1118, Rust 1191. The first
  six, which have assembly equivalents: AIL 496, C 448, Rust 464, assembly 925.
  The five short ones alone: AIL 382, C 342, Rust 344, assembly 696 (AIL was 411 at the first
  measurement, before compare-and-jump statements and syscall names). AIL wins on `hello` and
  `echo`.
- `compute` (2026-11-20) is the arithmetic benchmark: a hundred million steps of a 64-bit
  recurrence on a value read from stdin. It and its timing script were first written in a
  temporary directory outside the repository and nearly lost; they are now `examples/compute.ai`,
  `bench/compute.*` and `tools/perf.py`.
- Timing on an i7-12700H: an AIL program starts in about 75 microseconds, C in 230, Rust in 320.
  `compute` takes 134.5 ms in AIL against 132.1 in C at `-O3`, although its loop is 22
  instructions against 7: the steps are one dependency chain, so the extra moves cost little.
- **One benchmark of one shape misleads.** `compute` alone suggested parity with C. Four more
  CPU-bound programs (`sieve`, `collatz`, `fnv`, `isort`) gave a geometric mean of 1.742:
  `fnv` 1.00 (another dependency chain), `sieve` 1.20, `isort` 3.14 (a loop of moves, loads and a
  comparison), `collatz` 4.18 (`div` for `% 2` and `/ 2`). Measure a loop that is not one chain
  before concluding anything about generated code.
- The CPU-bound examples are written at top level with at most six variables, because the
  seventh top-level variable lives in a memory cell.
- `compiler/ailc.ai` is 6181 tokens in 1107 code lines; 1096 tokens are line ends, 422 are `as`.
- A number after a space is two tokens or more, a name one. `4294967295` is four tokens,
  `0xffffffff` two. `jz` and `jnz` are two tokens each; `load4` and `loadb` are two, `load` one.
- A comparison plus its conditional jump is twelve tokens; one compare-and-branch line would be
  seven. Stage1 has 55 such pairs.
- `tools/bench.sh` builds `bench/` with `gcc`, `rustc`, `as` and `ld` and checks output and exit
  status against the examples for empty input, for `hi` and for eight bytes; all 78 comparisons
  pass. A program may lack the assembly equivalent.

## Why
- **tiktoken in a virtual environment (chosen by the user):** no tokenizer was installed, and this
  one runs offline once installed, so no source leaves the machine. The alternative was the
  Anthropic token counting API, which gives exact Claude counts but sends every file out.
- **Comments stripped before counting:** the examples are heavily commented and the equivalents
  are not, and a comment is not what the language costs.
- **Not part of `make test`:** the build requires only `as` and `ld`; the measurement needs
  Python and network access once, the behaviour check `gcc` and `rustc`.

## How to apply
- Before choosing between two spellings, tokenize both (`build/tools/tokens --ids file`, or `-c '#' file` for a count; since 2026-11-20 the tokenizer is `tools/lib/o200k.ai`, which gives the numbers of `tiktoken`; `.venv` with `tiktoken` is no longer needed by any tool).
- Prefer a statement that removes a line over one that shortens a word.
- Replace numbers by names where the language can: constants, named data, global scalars.
- After changing an example, change its three equivalents in `bench/`, run `tools/bench.sh` and
  update the table in `docs/tokens.md`.

## Open items
- 2026-11-19: the counts are from an OpenAI encoding, used as a proxy; they have not been compared
  with Claude's tokenizer.
- 2026-11-19: `count.s` uses a loop where the other three versions are unrolled.

## Related
- [Stage0 design decisions](stage0-design-decisions.md)
- [Stage1 self-hosting](stage1-self-hosting.md)
- [Open items](../status/open-items.md)

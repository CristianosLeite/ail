---
title: Token cost measurement
last-verified: 2026-11-21
sources: [conversation 2026-11-19, conversation 2026-11-20, tools/tokens.sh, tools/perf.aw, tools/lib/o200k.aw, docs/tokens.md, docs/performance.md]
status: current
---
# Token cost measurement

**Summary.** `tools/tokens.sh` counts tokens of the encoding `o200k_base` (since 2026-11-20 with `build/tools/tokens`, the tokenizer in AIL, checked against `tiktoken` fixtures; before that with `tiktoken` itself) for the ten examples
and their C, Rust and assembly equivalents in `bench/`. Since the examples use expressions AIL is
11% cheaper than C and 17% cheaper than Rust, indented (13% and 19% without indentation; it was 17% and 10% dearer written as statements). Lines and numbers are what cost; keywords do not. Six algorithm programs added on 2026-11-20 are counted apart from that corpus: AIL 1524, C 1613, Rust 1783 (6% and 15% cheaper; `hashtab` went from 230 to 238 when its probe began to count words), with AIL dearer than C in `mergesort` and `graph`, where a `load` and a `store` each take a line that C writes as `*k++ = *j++`.
`tools/perf.aw` (until 2026-11-20 the Python script `tools/perf.py`) times the same programs.

## Facts
- With the examples rewritten in expressions and `while` (2026-11-20, later the same day): AIL
  970, C 1118, Rust 1191; AIL is cheaper than C in every program and dearer than Rust only in
  `count` and `fnv`. Indented with a tab a block level, as the examples are since then, AIL is
  990 (two or four spaces would be 1024) and two tokens dearer than C in `collatz`. Time against `gcc -O3`: geometric mean 1.041 (`collatz` 1.13, `isort` 1.06,
  `sieve` 1.03, the other two 1.00), from 1.742.
- Totals without comments on 2026-11-20 before that, ten programs written as statements: AIL 1313, C 1118, Rust 1191. The first
  six, which have assembly equivalents: AIL 496, C 448, Rust 464, assembly 925.
  The five short ones alone: AIL 382, C 342, Rust 344, assembly 696 (AIL was 411 at the first
  measurement, before compare-and-jump statements and syscall names). AIL wins on `hello` and
  `echo`.
- `compute` (2026-11-20) is the arithmetic benchmark: a hundred million steps of a 64-bit
  recurrence on a value read from stdin. It and its timing script were first written in a
  temporary directory outside the repository and nearly lost; they are now `examples/compute.aw`,
  `bench/compute.*` and `tools/perf.py` (now `tools/perf.aw`).
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
- `compiler/ailc.aw` is 6181 tokens in 1107 code lines; 1096 tokens are line ends, 422 are `as`.
- A number after a space is two tokens or more, a name one. `4294967295` is four tokens,
  `0xffffffff` two. `jz` and `jnz` are two tokens each; `load4` and `loadb` are two, `load` one.
- A comparison plus its conditional jump is twelve tokens; one compare-and-branch line would be
  seven. Stage1 has 55 such pairs.
- `tools/bench.sh` builds `bench/` with `gcc`, `rustc`, `as` and `ld` and checks output and exit
  status against the examples for empty input, for `hi` and for eight bytes; all 78 comparisons
  pass. A program may lack the assembly equivalent.

- Compared with Claude's tokenizers on 2026-11-21 (`tools/claudetokens.sh`, run by hand): no
  offline tokenizer of the current models exists, so the script sends the code of each program
  (`build/tools/tokens --code <mark> file`) to claudetokenizer.com, a third party that forwards
  to Anthropic's `count_tokens` (and to Google's count), chosen by the user knowing that the
  sources leave the machine. Corpus of ten, AIL/C/Rust/asm: `o200k_base` 941/1118/1191/925,
  Sonnet 4.6 1058/1355/1452/1070, Fable 5 1183/1506/1686/1251; C is 1.19, 1.28 and 1.27 times
  AIL, Rust 1.27, 1.37 and 1.43. The order holds and AIL gains. The three array programs are
  the exception with Fable 5 (817 against 800 and 792): prefixed library names cost more there.
- The endpoint is `POST /api` with `{"text","model","comparisonModel"}`; an empty text is
  refused; a message without text costs 5 tokens (Fable 5) and 6 (Sonnet 4.6), measured as
  twice the count of a line less that of the line twice, not the 7 the page subtracts; the
  last line end is not counted. Its `gpt4oTokens` equalled `build/tools/tokens` for all 63
  files. Answers are cached in `build/claudetokens/` by the SHA-256 of the text.

## Why
- **tiktoken in a virtual environment (chosen by the user):** no tokenizer was installed, and this
  one runs offline once installed, so no source leaves the machine. The alternative was the
  Anthropic token counting API, which gives exact Claude counts but sends every file out.
- **Comments stripped before counting:** the examples are heavily commented and the equivalents
  are not, and a comment is not what the language costs.
- **Not part of `make test`:** the build requires only `as` and `ld`; the measurement needs
  Python and network access once, the behaviour check `gcc` and `rustc`.

## How to apply
- Before choosing between two spellings, tokenize both (`build/tools/tokens --ids file`, or `-c '#' file` for a count; since 2026-11-20 the tokenizer is `tools/lib/o200k.aw`, which gives the numbers of `tiktoken`; `.venv` with `tiktoken` is no longer needed by any tool).
- Prefer a statement that removes a line over one that shortens a word.
- Replace numbers by names where the language can: constants, named data, global scalars.
- After changing an example, change its three equivalents in `bench/`, run `tools/bench.sh` and
  update the table in `docs/tokens.md`.

## Open items
- 2026-11-19: `count.s` uses a loop where the other three versions are unrolled.

## Related
- [Stage0 design decisions](stage0-design-decisions.md)
- [Stage1 self-hosting](stage1-self-hosting.md)
- [Open items](../status/open-items.md)

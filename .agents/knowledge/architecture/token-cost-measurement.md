---
title: Token cost measurement
last-verified: 2026-11-19
sources: [conversation 2026-11-19, tools/tokens.sh, docs/tokens.md]
status: current
---
# Token cost measurement

**Summary.** `tools/tokens.sh` counts tokens with `tiktoken` (`o200k_base`) for the five examples
and their C, Rust and assembly equivalents in `bench/`. AIL is 41% cheaper than assembly and about
20% dearer than C or Rust. Lines and numbers are what cost; keywords do not.

## Facts
- Totals without comments: AIL 411, C 342, Rust 344, assembly 696. AIL wins only on `hello`.
- `stage1/ailc.ai` is 6181 tokens in 1107 code lines; 1096 tokens are line ends, 422 are `as`.
- A number after a space is two tokens or more, a name one. `4294967295` is four tokens,
  `0xffffffff` two. `jz` and `jnz` are two tokens each; `load4` and `loadb` are two, `load` one.
- A comparison plus its conditional jump is twelve tokens; one compare-and-branch line would be
  seven. Stage1 has 55 such pairs.
- `tools/bench.sh` builds `bench/` with `gcc`, `rustc`, `as` and `ld` and checks output and exit
  status against the examples for empty input and for `hi`; all 30 comparisons pass.

## Why
- **tiktoken in a virtual environment (chosen by the user):** no tokenizer was installed, and this
  one runs offline once installed, so no source leaves the machine. The alternative was the
  Anthropic token counting API, which gives exact Claude counts but sends every file out.
- **Comments stripped before counting:** the examples are heavily commented and the equivalents
  are not, and a comment is not what the language costs.
- **Not part of `make test`:** the build requires only `as` and `ld`; the measurement needs
  Python and network access once, the behaviour check `gcc` and `rustc`.

## How to apply
- Before choosing between two spellings, tokenize both (`build/venv/bin/python` with `tiktoken`).
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

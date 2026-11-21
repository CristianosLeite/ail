---
title: Tools in AIL
last-verified: 2026-11-20
sources: [PR #4, PR #5, conversation 2026-11-20, tools/, tests/tools.sh, tests/infix.sh, docs/BACKLOG.md]
status: current
---
# Tools in AIL

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aw`,
> `tools/par.aw`, `tools/tokens.aw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aw`, `tools/lib/fmt.aw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aw` there.

**Summary.** Every tool that was a Python script is an AIL program since 2026-11-20
(`hashcol`, `fuse`, `infix`, `randvars`, `perf`, `tokens`, `par`), built by `build/ailc` as
`build/tools/<name>`. `make test` needs no Python. The ports were checked against the scripts'
output and differ from them in a few stated places.

## Facts
- Shared code is in `tools/lib/` (`scan.aw`, `flow.aw`, `rng.aw`, `fmt.aw`, `o200k.aw`) and in
  `lib/std/` (`bytes.aw`, `file.aw`, `proc.aw`). The prerequisites of each tool in the Makefile must
  be its `use` lines; `tests/tools.sh` compares them.
- The tokenizer (`tools/lib/o200k.aw`) needs two pinned files in `tools/pins/`, fetched by
  `tools/pin.sh` and ignored by git; `tests/tokens.sh` skips without them. Unicode is 16.0.0,
  the version tiktoken 0.14.0 splits by; with another the fixtures fail.
- Deliberate differences from the scripts: `fuse` leaves a jump with a string alone; `randvars`
  draws from splitmix64, so a seed gives another corpus (20 Python-made programs are kept in
  `tests/randvars/`); `perf` starts children with `fork`, and its startup figures are 2 to 10%
  lower.
- `perf` has three kinds of program since 2026-11-20: startup, CPU-bound and algorithm. An
  algorithm program is run on the rows of the table `work` (count, shape, runs), writes the
  nanoseconds of its kernels behind a checksum, and `perf` reads that file after every run
  ([page](algorithms-and-collections.md)). Its `froot` takes up to a million Newton steps: 200
  left the root of a product of 28 ratios far off, since a step from far above removes one
  part in n.
- `infix` never folds a name that a `var` declares. It reads the `var` lines of every file the
  source reaches with `use` (paths as written, from the current directory, like the compiler)
  and of files named after `out.aw`, for a source that another file includes:
  `build/tools/infix compiler/emit.aw out.aw compiler/ailc.aw`. A `use` that cannot be read
  ends the tool.
- That reading follows the compiler's lexing: leading spaces and tabs, a name ended by `#`, a
  string that goes on over the end of a line (its lines declare nothing), and a `use` path
  without escapes that ends at the next quote.
- `procstart` checks that its three descriptors are open, then puts them in place in an order
  that overwrites none still to be read; only descriptors that read one another in a ring
  need a copy (`F_DUPFD_CLOEXEC`). Any failure is a child that ends with 127.
- `procwait` keeps its limit when `pidfd_open` fails: `wait4` with `WNOHANG` every millisecond.

## Why
- **Ports instead of keeping Python:** the tools are the largest programs written in the
  language besides the compiler, so they test it, and the build depends on nothing but the seed.
- **Fixtures made by Python are kept:** the tool under test is compiled by the compiler it
  checks, so expected files from an independent implementation are what make the check real.
- **`infix` refuses an unreadable `use`:** a fold may delete a write to a global; guessing that
  a name is no `var` is how the original defect arose.
- **No temporary descriptor unless needed:** under a limit of open files an ordinary
  redirection must still work, as it did before the swap was supported.

## How to apply
- Run `infix` from the top of the repository, and for a file of the compiler name
  `compiler/ailc.aw` after the output.
- A scanner added to a tool that reads AIL source must agree with the compiler on tabs,
  comments, strings over lines and `use` paths; test each form.
- A new `use` in a tool needs the file in its Makefile line.
- A tool keeps state in `var`s that start with `g`; a library prefixes every name.

## Related
- [Token cost measurement](token-cost-measurement.md)
- [Test suite](../testing/stage0-test-suite.md)
- [Review fixes of 2026-11-20](review-fixes-2026-11.md)

---
title: Stage0 test suite
last-verified: 2026-11-20
sources: [stage1 review 2026-11-19 (REVIEW.md), control-flow review 2026-11-19 (REVIEW.md), functions review 2026-11-19 (REVIEW.md), conversation 2026-11-19, tests/run.sh]
status: current
---

> **2026-11-20:** stage0 (`stage0/ailc.s`) was removed; the compiler is `compiler/ailc.aiw` alone, built from a seed ([Seed bootstrap](../architecture/seed-bootstrap.md)). This page is kept for the reasons it records; routine names in it are those of stage0, and `docs/compiler.md` gives today's.
# Stage0 test suite

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aiw`,
> `tools/par.aiw`, `tools/tokens.aiw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aiw`, `tools/lib/fmt.aiw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aiw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aiw` there.

**Summary.** What the runner in `tests/run.sh` can and cannot prove, and the lessons from the
control-flow review about tests that pass for the wrong reason. `AGENTS.md` describes the file
layout of a test; this page records why some fixtures look the way they do.

## Facts
- Since 2026-11-20 the suite runs on one compiler, `build/ailc` (stage1), and no longer builds
  stage0. What replaced the comparison of the two compilers: `tests/self.sh` and `tests/fuzz.sh`
  compare `build/ailc1` (the source compiled by the seed) with `build/ailc` (compiled by that),
  one program in two translations; the fuzz also requires a proper end (status 0 with output
  and no message, or status 1 with one `ailc: ` line and no output); `tools/randvars.py` (since ported to AIL as `tools/randvars.aiw`) runs
  in `make test` (200 programs in a function, 200 at top level) against results computed in
  Python; `tests/insn.sh` checks instruction bytes against an assembler's. `make test` went
  from 2485 checks to 1635, since every test ran twice before.
- The comparison of the two translations is trivial while the seed is the current compiler
  (the files are identical); it becomes the check of self-compilation when code generation
  changes. A stage1 with one constant of `rdnum` changed, given as the second compiler, was
  found by the fuzz at source 1303 of 3000; wrappers that print two error lines or die of a
  signal fail at once.
- `tools/randvars.py` (rewritten 2026-11-20) renders each random tree twice, as statements
  with labels and jumps and as expressions with `x+=e`, `while` and `if` on a comparison, with
  all sixteen operators, redundant parentheses now and then, divisors forced non-zero by `|1`,
  and variables first assigned inside a loop or block kept to it (a `while` may run no round, so
  the compiler does not count them as assigned after it). Python runs the tree for the expected
  status. See the page on [expression code](../architecture/expression-syntax.md).
- Since the tools were ported (2026-11-20) `make test` needs no Python: `build/tools/randvars` computes the expected status itself, in a function that shares nothing with those that write the program, and has a third mode, 200 programs in an async function that waits before every third statement. The suite also runs `tests/async.sh`, `tests/par.sh`, `tests/tools.sh`, `tests/infix.sh` and `tests/tokens.sh`; it had 2413 checks on 2026-11-20. See [Tools in AIL](../architecture/tools-in-ail.md).
- The older facts below that speak of two compilers describe the suite before that date.
- `tests/make.sh` (since 2026-11-20) checks the recipe for examples in a scratch copy with the
  compiler already built: a good example builds and runs; after its source is broken the build
  fails twice, the old executable is byte for byte what it was and no temporary file remains;
  a faulty example that was never built leaves no target; a repaired one builds. With the
  recipe changed to write the target directly, two of its four checks fail. The target is made
  older with `touch -d` instead of waiting for the clock.
- `tests/fuzz.sh [count [seed]]` (since 2026-11-20) compares the two compilers on sources made
  by one to four random edits of a test, example or library source: a token from a dictionary
  put in, a span cut out, a byte replaced, the end cut off, a span repeated, a piece of another
  source added, a line end or a space moved. Exit status, output bytes and message must agree.
  It is seeded, so a run can be repeated, and `make test` runs 300 sources of seed 1 in about
  two seconds. It never executes a compiled program. Against a stage1 that accepts any byte
  after CR in `data`, 2000 sources of one seed gave two differences; a stage1 that accepts 17
  hexadecimal digits was not found in 3000, after which such literals went into the dictionary.
- `tests/bytes.sh` (since 2026-11-20) checks output bytes without trusting a compiler: six
  programs of one line repeated to fill 8 MiB (jumps forward, back, conditional; calls; buffer
  addresses; var cells), whose expected files, header included, awk writes from a formula. With
  the jump, call or name fixup table of stage0 made smaller, the ordinary suite still passes
  and this check fails. It takes five seconds for both compilers.
- The `od` of uutils breaks lines of a width that does not divide its buffer, so the check
  compares raw bytes written by awk (`printf "%c"` under `LC_ALL=C`), not dumps.
- `tests/run.sh` runs each compiled program under `timeout` with `limit=10` seconds; a timeout is
  a failed test. Before 2026-11-19 a program that never exited hung the whole suite.
- Until the functions review of 2026-11-19 the runner compared the status of `timeout` itself, so a
  program that hung passed a test expecting status 124. The program now runs under `sh -c`, which
  writes its status to `<name>.rc` in the run's directory; no file means the deadline expired and the test
  fails. `exit_status_124` keeps a normal exit with 124 passing.
- A review on 2026-11-19 ran eight runners at once and six failed, one with `Text file busy`:
  every run wrote `build/tests/<name>` and its companions. Each run now works in its own
  `mktemp -d build/tests/run.XXXXXX`, removed by an exit trap. The price is that the files of a
  failed test are gone when the runner ends; rerun the steps by hand to inspect them.
- A review on 2026-11-19 found that a program ignoring `SIGTERM` failed its test but kept
  running after the deadline. The runner now calls `timeout --signal=KILL` and, when that fails,
  sends `SIGKILL` itself to the process group, whose id the wrapper stored as `$PPID` (`timeout`
  makes itself a group leader). The second kill is needed: GNU `timeout` 9.7 signals the whole
  group and exits 137, but uutils `timeout` 0.10.0, the default on this machine, kills only the
  `sh` wrapper, exits 124 and leaves the program alive. Checked with both in a scratch copy with
  `limit=1`, using a program that ignores `SIGTERM` (`buf a 32`, `store a 1`, `sys 13 15 a 0 8`,
  then an endless loop); it is not in the suite because it would cost the full deadline each run.
- `tests/io.sh` holds the checks that are not "compile, run, compare": the compiler's exit
  status and message with stdin closed, with output to `/dev/full` and with output to a closed
  pipe. `make test` runs it after the suite when no `T` is given. The closed pipe is a fifo whose
  reader has already exited before the compiler starts; `ailc | true` would race with the exit of
  `true`. Without the `SIGPIPE` handling in the compiler the pipe case fails.
- `jump_fills_source` (10921 `jmp a` lines and one final `label a`) only proves that the fixup
  table holds that many entries: its first jump skips all the others, so it still passes when a
  later displacement is wrong.
- `jump_last_of_many` runs the last entry of a nearly full fixup table, a backward jump over all
  the others. `jump_chain` runs 2000 jumps, each to its own label over a `sys 60 1`.
- Mutations tried on a scratch copy of the compiler on 2026-11-19: leaving the last fixup
  unpatched fails `jump_last_of_many` and `jump_chain` but not `jump_fills_source`; wrapping the
  label index at 1024 fails only `jump_chain`; a `label again` / `jmp again` fixture fails by
  timeout instead of hanging.
- The control-flow review decoded all 10921 displacements of a full fixture by hand and found
  them correct. No test repeats that.

- A review of stage1 on 2026-11-19 (REVIEW.md) found three gaps in the scripts, all closed.
  `AILC=build/ailc1 make test` ran every runner with stage1, so stage0's I/O handling went
  untested while the suite passed; the Makefile now sets `AILC` on every run. A compiler that
  never ended stalled the suite, since only the compiled program had a deadline; `run.sh`,
  `io.sh` and `stage1.sh` now run the compilers under `timeout`, and `stage1.sh` fails a test
  whose status is above 2 even when both compilers agree on it. And nothing ran the write loop
  past its first write; `io_short_write` does.
- `io_short_write` opens a fifo read-write on descriptor 4 and runs a small AIL program with it
  as stdout, which calls `fcntl` for `F_SETPIPE_SZ` 4096 and `O_NONBLOCK`. Both belong to the
  open pipe, not the process, so the compiler started next inherits them: its first `write`
  takes 4096 bytes and its second fails. The case checks the prefix, the message and status 2.
  A stage1 that exits after its first write fails it. It cannot tell whether the second write
  starts at the right byte: that needs a reader draining between the writes, which is a race.
- Checked by hand on 2026-11-19: `AILC=/bin/false make test` passes; a compiler replaced by
  `sleep 100` fails `run.sh`, `io.sh` and `stage1.sh` after the deadline instead of hanging.

## Why
- **A deadline in the runner, not in each test:** control flow makes non-termination a normal
  failure mode of a compiler bug, and the runner otherwise never reports which test hung.
- **Fixtures that execute what they generate:** the runner sees only stdout and the exit status,
  so emitted code that never runs is not checked at all.
- **Size fixtures are kept beside behaviour fixtures:** one fills a table to its limit, the other
  runs every entry of a smaller table; a single source of 64 KiB cannot do both.

## How to apply
- A generated fixture that fills a table must also make the last entry run, or be paired with one
  that does.
- A program meant to skip code should make the skipped code exit with a distinct status, so a
  wrong jump changes the result instead of falling through unnoticed.
- Prove a new fixture by breaking the compiler in a scratch copy and seeing it fail; see the
  exit-status note in [Stage0 design decisions](../architecture/stage0-design-decisions.md).
- A test of a loop needs no timeout of its own; raise `limit` in `tests/run.sh` only if a
  legitimate program needs longer.

## Open items
- 2026-11-19: the runner cannot inspect emitted bytes, so nothing checks every displacement of a
  full fixup table; a wrong entry that is never executed goes unnoticed.

## Related
- [Stage0 design decisions](../architecture/stage0-design-decisions.md)
- [Open items](../status/open-items.md)

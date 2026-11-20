---
title: Stage0 test suite
last-verified: 2026-11-19
sources: [stage1 review 2026-11-19 (REVIEW.md), control-flow review 2026-11-19 (REVIEW.md), functions review 2026-11-19 (REVIEW.md), conversation 2026-11-19, tests/run.sh]
status: current
---
# Stage0 test suite

**Summary.** What the runner in `tests/run.sh` can and cannot prove, and the lessons from the
control-flow review about tests that pass for the wrong reason. `AGENTS.md` describes the file
layout of a test; this page records why some fixtures look the way they do.

## Facts
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

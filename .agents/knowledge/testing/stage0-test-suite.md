---
title: Stage0 test suite
last-verified: 2026-11-19
sources: [control-flow review 2026-11-19 (REVIEW.md), functions review 2026-11-19 (REVIEW.md), conversation 2026-11-19, tests/run.sh]
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
  writes its status to `build/tests/<name>.rc`; no file means the deadline expired and the test
  fails. `exit_status_124` keeps a normal exit with 124 passing.
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

# Open items

- [ ] 2026-11-19 — Measure token cost of AIL syntax with a real tokenizer against C, Rust and assembly ([page](../architecture/stage0-design-decisions.md))
- [ ] 2026-11-19 — Extend stage0 towards self-hosting: wider integers, then stage1 in AIL (arithmetic, assignment, memory access, comparison, control flow and functions done 2026-11-19) ([page](../architecture/stage0-design-decisions.md))
- [ ] 2026-11-19 — Lift the limit of six variables per function (spilling to the stack) if stage1 needs it ([page](../architecture/stage0-functions.md))
- [ ] 2026-11-19 — Decide what deep recursion should do: nothing checks for stack overflow, the program dies with SIGSEGV ([page](../architecture/stage0-functions.md))
- [ ] 2026-11-19 — Report a line number on compile errors ([page](../architecture/stage0-design-decisions.md))
- [ ] 2026-11-19 — Automate the Makefile failed-build check, which the test runner cannot express (compiler I/O errors are in `tests/io.sh` since 2026-11-19) ([page](../architecture/stage0-design-decisions.md))
- [ ] 2026-11-19 — Check emitted bytes in tests (every displacement of a full fixup table), which the runner cannot do today ([page](../testing/stage0-test-suite.md))

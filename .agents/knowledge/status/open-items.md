# Open items

- [x] 2026-11-19 — Measure token cost of AIL syntax with a real tokenizer against C, Rust and assembly ([page](../architecture/token-cost-measurement.md))
- [x] 2026-11-19 — Self-hosting: stage1 in AIL builds itself to a byte-identical file, with no change to stage0 ([page](../architecture/stage1-self-hosting.md))
- [ ] 2026-11-19 — Constant data: a string as a value outside `sys`, to replace the decimal tables of stage1; goes into both compilers ([page](../architecture/stage1-self-hosting.md))
- [ ] 2026-11-19 — More global names: stage1 uses all sixteen buffers ([page](../architecture/stage1-self-hosting.md))
- [ ] 2026-11-19 — Wider integers and a 32-bit store, if still wanted once constant data exists ([page](../architecture/stage1-self-hosting.md))
- [ ] 2026-11-19 — Put a differential fuzz of the two compilers in the suite ([page](../architecture/stage1-self-hosting.md))
- [ ] 2026-11-19 — Lift the limit of six variables per function (spilling to the stack) (stage1 did not need it) ([page](../architecture/stage0-functions.md))
- [ ] 2026-11-19 — Decide what deep recursion should do: nothing checks for stack overflow, the program dies with SIGSEGV ([page](../architecture/stage0-functions.md))
- [ ] 2026-11-19 — Report a line number on compile errors ([page](../architecture/stage0-design-decisions.md))
- [ ] 2026-11-19 — Automate the Makefile failed-build check, which the test runner cannot express (compiler I/O errors are in `tests/io.sh` since 2026-11-19) ([page](../architecture/stage0-design-decisions.md))
- [ ] 2026-11-19 — Check emitted bytes in tests (every displacement of a full fixup table), which the runner cannot do today ([page](../testing/stage0-test-suite.md))
- [ ] 2026-11-19 — Compare the tiktoken counts with Claude's tokenizer ([page](../architecture/token-cost-measurement.md))

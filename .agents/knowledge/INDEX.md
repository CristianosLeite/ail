# Knowledge index

## architecture
- [Stage0 design decisions](architecture/stage0-design-decisions.md) — why the syntax, the op table, direct ELF output, inline strings, buffers and jump fixups; review findings and known limits
- [Stage0 functions](architecture/stage0-functions.md) — callee-saved calling convention, one saved scope for labels and variables, separate call fixup list, mutation checks
- [Stage1 self-hosting](architecture/stage1-self-hosting.md) — the compiler in AIL: decisions, differential and mutation checks, friction found in the language
- [Token cost measurement](architecture/token-cost-measurement.md) — tiktoken counts against C, Rust and assembly, where AIL tokens go, rules for new syntax
- [Language extensions](architecture/language-extensions.md) — decisions taken while working through the TODO backlog: data and strings, and the ones that follow

## testing
- [Stage0 test suite](testing/stage0-test-suite.md) — runner deadline, fixtures that must execute what they generate, mutation checks, what goes unchecked

## status
- [Open items](status/open-items.md) — pending work

# Knowledge index

## architecture
- [Stage0 design decisions](architecture/stage0-design-decisions.md) — (stage0 was removed 2026-11-20; reasons still hold) why the syntax, the op table, direct ELF output, inline strings, buffers and jump fixups; review findings and known limits
- [Stage0 functions](architecture/stage0-functions.md) — callee-saved calling convention, one saved scope for labels and variables, separate call fixup list, mutation checks
- [Stage1 self-hosting](architecture/stage1-self-hosting.md) — the compiler in AIL: decisions, differential and mutation checks, friction found in the language
- [Seed bootstrap](architecture/seed-bootstrap.md) — the compiler in AIL built from a released copy of itself: the manifest, why a GitHub release, the rule for new syntax in the compiler source
- [Token cost measurement](architecture/token-cost-measurement.md) — tiktoken counts against C, Rust and assembly, where AIL tokens go, rules for new syntax
- [Language extensions](architecture/language-extensions.md) — decisions taken while working through the TODO backlog: data and strings, and the ones that follow
- [Targets and interoperability](architecture/targets-and-interoperability.md) — evaluation of a second architecture, object files, a platform ABI and dynamic linking: none now, with what each would take and when to reopen

## testing
- [Stage0 test suite](testing/stage0-test-suite.md) — runner deadline, fixtures that must execute what they generate, mutation checks, what goes unchecked

## status
- [Open items](status/open-items.md) — pending work

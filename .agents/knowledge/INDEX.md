# Knowledge index

## architecture
- [Stage0 design decisions](architecture/stage0-design-decisions.md) — (stage0 was removed 2026-11-20; reasons still hold) why the syntax, the op table, direct ELF output, inline strings, buffers and jump fixups; review findings and known limits
- [Stage0 functions](architecture/stage0-functions.md) — callee-saved calling convention, one saved scope for labels and variables, separate call fixup list, mutation checks
- [Stage1 self-hosting](architecture/stage1-self-hosting.md) — the compiler in AIL: decisions, differential and mutation checks, friction found in the language
- [Seed bootstrap](architecture/seed-bootstrap.md) — the compiler in AIL built from a released copy of itself: the manifest, why a GitHub release, the rule for new syntax in the compiler source
- [Expression syntax](architecture/expression-syntax.md) — infix without spaces, `x=e` and `x+=e`, Rust's precedence; the eight spellings counted and why the earlier rejection of infix was reversed
- [Token cost measurement](architecture/token-cost-measurement.md) — o200k_base counts against C, Rust and assembly, where AIL tokens go, rules for new syntax
- [Language extensions](architecture/language-extensions.md) — decisions taken while working through the TODO backlog: data and strings, and the ones that follow
- [Targets and interoperability](architecture/targets-and-interoperability.md) — evaluation of a second architecture, object files, a platform ABI and dynamic linking: none now, with what each would take and when to reopen
- [Async runtime](architecture/async-runtime.md) — `async fn`/`await` as polled tasks on one thread: the two await forms, eager futures, cancellation, why no multithreaded scheduler
- [Tools in AIL](architecture/tools-in-ail.md) — the Python tools ported: shared libraries, stated differences, how `infix` finds vars of other files, `procstart`/`procwait` rules
- [Source style and the formatter](architecture/source-style.md) — one tab a block, `build/tools/indent`, what is not indented, the VS Code extension, the token figures after indenting
- [Algorithm benchmarks and collections](architecture/algorithms-and-collections.md) — six kernels in AIL, C and Rust over one harness, kernel timing in `perf` (1.75 times C), `tests/algo.sh`, the rules of `vec`, `queue`, `heap` and `map`
- [Generated code after the algorithm measurements](architecture/generated-code-follow-up.md) — scaled index, registers by weight, two-jump `while`, calls in place: 1.75 to 1.20 times C; code placement moves times by a fifth
- [Review fixes of 2026-11-20](architecture/review-fixes-2026-11.md) — `tail` with a local, result count through `tail`, names of a `while` value, limit of locals, and why

## testing
- [Stage0 test suite](testing/stage0-test-suite.md) — runner deadline, fixtures that must execute what they generate, mutation checks, what goes unchecked

## status
- [Open items](status/open-items.md) — pending work

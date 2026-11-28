# Knowledge index

The benchmarks, the tools that time programs and count tokens, and what was learned about measuring are in the repository ail-bench (https://github.com/CristianosLeite/ail-bench) since 2026-11-21, with a knowledge base of their own. The pages here keep the decisions about the language, the compiler and the libraries that the measurements led to; each page that names a path that moved says so at its top.

The VS Code extension is in the repository ail-extensions (https://github.com/CristianosLeite/ail-extensions) since 2026-11-21, with a knowledge base of its own.

## architecture
- [Stage0 design decisions](architecture/stage0-design-decisions.md) — (stage0 was removed 2026-11-20; reasons still hold) why the syntax, the op table, direct ELF output, inline strings, buffers and jump fixups; review findings and known limits
- [Stage0 functions](architecture/stage0-functions.md) — callee-saved calling convention, one saved scope for labels and variables, separate call fixup list, mutation checks
- [Stage1 self-hosting](architecture/stage1-self-hosting.md) — the compiler in AIL: decisions, differential and mutation checks, friction found in the language
- [Seed bootstrap](architecture/seed-bootstrap.md) — the compiler in AIL built from a released copy of itself: the manifest, why a GitHub release, the rule for new syntax in the compiler source
- [Expression syntax](architecture/expression-syntax.md) — infix without spaces, `x=e` and `x+=e`, Rust's precedence; the eight spellings counted and why the earlier rejection of infix was reversed
- [Token cost measurement](architecture/token-cost-measurement.md) — o200k_base counts against C, Rust and assembly, where AIL tokens go, rules for new syntax, the same counted with Claude's tokenizers
- [Language extensions](architecture/language-extensions.md) — decisions taken while working through the TODO backlog: data and strings, and the ones that follow
- [Targets and interoperability](architecture/targets-and-interoperability.md) — evaluation of a second architecture, object files, a platform ABI and dynamic linking: none now, with what each would take and when to reopen
- [Async runtime](architecture/async-runtime.md) — `async fn`/`await` as polled tasks on one thread: the two await forms, eager futures, cancellation, why no multithreaded scheduler, variables across an `await` in the record and the others in registers
- [Tools in AIL](architecture/tools-in-ail.md) — the Python tools ported: shared libraries, stated differences, how `infix` finds vars of other files, `procstart`/`procwait` rules
- [Source style and the formatter](architecture/source-style.md) — one tab a block, `build/tools/indent` and `tools/lib/dent.aiw`, which `fuse` and `infix` write through, what is not indented, the VS Code extension and its check of the grammar, the token figures after indenting
- [Algorithm benchmarks and collections](architecture/algorithms-and-collections.md) — six kernels in AIL, C and Rust over one harness, kernel timing in `perf`, `tests/algo.sh` for the three languages, the rules of `vec`, `queue`, `heap` and `map` and what they cost (1.07 to 2.2 times C at a million keys, 7 to 16 at a thousand, where `alloc` is an `mmap`)
- [Numerical arrays (lib/nd)](architecture/numerical-arrays.md) — the 176-byte descriptor, views, the one walk that is broadcasting, results given by the caller, sums in the order of a C loop, NumPy fixtures as data, 3.65 times C and 2.18 with two doubles at once, tasks for the product
- [Generated code after the algorithm measurements](architecture/generated-code-follow-up.md) — scaled index, registers by weight, two-jump `while`, calls in place (also of bodies that call and name globals, four deep), short slot displacements, `test` with a mask and `lea`, loops aligned to 64 bytes so that placement moves times by 1 to 3% where it was a fifth, `perf --places`; what was decided against
- [Source extension](architecture/source-extension.md) — `.aiw` since 2026-11-21: `.aw` is PHP in GitHub Linguist, the names looked at, what Linguist asks before it takes a language
- [Review fixes of 2026-11-20](architecture/review-fixes-2026-11.md) — `tail` with a local, result count through `tail`, names of a `while` value, limit of locals, and why
- [Packages, the manifest and the ail command](architecture/packages.md) — one mechanism of versions and dependencies; `use "name:path"`, `lib/` as the package of AIL, packages from the compiler's arguments
- [Numbers from text, JSON and HTTP](architecture/text-and-network.md) — `lib/std/num.aiw`, a decimal as the nearest double for every text; `lib/std/json.aiw`, read in place with no tree, I-JSON strict; `lib/net/http.aiw` and `httpd.aiw`, a client and a server on the async sockets; `lib/std/sha.aiw`, SHA-256, moved from aildb (user, 2026-11-24); libraries of AIL at the user's word, checked against Python, Ollama and curl

## testing
- [Stage0 test suite](testing/stage0-test-suite.md) — runner deadline, fixtures that must execute what they generate, mutation checks, what goes unchecked
- [The tests of Windows run on Windows itself](testing/windows-itself.md) — `tests/win.sh` from WSL 2 with a `wine` that starts the program; the tree on NTFS, not the share; 607 tests on Windows 11, 2026-11-27

## status
- [Open items](status/open-items.md) — pending decisions; the packages and the `ail` command since 2026-11-22

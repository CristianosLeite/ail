# Open items

> Since 2026-11-21 the VS Code extension is in the repository ail-extensions
> (https://github.com/CristianosLeite/ail-extensions): `editors/vscode/` on this page is a path there, and its check is
> `make check` there.

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aiw`,
> `tools/par.aiw`, `tools/tokens.aiw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aiw`, `tools/lib/fmt.aiw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aiw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aiw` there.

- [x] 2026-11-19 — Measure token cost of AIL syntax with a real tokenizer against C, Rust and assembly ([page](../architecture/token-cost-measurement.md))
- [x] 2026-11-19 — Self-hosting: stage1 in AIL builds itself to a byte-identical file, with no change to stage0 ([page](../architecture/stage1-self-hosting.md))
- [x] 2026-11-19 — Constant data: a string as a value outside `sys`, to replace the decimal tables of stage1; goes into both compilers ([page](../architecture/language-extensions.md))
- [x] 2026-11-19 — More global names: stage1 uses all sixteen buffers ([page](../architecture/language-extensions.md))
- [x] 2026-11-19 — A 16- and 32-bit load and store, and wider integers ([page](../architecture/language-extensions.md))
- [x] 2026-11-19 — Put a differential fuzz of the two compilers in the suite ([page](../testing/stage0-test-suite.md))
- [x] 2026-11-19 — Lift the limit of six variables per function (spilling to the stack) (stage1 did not need it) ([page](../architecture/language-extensions.md))
- [x] 2026-11-19 — Decide what deep recursion should do: nothing checks for stack overflow, the program dies with SIGSEGV ([page](../architecture/language-extensions.md))
- [x] 2026-11-19 — Report a line number on compile errors ([page](../architecture/language-extensions.md))
- [x] 2026-11-19 — Automate the Makefile failed-build check, which the test runner cannot express (compiler I/O errors are in `tests/io.sh` since 2026-11-19) ([page](../testing/stage0-test-suite.md))
- [x] 2026-11-19 — Check emitted bytes in tests (every displacement of a full fixup table), which the runner cannot do today ([page](../testing/stage0-test-suite.md))
- [x] 2026-11-20 — The redesign of `docs/REDESIGN.md`: seed bootstrap and removal of stage0, infix expressions and `while`, instruction selection, corpus and compiler rewritten; report in `docs/performance.md` ([seed](../architecture/seed-bootstrap.md), [syntax](../architecture/expression-syntax.md))
- [x] 2026-11-20 — `collatz` was 12.6% behind C: `test` with a mask and one `lea` for `x*3+1` bring the median of eight placements from 1.121 to 1.106 (2026-11-21); folding one branch into another needs analysis across statements and is not done, by decision ([page](../architecture/generated-code-follow-up.md))
- [x] 2026-11-19 — The tiktoken counts compared with Claude's tokenizers on 2026-11-21 (`tools/claudetokens.sh`): C is 1.27 times AIL with Fable 5 and 1.28 with Sonnet 4.6 where `o200k_base` says 1.19, Rust 1.43 and 1.37 for 1.27 ([page](../architecture/token-cost-measurement.md))
- [x] 2026-11-20 — Port the Python tools to AIL ([page](../architecture/tools-in-ail.md))
- [x] 2026-11-20 — Native asynchronous execution: runtime, `async fn` and `await`, pool, channels, measurements ([page](../architecture/async-runtime.md))
- [x] 2026-11-20 — "Source style and editor tooling" of `docs/BACKLOG.md`: convention, `build/tools/indent`, VS Code extension, every source indented ([page](../architecture/source-style.md))
- [x] 2026-11-20 — Indentation in `fuse` and `infix`: both write their results through `dtindent` of `tools/lib/dent.aiw` since 2026-11-21 ([page](../architecture/source-style.md))
- [x] 2026-11-20 — The grammar and folding of the VS Code extension checked on every source with the editor's own libraries (`editors/vscode/check.sh`, 2026-11-21; 579 lines were wrong and are fixed); the installed copy is a symlink to `editors/vscode/`, and the user found it working in the editor ([page](../architecture/source-style.md))
- [x] 2026-11-20 — The variables of an async function that cross no `await` are in registers since 2026-11-21: a loop between two waits is a fifth faster (`bench/async/calc`) ([page](../architecture/async-runtime.md))
- [x] 2026-11-20 — "Algorithm benchmarks and collection APIs" of `docs/BACKLOG.md`: six programs with C and Rust forms, kernel times in `perf`, `lib/std/vec.aiw`, `queue.aiw`, `heap.aiw`, `map.aiw` ([page](../architecture/algorithms-and-collections.md))
- [x] 2026-11-20 — Items 5 and 6 of "Performance follow-up": calls of short functions compiled in place, `hashtab` probing in words; the kernels are at 1.20 times C, `hashtab` at 1.24 ([page](../architecture/generated-code-follow-up.md))
- [x] 2026-11-20 — Kernel times at a thousand elements moved by a fifth with the place of the code: since 2026-11-21 the first line of a loop starts at a multiple of 64, the times of eight places differ by 0.3 to 2.6%, and `perf --places` measures them ([page](../architecture/generated-code-follow-up.md))
- [x] 2026-11-20 — Calls in place take functions that call or name a `buf`, `data` or `var`, and bodies inside bodies four deep, since 2026-11-21 (the compiler 6% faster, tools 3 to 8%); calls at top level stay calls by decision, and a function that needs a stack slot, as `sift` of `heapsort`, is not compiled in place ([page](../architecture/generated-code-follow-up.md))
- [x] 2026-11-20 — Run the Rust algorithm programs against the references of `tests/algo.sh`: done on 2026-11-21, all nine pass ([page](../architecture/algorithms-and-collections.md))
- [x] 2026-11-20 — The collections timed on their own against C and Rust (`collseq`, `collmap`, 2026-11-21): 1.07 to 2.2 times C at a million keys, 7 to 16 times at a thousand, where each `alloc` is an `mmap` ([page](../architecture/algorithms-and-collections.md))
- [x] 2026-11-20 — "Performance follow-up" of `docs/BACKLOG.md`, items 1 to 4: scaled indexes, registers by weight, a `while` on two comparisons, task sizes ([page](../architecture/generated-code-follow-up.md))
- [x] 2026-11-20 — Stack slots have the shortest displacement and are not loaded again right after a store since 2026-11-21; `heapsort` gains 6%, `mergesort` 4% (the loss of `bsearch` at a thousand elements noted here was the place of its code) ([page](../architecture/generated-code-follow-up.md))
- [x] 2026-11-21 — Item 5 of "Native numerical arrays": blocking and tasks for `ndmatmul`, a loop over words for a number as an operand, packed instructions if the figures ask for them ([page](../architecture/numerical-arrays.md))
- [x] 2026-11-21 — `ndsumpw` adds two doubles at once into sixteen sums (`ndpack`), 0.66 to 0.85 of its time with `fsum`; `ndsum` and `nddot` are at the time of C since `fsum` and `fdot` ([page](../architecture/numerical-arrays.md))
- [ ] 2026-11-22 — Packages: the user is to review what the agent chose in the compiler (packages from arguments `name=directory`, `lib/` as the package `ail`, a path from the root in no package); the names `Ailfile` and `Ailfile.lock`, the rules of a version and of the line `ail`, and 0.1.0 as the first version of AIL, also chosen by the agent; the command is the open section of `docs/TODO.md` ([page](../architecture/packages.md))
- [ ] 2026-11-22 — Numbers from text, JSON and HTTP: the user is to review what the agent chose (no tree for JSON and the two rules of I-JSON, no function that writes a double, the request and the handler as bytes the caller owns, one request a connection), the version of AIL that has them is 0.1.1 (user, 2026-11-22) ([page](../architecture/text-and-network.md))
- [ ] 2026-11-28 — The services `anon`, `kill`, `openat`, `fdpath` and `lockfd`, and `sync` of a directory on Windows: the user is to review what the agent chose (a file of `anon` with a name on Windows while it is open, `kill` for a child alone and -9 from `reap`, one name and the error -40 for `openat`, its flag 0x200000 and a directory made by 64 with 0x10000, a directory that keeps its name on Windows while it is open, `lockfd` for a plain file alone, a flush of a directory that Windows does not document); the version of AIL that has them is the user's to give ([page](../architecture/directory-services.md))
- [x] 2026-11-28 — An executable of Windows that is loaded at an address Windows chooses (ASLR): the user decided it for a pull request of its own, after Microsoft Defender took a program of the tests for malware again; it is the pull request 43, merged by the user the same day (`11bf120`), and `docs/TODO.md` has what is left of the item ([page](../architecture/directory-services.md))
- [ ] 2026-11-28 — The fixes after the review of `c5ed7fb` (the pull request 42): the user is to review what the agent chose (an error of `kill` where there is no descriptor of the child and the number is not sure to be its own, -9 for a number that is no descriptor, a descriptor opened only to be asked that is noted on Windows and gives -9 for a read, a write, a lock and its names, the flag 0x800000 of `openat` for a file that keeps its name, which does nothing on Linux, a path of `fdpath` that is asked what is at it) ([page](../architecture/directory-services.md))

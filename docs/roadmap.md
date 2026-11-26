# Roadmap

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aiw`,
> `tools/par.aiw`, `tools/tokens.aiw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aiw`, `tools/lib/fmt.aiw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aiw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aiw` there.

The goal of the proof of concept is a language that is cheap in tokens for an AI to write, compiled by a compiler written in that same language.

## Done

- Stage0 compiler in assembly that emits ELF64 directly.
- `sys`, a raw syscall with integer and string arguments.
- Register-backed variables: `as name` keeps a statement's result, and a variable can be passed as an argument.
- Assignment and arithmetic: `set`, `add`, `sub`, `mul`, `div`, `mod`, `and`, `or`, `xor`, `shl`, `shr`.
- Comparisons: `eq`, `ne`, `lt`, `le`, `gt`, `ge` keep `1` or `0` in a variable, unsigned.
- Memory access: `buf` reserves writable memory in a second ELF segment; `load`, `loadb`, `store` and `storeb` read and write 64-bit values and bytes.
- Control flow: `label`, `jmp`, `jz` and `jnz`, with forward jumps patched from a fixup list at the end of the single pass.
- Functions: `fn` ... `end`, `call` and `ret`, with up to 64 parameters, variables and labels local to each function, recursion and forward calls.
- Stage1: the compiler written in AIL (`compiler/ailc.aiw`) with the same behaviour as stage0. Stage0 built it, it builds itself, and the two outputs are byte-identical.
- One compiler (2026-11-20): the build starts from a released copy of the compiler, a seed pinned by checksum in `seed/MANIFEST`, the tables of the compiler are their own source, the tests stand without a second compiler, and stage0 is removed.
- Hello world, and a test runner whose tests can expect output, an exit status or a compile error.

## Next: develop the language in AIL

The language is developed in the compiler written in AIL, the only one since 2026-11-20. A new feature that the compiler itself is to use is implemented first in the language the pinned seed understands; then a seed is released, and the source may use the feature ([details](compiler.md#building-it)). Writing the compiler in AIL needed no change to the language, and showed where it costs most. In rough order of value:

1. **Constant data** (done): `data` names read-only bytes, a string is a value in every statement and `len` gives a length. Stage1 keeps its tables that way.
2. **More global names** (done): any number of buffers, `var` for global scalars and `const` for named numbers.
3. **Wider integers** (done): 64-bit, negative and hexadecimal literals, and 16- and 32-bit memory accesses.
4. **More than six variables per function** (done): 64 per scope; a function reuses registers whose variable is done and spills to the stack.

## Next: expressions and generated code

`REDESIGN.md` sets the goals: fewer tokens than Rust on the ten programs of the corpus, arithmetic and control flow written directly, and elapsed time on CPU-bound programs within 5% of C at `-O3`. In order:

1. **Infix expressions** as arguments and in `name = expression`, `if` with an expression, and a `while` block, with the syntax fixed by counting tokens on the corpus.
2. **Instruction selection**: immediate operands, variables used where they are, an assignment computed in the register of its target, the test of a loop at its end. The measurements in [performance.md](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md) say where the time goes today.
3. **The corpus, the library and the compiler rewritten** in the new forms, the compiler after a second seed that understands them.

All three are done as of 2026-11-20: the corpus is 990 tokens (970 before it was indented; 941 since 2026-11-21, when `isort` became a caller of `lib/algo/`, and 942 with the sources named `.aiw`, whose `use` line costs a token more) against 1118 for C and 1191 for Rust, the CPU-bound programs take 1.04 times as long as C in the geometric mean, and the compiler is written with expressions and built from seed 2.

## Supporting work

- Source style (2026-11-20): sources are indented with one tab for each block, which costs 2% in tokens (990 against 970 on the corpus; spaces would cost 5.6%) and nothing in the program. `build/tools/indent` sets the indentation and changes no other byte, `--check` reports it, and `make test` holds every source to it; `editors/vscode/` is an extension for VS Code with highlighting, folding and formatting through that tool. Every source was indented with its executables compared before and after.
- Asynchronous execution (2026-11-20): `async fn` and `await` compile a function into a task that one thread polls, with its variables in a record on the heap and no stack of its own; `lib/async/` has the runtime, written in AIL after the model of Tokio: the queue, timers, an `epoll` driver for sockets, work handed to the pool of `spawn`, cancelling, stopping, channels and the first of several. A TCP echo server is 259 tokens against 503 in C on `epoll`, and carries the same 280000 round trips a second on one thread ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#async-2026-11-20)).

- Token cost is measured with a real tokenizer against equivalent C, Rust and assembly ([results](https://github.com/CristianosLeite/ail-bench/blob/main/docs/tokens.md)): AIL costs 11% fewer tokens than C and 17% fewer than Rust on ten programs, indented (it cost 17% and 10% more before expressions). Use `tools/tokens.sh` of ail-bench to choose between syntax alternatives.
- Elapsed time is measured against the same programs built with `gcc -O3` and `rustc -O` ([results](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md)): an AIL program starts in a third of the time of the C one; the five CPU-bound programs take 1.04 times as long as C in the geometric mean, four of them within 6% and one 13% behind (the mean was 1.74 before the compiler chose instructions).
- Numerical arrays (2026-11-21): `lib/nd/` has arrays of doubles and of 64-bit integers on the model of NumPy, with views, broadcasting, sums, means and products, checked against results of NumPy that are committed as data. Its kernels took 3.65 times as long as plain loops in C when first measured and take 2.18 times since the statements `padd`, `psub`, `pmul`, `pdiv` and `pmadd` compute two doubles at once; the product of matrices also runs in tasks, and the sums that keep their order take the time of C since `fsum` and `fdot` keep the sum in a floating-point register ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#numerical-arrays-2026-11-21)).
- Six algorithm programs (three sorts, a binary search, a hash table, a graph traversal) are timed kernel by kernel against C and Rust ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#algorithms-2026-11-20)): 1.75 times the time of C in the geometric mean when first measured and 1.20 after the follow-up of the same day (a scaled index in the memory operand, registers given to the variables the loops mention most, a `while` on two comparisons as two jumps, calls of short functions compiled in place). Those figures had the clock of the harness as a system call in AIL alone; read through the vDSO as in C and Rust, the six programs and the three array programs are at 1.20 over 62 kernel times ([the clock](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#the-clock-of-the-harness-2026-11-21)). The time of a kernel on a thousand elements moves by a fifth with the place of its code, so two builds are compared over several places. `lib/` has a vector, a bounded queue, a heap and a hash map ([reference](language.md#the-vector-library)).
- Compile errors name the line, the file, the name at fault and a specific cause, since the error message is what an AI uses to repair its program.
- Packages (2026-11-22): a project has a manifest, `Ailfile`, with its name, its version and the packages it uses, and AIL has a version of its own, apart from the number of the seed; `use "name:path"` reads a file of another package, and the command `ail` makes a package, fetches its dependencies at locked revisions, builds, runs, tests and formats it ([packages](packages.md), [the command](cli.md)).

## Not planned

- Linkable object files and dynamic linking were evaluated on 2026-11-20 and left out: each would add a file format to the compiler and a linker to every build. A second target architecture and a platform calling convention were left out with them and are planned since 2026-11-26, behind a runtime that the compiler copies into each executable ([RUNTIME.md](RUNTIME.md)).

# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

AIL is a proof-of-concept programming language whose design goal is low token consumption when an AI writes it. It is hardware-oriented (assembly-like, no classes or objects) and human readability is explicitly not a goal. When adding syntax, prefer short common words and bare spaces over punctuation and boilerplate, and let the compiler infer anything derivable (for example, a string literal supplies its own length).

The plan is to bootstrap: stage0 is written in assembly, and later compiler versions are to be written in AIL itself. Self-hosting is not started; the language first needs memory access, arithmetic, control flow and functions.

## Rules

- All repository text is in English: documentation, code comments, commit messages, test names, compiler messages and the knowledge base. This holds even when the conversation is in another language.

## Commands

Requires GNU `as` and `ld` on x86-64 Linux.

```
make            # build build/ailc and build/hello
make test       # run every test in tests/
make test T=hello   # run one test
make build/foo  # compile examples/foo.ai to build/foo
make clean
```

The compiler reads source on stdin and writes the executable on stdout:

```
build/ailc < prog.ai > prog && chmod +x prog
```

A test is a set of files `tests/<name>.*`, run by `tests/run.sh`:

- `.ai`: the program, or `.ai.sh`, a script that prints it (used for generated sources such as the size-limit tests)
- `.out`: expected stdout of the compiled program
- `.code`: expected exit status of the compiled program, default 0
- `.err`: expected compiler stderr; the compiler must then exit 1

A test has either `.err` (compiling must fail) or `.out` (the program must run). Not covered by the runner and checked by hand: the compiler's I/O errors (`build/ailc <&-`, output to `/dev/full`) and the Makefile's behaviour after a failed example build.

Compiler errors are one line on stderr with no location: `ailc: syntax error`, `ailc: undefined variable`, `ailc: too many variables` or `ailc: source too big` exit 1; `ailc: read error` or `ailc: write error` exit 2.

## Language (stage0)

`docs/language.md` is the language reference and `docs/compiler.md` explains the compiler; keep both in sync with `stage0/ailc.s`. The only statement is `sys n a b ...` (raw Linux syscall, up to 6 arguments; `n` must be a decimal number). Arguments are unsigned 32-bit decimals, string literals or variables; a string expands to two arguments, address then length. `as name` at the end of a `sys` keeps the syscall's return value in a variable; that is the only way to set one. Variables are 64-bit, at most 6, and each is bound to one register for the whole program. `#` comments to end of line. Execution starts at the first line and `exit(0)` is appended.

## Compiler architecture (`stage0/ailc.s`)

GNU as, Intel syntax (`.intel_syntax noprefix`). Single pass with no AST or fixups, and a six-entry variable table as the only symbol table: it reads all of stdin into a buffer, emits machine code into an output buffer as it scans, and writes the buffer once at the end.

- **Output is a complete ELF64** emitted by the compiler itself: a 120-byte header template (ELF header plus one R+X `PT_LOAD` segment) is copied in first, code follows at file offset 120, and the image is loaded at the fixed address `0x400000`. The only back-patch is the segment file/memory size at the end.
- **Fixed register roles** throughout: `rsi`/`r15` input cursor and end, `rdi`/`r14` output cursor and base, `ebx` index of the next syscall argument, `ebp` number of variables defined. Routines rely on these rather than passing parameters.
- **Arguments** are emitted by `emit_mov` as `mov r32, imm32` into the register chosen by `regtab` (rax, rdi, rsi, rdx, r10, r8, r9). This zero-extends, which is why values are limited to unsigned 32 bits.
- **Variables** live in the generated program's `rbx`, `rbp`, `r12`, `r13`, `r14`, `r15` (table `varnum`), assigned in order of first `as`. The compiler's table `vars` stores each name as a pointer into the input buffer plus a length. `emit_mov_rr` emits the 64-bit register-to-register `mov` used both to pass a variable and to capture `rax`.
- **Strings** are inlined in the code stream behind a `jmp rel32`, so their absolute address is known immediately and no data section or second pass is needed. The segment is not writable, so string data is read-only.

Adding a statement means adding a keyword check in `next` (currently it accepts only `sys`) and an emitter, plus tests for what it accepts and rejects. Do not name a label after an assembler keyword: `jbe word` assembles without a warning and jumps to the wrong place. Anything needing forward references (labels, functions) will require fixups, which the single-pass design does not have yet.

# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

AIL is a proof-of-concept programming language whose design goal is low token consumption when an AI writes it. It is hardware-oriented (assembly-like, no classes or objects) and human readability is explicitly not a goal. When adding syntax, prefer short common words and bare spaces over punctuation and boilerplate, and let the compiler infer anything derivable (for example, a string literal supplies its own length).

The plan is to bootstrap: stage0 is written in assembly, and later compiler versions are to be written in AIL itself. Self-hosting is not started; the language first needs control flow and functions.

## Rules

- All repository text is in English: documentation, code comments, commit messages, test names, compiler messages and the knowledge base. This holds even when the conversation is in another language.

## Commands

Requires GNU `as` and `ld` on x86-64 Linux.

```
make            # build build/ailc and every example in examples/
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

Compiler errors are one line on stderr with no location: `ailc: syntax error`, `ailc: undefined variable`, `ailc: too many variables`, `ailc: duplicate name`, `ailc: too many buffers` or `ailc: source too big` exit 1; `ailc: read error` or `ailc: write error` exit 2.

## Language (stage0)

`docs/language.md` is the language reference and `docs/compiler.md` explains the compiler; keep both in sync with `stage0/ailc.s`. Statements:

- `sys n a b ...`: raw Linux syscall, up to 6 arguments; `n` must be a decimal number.
- `set a as x`, and `add sub mul div mod and or xor shl shr` as `op a b as x`: 64-bit, wrapping, unsigned division and shift.
- `eq ne lt le gt ge` as `op a b as x`: 64-bit comparison, unsigned order, result `1` or `0`.
- `buf name size`: reserves zero-filled writable bytes (rounded up to 8); the name is a constant address, at most 16 buffers.
- `load p as x`, `loadb p as x`, `store p a`, `storeb p a`: 64-bit and byte access at address `p`.

Arguments are unsigned 32-bit decimals, string literals, variables or buffer names; a string expands to two arguments, address then length, and is accepted only by `sys`. `as name` at the end of a statement keeps its result in a variable; that is the only way to set one. It is required on everything that produces a value, forbidden on stores and optional on `sys`. Variables are 64-bit, at most 6, and each is bound to one register for the whole program. Variables and buffers share one name space; keywords are only special at the start of a line. Tokens are separated by spaces or tabs only and may not touch; lines end with LF or CRLF; any other separator byte is a syntax error. `#` comments to end of line. Execution starts at the first line and `exit(0)` is appended.

## Compiler architecture (`stage0/ailc.s`)

GNU as, Intel syntax (`.intel_syntax noprefix`). Single pass with no AST or fixups; the only symbol tables are a six-entry variable table and a sixteen-entry buffer table: it reads all of stdin into a buffer, emits machine code into an output buffer as it scans, and writes the buffer once at the end.

- **Output is a complete ELF64** emitted by the compiler itself: a 176-byte header template (ELF header plus two `PT_LOAD` segments) is copied in first, code follows at file offset 176, and the image is loaded R+X at the fixed address `0x400000`. The second segment is R+W, has no file bytes and maps the buffers at the fixed address `0x10000000`. The only back-patches are the segment sizes at the end.
- **Fixed register roles** throughout: `rsi`/`r15` input cursor and end, `rdi`/`r14` output cursor and base, `ebx` index of the next syscall argument, `ebp` number of variables defined. Routines rely on these rather than passing parameters.
- **Statements are rows of `optab`**: keyword, operand count, flags and instruction bytes. Operands go through the same parser as syscall arguments, so they land in `rax` and `rdi`; `emit_op` then copies the row's bytes where `sys` gets its `syscall`, and the result is left in `rax` for `as`. `curop` points at the current row. `buf` is the one statement parsed on its own (`bufdef`).
- **Arguments** are emitted by `emit_mov` as `mov r32, imm32` into the register chosen by `regtab` (rax, rdi, rsi, rdx, r10, r8, r9). This zero-extends, which is why values are limited to unsigned 32 bits.
- **Variables** live in the generated program's `rbx`, `rbp`, `r12`, `r13`, `r14`, `r15` (table `varnum`), assigned in order of first `as`. The compiler's table `vars` stores each name as a pointer into the input buffer plus a length. `emit_mov_rr` emits the 64-bit register-to-register `mov` used both to pass a variable and to capture `rax`.
- **Buffers** are compile-time addresses in the writable segment (tables `bufs` and `bufaddr`, total in `bsssz`), passed as an `imm32` by `emit_mov`.
- **Strings** are inlined in the code stream behind a `jmp rel32`, so their absolute address is known immediately and no data section or second pass is needed. The code segment is not writable, so string data is read-only.

Adding a statement that takes values in `rax`/`rdi` and leaves a result in `rax` means adding a row to `optab`; anything else needs a keyword check in `next` (as `buf` has) and its own parser ending in `eol`. Either way add tests for what it accepts and rejects. Do not name a label after an assembler keyword: `jbe word` assembles without a warning and jumps to the wrong place. Anything needing forward references (labels, functions) will require fixups, which the single-pass design does not have yet.

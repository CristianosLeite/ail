# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

AIL is a proof-of-concept programming language whose design goal is low token consumption when an AI writes it. It is hardware-oriented (assembly-like, no classes or objects) and human readability is explicitly not a goal. When adding syntax, prefer short common words and bare spaces over punctuation and boilerplate, and let the compiler infer anything derivable (for example, a string literal supplies its own length).

The plan is to bootstrap: stage0 is written in assembly, and later compiler versions are to be written in AIL itself. Self-hosting is not started; the language first needs variables, memory access, arithmetic, control flow and functions.

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

A test is a pair `tests/<name>.ai` and `tests/<name>.out` (expected stdout); `tests/run.sh` compiles and runs each one and passes it when it exits 0 with exactly that output. Add a test by adding the two files. Tests that expect a compile error or a non-zero exit status are not supported yet. On any error the compiler prints `ailc: syntax error` to stderr and exits 1, with no location.

## Language (stage0)

`README.md` holds the spec; keep it in sync with the compiler. The only statement is `sys n a b ...` (raw Linux syscall, up to 6 arguments). Arguments are unsigned 32-bit decimals or string literals; a string expands to two arguments, address then length. `#` comments to end of line. Execution starts at the first line and `exit(0)` is appended.

## Compiler architecture (`stage0/ailc.s`)

GNU as, Intel syntax (`.intel_syntax noprefix`). Single pass with no AST, symbol table or fixups: it reads all of stdin into a buffer, emits machine code into an output buffer as it scans, and writes the buffer once at the end.

- **Output is a complete ELF64** emitted by the compiler itself: a 120-byte header template (ELF header plus one R+X `PT_LOAD` segment) is copied in first, code follows at file offset 120, and the image is loaded at the fixed address `0x400000`. The only back-patch is the segment file/memory size at the end.
- **Fixed register roles** throughout: `rsi`/`r15` input cursor and end, `rdi`/`r14` output cursor and base, `ebx` index of the next syscall argument. Routines rely on these rather than passing parameters.
- **Arguments** are emitted by `emit_mov` as `mov r32, imm32` into the register chosen by `regtab` (rax, rdi, rsi, rdx, r10, r8, r9). This zero-extends, which is why values are limited to unsigned 32 bits.
- **Strings** are inlined in the code stream behind a `jmp rel32`, so their absolute address is known immediately and no data section or second pass is needed. The segment is not writable, so string data is read-only.

Adding a statement means adding a keyword check in `next` (currently it accepts only `sys`) and an emitter. Anything needing forward references (labels, functions) will require fixups, which the single-pass design does not have yet.

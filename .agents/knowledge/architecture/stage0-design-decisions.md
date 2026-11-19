---
title: Stage0 design decisions
last-verified: 2026-11-19
sources: [commit 787fe7e, code review 2026-11-19, conversation 2026-11-19, stage0/ailc.s]
status: current
---
# Stage0 design decisions

**Summary.** Why the bootstrap compiler (`stage0/ailc.s`) and the first syntax look the way they do,
what was verified, and what the choices cost later. `AGENTS.md` describes the structure; this page
records the reasoning.

## Facts
- Hello world is `sys 1 1 "hello world\n"` and compiles to a 168-byte static ELF64 (120 bytes of
  headers, 48 of code and string).
- Covered by tests since 2026-11-19: escapes, comments, several statements, explicit exit status,
  six arguments, every syntax-error cause, and the 65536-byte source limit on both sides.
- A code review on 2026-11-19 found four defects, all fixed: `sys` with no number or with a string
  as the number compiled; a source of exactly 64 KiB was rejected; I/O failures were reported as
  syntax errors; and a failed example build left an empty executable that Make treated as current.
  `sys1 1 "x"` (no blank after the keyword) was also accepted and is now rejected.
- Checked by hand only, because the runner cannot express them: `build/ailc <&-` gives
  `ailc: read error`, output to `/dev/full` gives `ailc: write error` (both exit 2), and after a
  failed example build a second `make` fails again instead of reporting nothing to do.
- Variables were added on 2026-11-19: `sys ... as name` keeps the return value, and a name can be
  passed as an argument. Six variables, one register each (`rbx rbp r12 r13 r14 r15`), never freed.
  Tests cover every pool register, 64-bit values (an `mmap` pointer) and every rejection.
- A label named `word` broke the compiler: in Intel syntax `jbe word` is read as a size keyword,
  assembles silently and jumps elsewhere, so every source with a name segfaulted `ailc`.
- Negative numbers and hex are not parsed. A value such as -1 (needed for `mmap`'s fd) cannot be
  written yet, and `mov r32, imm32` would zero-extend it wrongly anyway.

## Why
- **`sys` as the only statement:** it is the smallest thing that is both hardware-oriented and enough
  to print. No runtime or library is needed.
- **String literal expands to address and length:** the writer never counts bytes, which saves tokens
  and removes a class of off-by-one errors.
- **Implicit `exit(0)` and no `main`:** boilerplate that carries no information is left out.
- **Compiler emits ELF itself:** the output path has no assembler or linker, so a self-hosted
  compiler will not need them either. Only building stage0 needs `as` and `ld`.
- **Variables are registers, with no spilling:** the generated code needs no stack or writable
  memory, and passing or capturing a value is one 3-byte `mov`. The pool is the registers that the
  `syscall` instruction and the argument positions leave alone; `rsp` is kept for a future stack.
- **`as name` after the arguments:** it reads left to right in execution order and adds two tokens.
  A name is defined only when its `as` is reached, so it cannot be used earlier on the same line.
- **Names are stored as pointers into the input buffer:** no copying and no name-length limit.
- **Separate `undefined variable` and `too many variables` messages:** with no line numbers, the
  message is all an AI has to repair the program.
- **A name must follow a blank:** otherwise `12x` would turn from a syntax error into the number 12
  and a variable `x`.
- **Strings inlined behind a `jmp`:** the address is known at the moment the string is read, which
  keeps the compiler single-pass with no fixups. The cost is 5 bytes per string and read-only data.
- **Fixed load address `0x400000`, non-PIE:** absolute addresses fit in a 32-bit immediate.
- **Input buffer is the limit plus one byte:** a full buffer then means "too big" with no extra read,
  and a source of exactly the limit still reaches EOF normally.
- **Exit 1 for source errors, 2 for I/O errors:** a caller can tell "fix the program" from "fix the
  environment" without parsing the message.
- **Makefile builds examples into `<target>.tmp` and renames:** the shell creates the redirect target
  before the compiler runs, so writing to the real target leaves a fresh-looking file on failure.

## How to apply
- Keep new syntax to short common words separated by spaces; let the compiler derive what it can.
- Labels, functions or forward jumps need a fixup list or a second pass. Decide that before adding
  control flow.
- Writable data needs a second `PT_LOAD` segment or an RWX one. The current header has a single R+X
  segment.
- 64-bit or negative immediates need a `mov r64, imm64` (or sign-extended) path in `emit_mov`.

## Open items
- 2026-11-19: token cost has not been measured with a real tokenizer; the syntax follows a rule of
  thumb only.
- 2026-11-19: self-hosting is not started; the language lacks memory access, arithmetic, control
  flow and functions. A variable can only be set by `as`; assignment comes with arithmetic.
- 2026-11-19: six variables will not be enough for a compiler; that needs spilling or scoped reuse
  of registers once functions exist.
- 2026-11-19: errors carry no line number.
- 2026-11-19: I/O error paths and the Makefile failed-build case have no automated test.

## Related
- [Open items](../status/open-items.md)

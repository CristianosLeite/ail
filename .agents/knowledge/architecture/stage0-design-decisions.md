---
title: Stage0 design decisions
last-verified: 2026-11-19
sources: [commit 787fe7e, conversation 2026-11-19]
status: current
---
# Stage0 design decisions

**Summary.** Why the bootstrap compiler (`stage0/ailc.s`) and the first syntax look the way they do,
what was verified, and what the choices cost later. `AGENTS.md` describes the structure; this page
records the reasoning.

## Facts
- Hello world is `sys 1 1 "hello world\n"` and compiles to a 168-byte static ELF64 (120 bytes of
  headers, 48 of code and string).
- Verified by hand on 2026-11-19: escapes `\t \" \\ \n`, trailing and full-line `#` comments, several
  statements in one file, explicit `sys 60 7` giving exit status 7, and exit status 1 for an unknown
  keyword and for an unterminated string. Only hello world is an automated test (`tests/hello.ai`);
  the rest of this list has no test yet.
- The test runner (`tests/run.sh`) compares stdout and requires exit status 0. It cannot express a
  test that expects a compile error or a non-zero exit status, so the two error paths and the
  `sys 60 7` case above cannot be added as tests until it is extended.
- `sys1 1 "x"` (no space after the keyword) is accepted, because the keyword check does not require
  a delimiter. This is unintentional.
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
- **Strings inlined behind a `jmp`:** the address is known at the moment the string is read, which
  keeps the compiler single-pass with no fixups. The cost is 5 bytes per string and read-only data.
- **Fixed load address `0x400000`, non-PIE:** absolute addresses fit in a 32-bit immediate.

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
- 2026-11-19: self-hosting is not started; the language lacks variables, memory access, arithmetic,
  control flow and functions.
- 2026-11-19: errors carry no line number.
- 2026-11-19: the hand-verified behaviours above are not automated; the runner needs expected exit
  status and expected compile failure first.

## Related
- [Open items](../status/open-items.md)

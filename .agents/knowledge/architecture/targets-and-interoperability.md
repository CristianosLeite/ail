---
title: Targets and interoperability
last-verified: 2026-11-20
sources: [conversation 2026-11-20, docs/BACKLOG.md, stage0/ailc.s, compiler/ailc.aw, compiler/tables.aw]
status: current
---
# Targets and interoperability

**Summary.** Evaluated on 2026-11-20 for the backlog: a second target architecture, linkable
object files, a platform calling convention and dynamic linking. None is implemented. AIL stays a
compiler for x86-64 Linux that writes a complete executable, and this page says what each
extension would take and what would justify it.

## Facts
- The compilers are about 3600 lines of assembly (stage0) and 2900 lines of AIL (stage1 with its
  tables). The target is in every layer of them, not behind an interface:
  - the 117 statement rows are instruction bytes, written once as assembly and once as numbers;
  - `regtab`, `argnum`, `varnum`, the pushes and pops, the probe and the `alloc` and `free`
    rows name x86 registers and Linux syscall numbers;
  - `emit_mov`, `emit_mov_rr`, `emit_mem` and `emit_lea` build ModRM, SIB and REX bytes;
  - the fixups assume a 4-byte field that takes a distance from its own end;
  - the syscall names are the x86-64 numbers.
- The output is `ET_DYN` with two `PT_LOAD` headers: no sections, no symbols, no relocations,
  no interpreter.
- AIL's calling convention passes values in `rax`, `rdi`, `rsi`, `rdx`, `r10`, `r8` and results
  in the same registers; the callee saves the variable registers it uses (`rbx`, `rbp`,
  `r12`-`r15`). The System V convention passes in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`, returns
  in `rax` and `rdx`, saves the same six registers and wants the stack aligned to 16 bytes at a
  call, which AIL does not keep.

## Why
- **No second target now.** An aarch64 backend is not a table: instructions have a fixed width,
  a 64-bit constant takes up to four of them, an address a pair with its own two fixup kinds,
  and a branch reaches 128 MiB. It would be a second code generator in each compiler, and
  stage0, the seed, is itself x86 assembly. No program asks for it. If one does, the way in is
  through stage1 alone: a backend chosen at start, cross-compiling from x86, with stage0 left
  as the x86 seed.
- **No object files now.** Writing `ET_REL` needs section headers, a symbol table, a string
  table and relocation records, and syntax to import and export names. It would also bring back
  what the design removed on purpose: a linker between the source and the program. `use` already
  joins AIL sources, so objects would only serve to meet other languages.
- **No platform ABI now.** A statement that places values for the System V convention and
  aligns the stack is small, but there is nothing to call without object files or dynamic
  linking, and a function to be called from C would need the reverse wrapper. It follows the
  decision on objects.
- **No dynamic linking.** It needs an interpreter path, a dynamic section, relocations applied
  by the loader and the C library's start-up contract. Every system facility a program needs is
  reachable through `sys`, and the io library shows that helpers can be written in AIL.

## How to apply
- Do not add target conditionals to the compilers. If a second target is ever wanted, start by
  separating what `emit_*` and the tables assume, in stage1 only.
- Keep AIL's convention internal: nothing outside a program depends on it, so it can change, as
  it did for stack values and several results.
- Reopen object files when a concrete program must call, or be called by, code in another
  language; the platform ABI goes with that, not before.
- Symbols for debuggers are a separate, smaller question; see the item on error locations.

## Open items
- 2026-11-20: none. The backlog item is closed with this decision.

## Related
- [Language extensions](language-extensions.md)
- [Stage0 design decisions](stage0-design-decisions.md)
- [Open items](../status/open-items.md)

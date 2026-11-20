---
title: Stage0 design decisions
last-verified: 2026-11-19
sources: [commit 787fe7e, code reviews 2026-11-19, conversations 2026-11-19, TODO.md control flow and functions items 2026-11-19, stage0/ailc.s]
status: current
---
# Stage0 design decisions

**Summary.** Why the bootstrap compiler (`stage0/ailc.s`) and the first syntax look the way they do,
what was verified, and what the choices cost later. `AGENTS.md` describes the structure; this page
records the reasoning.

## Facts
- Hello world is `sys 1 1 "hello world\n"` and compiles to a 224-byte static ELF64 (176 bytes of
  headers, 48 of code and string).
- Covered by tests since 2026-11-19: escapes, comments, several statements, explicit exit status,
  six arguments, every syntax-error cause, and the 65536-byte source limit on both sides.
- A code review on 2026-11-19 found four defects, all fixed: `sys` with no number or with a string
  as the number compiled; a source of exactly 64 KiB was rejected; I/O failures were reported as
  syntax errors; and a failed example build left an empty executable that Make treated as current.
  `sys1 1 "x"` (no blank after the keyword) was also accepted and is now rejected.
- The runner cannot express these: `build/ailc <&-` gives `ailc: read error`, output to
  `/dev/full` gives `ailc: write error` (both exit 2), and after a failed example build a second
  `make` fails again instead of reporting nothing to do. The first two are checked by
  `tests/io.sh` since 2026-11-19, the last by hand only.
- A review on 2026-11-19 found that the comment scanner looked only for LF, so
  `# note<CR>sys 60 7` compiled and the comment swallowed the statement, although a bare CR is
  an error everywhere else outside a string. The scanner now calls `crlf` on every CR. Six tests
  cover it (220 in all); the three rejections fail against the previous compiler.
- A review on 2026-11-19 found that output to a pipe whose reader had gone killed the compiler
  with `SIGPIPE`: no message, status 141. `_start` now sets `SIGPIPE` to `SIG_IGN`, so `write`
  returns `-EPIPE` and takes the ordinary `write error` path. `tests/io.sh` covers it.
- Variables were added on 2026-11-19: `sys ... as name` keeps the return value, and a name can be
  passed as an argument. Six variables, one register each (`rbx rbp r12 r13 r14 r15`), never freed.
  Tests cover every pool register, 64-bit values (an `mmap` pointer) and every rejection.
- Assignment, arithmetic and memory access were added on 2026-11-19: `set` and ten arithmetic
  statements, `buf name size`, `load`/`loadb`/`store`/`storeb`. The header grew from 120 to 176
  bytes for a second, read-write `PT_LOAD` at `0x10000000` with no file bytes.
- Linux (checked on 7.0) loads a `PT_LOAD` whose memory size is zero, so programs without `buf`
  keep the same two-segment header and nothing patches `e_phnum`.
- A literal above 4294967295 still wraps silently, so `div x 4294967296` divides by zero.
- A review of the memory access work on 2026-11-19 found two defects, both fixed. `store "A"`,
  `storeb "A"` and `add "A" as x` compiled, because a string expands to two values and so
  satisfied the two-operand count; the stores then died with SIGSEGV. `str` now rejects a string
  unless the statement is `sys`. And the `loadb` test passed 0xff straight to `exit`, which looks
  the same zero- or sign-extended; it now shifts right by 8 and expects 0.
- Checked by hand in that review: an unaligned 64-bit store and load across a page boundary work,
  and the buffer total can reach the exact segment limit (one more byte is rejected after
  rounding).
- A label named `word` broke the compiler: in Intel syntax `jbe word` is read as a size keyword,
  assembles silently and jumps elsewhere, so every source with a name segfaulted `ailc`.
- Negative numbers and hex are not parsed. A value such as -1 (needed for `mmap`'s fd) cannot be
  written yet, and `mov r32, imm32` would zero-extend it wrongly anyway.
- Control flow was added on 2026-11-19: `label name`, `jmp name`, `jz a name`, `jnz a name`. Jumps
  are `optab` rows flagged `IS_JMP` whose bytes stop before the `rel32`; `ident` takes the name
  after the operands as the label. New error `ailc: undefined label`; a second `label` with the
  same name is `duplicate name`. 31 tests cover both directions, taken and untaken branches, a
  comparison-driven loop, a value with only bit 32 set, and every rejection.
- A variable read on a path that jumped over its `as` holds an unspecified value: definition is by
  line order, and the compiler does no flow analysis.

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
- **One separator rule for every token (2026-11-19):** space or tab between tokens, LF or CRLF at
  the end of a line, `#` for a comment, nothing else. Before, any byte up to ASCII space separated
  numbers and strings, so a NUL invisible in an editor compiled, and tokens could touch (`1"x"`).
  Every token now ends in `tokend`, which also keeps `12x` a syntax error instead of the number 12
  and a variable `x`. This broke sources relying on the old separators, accepted while the
  language is small. New statements must end their tokens through `tokend` too.
- **New statements are `keyword operands as name` (chosen by the user, 2026-11-19):** the same
  shape as `sys`, so operands reuse the argument parser and land in `rax` and `rdi`, and a
  statement is one row of instruction bytes in `optab`. Rejected: two-address in-place forms
  (`add x 1`), which give two ways to define a variable, and infix `x = a + b`, which adds
  punctuation and a second parser path.
- **Buffers are named compile-time addresses, not variables (chosen by the user):** `buf` costs
  none of the six registers. The alternative was one fixed region carved up by hand.
- **Byte and 64-bit accesses only (chosen by the user):** enough to write a compiler; 16- and
  32-bit accesses wait for a demonstrated need.
- **Writable segment at a fixed address:** the address of a buffer must be known when it is used,
  before the code size is known, so it cannot follow the code.
- **`duplicate name` and `too many buffers` are separate messages:** same reason as for variables.
- **Comparisons produce a value, not flags (2026-11-19):** `eq ne lt le gt ge` are `optab` rows that
  emit `cmp` / `setcc al` / `movzx eax, al`, so they needed no fixups and could land before control
  flow; a conditional jump can later test the variable. Ordering is unsigned to match `div`, `mod`
  and `shr`; there is no signed comparison. This replaces the earlier choice to leave comparison
  out until control flow was designed.
- **Every jump is resolved in `fin` from the fixup list `fixs` (2026-11-19):** backward jumps could
  be resolved at once, but one path for both directions is less code. The cost is a linear label
  search per jump, which the 64 KiB source limit keeps small.
- **Label and fixup tables are sized from the source limit:** `INSZ/8 + 1` labels (`label a\n` is 8
  bytes) and `INSZ/6 + 1` jumps (`jmp a\n` is 6), so neither can overflow and there is no
  "too many labels" error to document or test. Raising `INSZ` grows them with it.
- **Labels are a separate name space:** a label is never a value, so sharing names with variables
  and buffers is unambiguous, and `as` is allowed as a label name because the label position
  cannot hold `as name`.
- **`jz`/`jnz` test a value, not flags:** they pair with the value-producing comparisons and need
  no state between statements; the cost is a redundant `test rax, rax` after a comparison.
- **Strings inlined behind a `jmp`:** the address is known at the moment the string is read, which
  keeps the compiler single-pass with no fixups. The cost is 5 bytes per string and read-only data.
- **Fixed load address `0x400000`, non-PIE:** absolute addresses fit in a 32-bit immediate.
- **Input buffer is the limit plus one byte:** a full buffer then means "too big" with no extra read,
  and a source of exactly the limit still reaches EOF normally.
- **Exit 1 for source errors, 2 for I/O errors:** a caller can tell "fix the program" from "fix the
  environment" without parsing the message.
- **Makefile builds examples into a temporary file and renames:** the shell creates the redirect
  target before the compiler runs, so writing to the real target leaves a fresh-looking file on
  failure. The file comes from `mktemp <target>.tmp.XXXXXX` and a trap removes it: with the fixed
  name `<target>.tmp` used until 2026-11-19, sixteen of twenty simultaneous rebuilds of one
  example failed (`mv: cannot stat`). `mktemp` creates mode 600, so the recipe sets 755 itself.

## How to apply
- Keep new syntax to short common words separated by spaces; let the compiler derive what it can.
- A forward reference to code goes through a fixup list: `fixs` for jumps, resolved per scope,
  and `calls` for `call rel32`, resolved in `fin` (see [Stage0 functions](stage0-functions.md)).
  A table sized from the source limit needs the shortest line that fills it.
- A statement that ends in a name which is not a value (as the jumps do) is an `optab` row with
  its own flag, checked in `ident` and at the end-of-statement path in `arg`.
- A new statement that maps to "operands in `rax`/`rdi`, result in `rax`" is a row in `optab`.
- The operand count in `optab` counts values, not tokens, and says nothing about their kind. A
  restriction on what an operand may be needs its own check where that token is parsed, as `str`
  does with `IS_SYS`.
- An exit status shows only the low 8 bits of a value. A test of width or extension must move the
  interesting bits down first, and is only proven when the wrong instruction, patched into a
  scratch copy of the compiler, makes it fail.
- Initialised writable data would need file bytes in the second segment; today it is zero-filled
  only and strings stay read-only.
- 64-bit or negative immediates need a `mov r64, imm64` (or sign-extended) path in `emit_mov`.

## Open items
- 2026-11-19: token cost has not been measured with a real tokenizer; the syntax follows a rule of
  thumb only.
- 2026-11-19: self-hosting is done, see [Stage1 self-hosting](stage1-self-hosting.md); six variables per function were enough for it.
- 2026-11-19: errors carry no line number.
- 2026-11-19: the Makefile failed-build case has no automated test.

## Related
- [Stage1 self-hosting](stage1-self-hosting.md)
- [Stage0 functions](stage0-functions.md)
- [Stage0 test suite](../testing/stage0-test-suite.md)
- [Open items](../status/open-items.md)

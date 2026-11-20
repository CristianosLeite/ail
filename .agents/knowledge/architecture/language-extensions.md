---
title: Language extensions
last-verified: 2026-11-19
sources: [conversation 2026-11-19, TODO.md, stage0/ailc.s, stage1/ailc.ai]
status: current
---
# Language extensions

**Summary.** Decisions taken while implementing the backlog in `TODO.md`, one commit per item, in
both compilers. Each section says what was chosen, why, and what to keep in mind when touching it.

## Facts

### Read-only data and strings as values (2026-11-19)
- `data [name] item...` puts bytes in the code stream behind a `jmp`, like a string literal. An
  item is a string or a byte value 0 to 255. Consecutive `data` statements share one `jmp` and are
  contiguous; the name is optional.
- A string literal is accepted in every statement: two values (address, length) in `sys` and
  `call`, the length in `len`, the address elsewhere. `\xHH` is a new escape.
- `len x as n` gives the length of a buffer (as declared), of a data name (its own statement only)
  or of a string.
- Buffers and data names share one table, sized from the source limit; the limit of 16 counts
  buffers only (`nrbufs`) until the backlog lifts it.
- Stage1 keeps its tables as `data` under the names of stage0; its special-statement flag moved
  from 64 to 128 because 64 is now `IS_LEN`.
- The suite went from 220 to 258 tests. `tests/run.sh` now discards the stderr of the shell that
  runs a program, because `data_is_read_only` dies of `SIGSEGV` and the shell reported it.

### Global scalars, constants and no buffer limit (2026-11-19)
- `var a b c` declares global 64-bit cells: read as a value, written by `as`, seen by every
  function. `const name number` names a number, also accepted as the `sys` number and as a `buf`
  size. Both must be declared before use.
- The limit of 16 buffers is gone; `too many buffers` became `buffers too big`, since only the
  size cap is left. The table of global names holds 32769 entries (one per two source bytes).
- Var cells grow downward from `0x10000000`; the writable segment starts whole pages lower.
- Stage1 keeps all its state in vars: the one-cell buffers, the packed buffer `st` and its
  accessors `g` and `s` are gone. A peephole pass folded 25 `set` lines into their users; about
  130 `set <var> as <local>` copies remain and are correct but not needed.
- The suite went from 258 to 308 tests.

### Forward references to buffers and data (2026-11-19)
- A name that is neither a variable of its scope nor a global declared earlier is recorded in
  `refs` with a zero `imm32`; `fin` fills in the address or the length. `undefined variable` is
  therefore reported at the end of the source, after any other error.
- A var or a const must still be declared before its uses: they change which instruction is
  emitted, not only a value.
- Inside a function a parameter or variable may have the name of a buffer, data or const and
  hides it from its definition on. At top level a name still means one thing.
- `jz_undefined_variable` (`label a` / `jz a`) is now a syntax error: the name is accepted as a
  value and the label is missing. Stage1 keeps its tables at the end of the source.
- The suite went from 308 to 329 tests.

### 64-bit, negative and hexadecimal literals (2026-11-19)
- `rdnum` reads every integer of the language: decimal up to 2^64-1, `0x` with up to sixteen
  digits, either after `-` down to -2^63. Out of range is `number too big`; the silent wrap at 32
  bits is gone. `sys`, `const`, `buf` sizes and `data` bytes all go through it.
- `emit_mov` chooses among 5/6, 7 and 10 bytes. `num_shortest_encoding` pins the three sizes by
  the distance between data bytes.
- `buf_size_over_32bit` became `buf_size_over_64bit` with the new message.
- The suite went from 329 to 365 tests.

### 16- and 32-bit loads and stores (2026-11-19)
- Four rows of `optab`: `load2`, `load4`, `store2`, `store4`. Loads zero-extend.
- Stage1 appends and patches displacements with `store4`; `p4` is gone and `e4` is two lines.
- The suite went from 365 to 376 tests.

## Why
- **A digit suffix, the size in bytes:** `load4` is two tokens like `loadb`; a letter (`loadd`,
  `loadw`) tokenizes worse (`lo` + `add`) and its meaning depends on the reader's assembler.
- **`0x` prefix:** `0xffffffff` is two tokens where `4294967295` is four (see
  [Token cost measurement](token-cost-measurement.md)).
- **An error instead of wrapping:** a literal that silently becomes another number is the kind of
  fault an AI cannot see in its own output.
- **Hide instead of refusing in functions:** with declarations allowed after uses, a function
  compiled before a later `buf` cannot know the name is taken, so refusing would depend on the
  order of the source. Hiding is the same whatever the order.
- **A fixup with a fixed-size `mov`:** a second pass over the source would have to parse strings
  and comments to find the declarations; the fixup list reuses what jumps and calls already do.
- **Cells below the buffers:** a var is read with an absolute 32-bit displacement, which the
  processor sign-extends, so its address must stay below 2 GiB whatever the buffers take. Growing
  downward needs no count in advance and leaves programs without vars byte-identical.
- **`as` writes a var instead of shadowing it:** shared state is the purpose; a local that hid
  it silently would be the worse surprise. A parameter with the name of a var is an error.
- **`const` accepted as the syscall number:** it makes `sys write 1 "x"` possible without a
  built-in table of names.
- **`sys` with a name that is not a const stays a syntax error:** it kept the existing tests,
  and "undefined variable" would be wrong for a name that is a variable.
- **Inline behind a jump, not a data section:** the address is known at once, the output layout
  does not change and existing programs compile to the same bytes.
- **Contiguous runs with an optional name:** a table of several hundred bytes on one line cannot
  be maintained, and a jump between rows would break indexing. Merging only when the output cursor
  has not moved needs two cells of state and no lookahead.
- **A data name is one value, a literal two in `sys` and `call`:** a name is mostly a table
  address; the literal keeps the token saving of `sys 1 1 "text"` and extends it to
  `call print "text"`.
- **`len` instead of a second implicit name:** one statement, and it also removes the repeated
  size constant of a buffer.
- **`\x` used to mean the letter x:** accepted as a change of behaviour; no test or example used it.

## How to apply
- A statement that defines no code must clear `dataend` if a later jump can land on it, as `label`
  does; otherwise data after it is merged into the block before it.
- A new kind of global name goes into `bufs`/`bufaddr`/`bufsize`/`bufkind` through `newglob`
  (stage1: an entry of `globs`).
- In stage1, never use the name of a var for a local: `as` would write the global.
- Anything that saves and restores the compiler state for a scope must include `nrefs`.
- When a row of `optab` changes, change the matching `data` line of stage1.

## Open items
- 2026-11-19: `data` items are bytes only; wider values wait for hex and 64-bit literals.

## Related
- [Stage0 design decisions](stage0-design-decisions.md)
- [Stage1 self-hosting](stage1-self-hosting.md)
- [Token cost measurement](token-cost-measurement.md)
- [Open items](../status/open-items.md)

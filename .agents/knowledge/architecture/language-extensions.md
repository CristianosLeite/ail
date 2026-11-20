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

## Why
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
- A new kind of global name goes into `bufs`/`bufaddr`/`bufsize` (stage1: `globs`).
- When a row of `optab` changes, change the matching `data` line of stage1.

## Open items
- 2026-11-19: `data` items are bytes only; wider values wait for hex and 64-bit literals.

## Related
- [Stage0 design decisions](stage0-design-decisions.md)
- [Stage1 self-hosting](stage1-self-hosting.md)
- [Token cost measurement](token-cost-measurement.md)
- [Open items](../status/open-items.md)

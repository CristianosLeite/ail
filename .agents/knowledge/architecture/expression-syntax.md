---
title: Expression syntax
last-verified: 2026-11-20
sources: [conversation 2026-11-20, docs/REDESIGN.md, docs/tokens.md]
status: current
---
# Expression syntax

**Summary.** Infix expressions are written without spaces (`x=(x^x>>13)*1664525+1013904223`),
spaces keep separating arguments, and assignment is `x=e` or `x+=e`. Chosen by counting the
ten-program corpus in eight spellings: 975 tokens against 1313 before, 1118 for C, 1191 for Rust.

## Facts
- Counted on 2026-11-20 with `o200k_base`: statements 1313; spaced operators with commas 1104,
  without commas 1092; touching operators 1024; touching with `x=e` 988; with `x+=e` too 975.
- A space before a number or an operator is a token of its own, and touching characters merge
  (`=(`, `)*`, `<n`); that is the whole difference between 1104 and 988.
- Precedence is Rust's: `* / %`, `+ -`, `<< >>`, `&`, `^`, `|`, comparisons last. All
  left-associative, comparisons unsigned with result 1 or 0.
- Not in expressions: strings (whole argument only), loads, calls, signed, float and atomic
  operations. `v=[p-8]` costs the same 6 tokens as `load p-8 as v`.

- Code for expressions (2026-11-20): the compiler keeps the evaluation stack itself, values wait
  as numbers, variables or registers, and the statements that say the same as an expression
  (`add a b as x`, `jlt a b l`, loads and stores) go the same way and give the same bytes.
  Final figures: corpus 970 tokens, 990 since it is indented (C 1118, Rust 1191), time 1.039 times `gcc -O3` in the
  geometric mean, compiler source 21% fewer tokens after `tools/infix.py` (now `tools/infix.aw`).
- Faults that only random programs or rewriting the examples found: the register of an
  assignment's target handed out again as a scratch register; the address of a store left in
  `rax` while its value divided. Both have a case in `tests/insn.cases` now.

## Why
- **This reverses a recorded decision.** Infix was rejected on 2026-11-19 as adding punctuation
  and a second parser path, and `docs/tokens.md` found a loop statement not worth it (31
  loop-shaped labels against 152 if-shaped). `docs/REDESIGN.md` (2026-11-20, the user's document)
  asks for expressions and `while`; the count then showed 26% fewer tokens on programs that
  compute, which the earlier measurement, taken on the compiler source, did not have.
- **No spaces instead of the commas of the sketch in `docs/REDESIGN.md`:** the document left
  argument boundaries to be settled by counting. Without spaces in an expression the old rule
  "spaces separate arguments" needs no change, `a -1` and `a-1` cannot be confused, and it is
  116 tokens cheaper than the comma form. The cost is one strict rule to know: `a + b` is three
  arguments, not a sum.
- **One spelling only:** accepting both spaced and touching forms would need the comma back.

## How to apply
- Write `x=a+b`, never `x = a + b`. An argument with a space in it is two arguments.
- Use `x+=e` when a variable is changed in place; it is a token cheaper and names the target
  once.
- Before adding an operator or a form to expressions, count it on the corpus as here; the
  candidates were derived mechanically from one hand-written version, so the comparison is of
  spelling only.

## Related
- [Token cost measurement](token-cost-measurement.md)
- [Stage0 design decisions](stage0-design-decisions.md)
- [Seed bootstrap](seed-bootstrap.md)

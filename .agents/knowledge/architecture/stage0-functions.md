---
title: Stage0 functions
last-verified: 2026-11-19
sources: [docs/TODO.md functions item 2026-11-19, functions review 2026-11-19 (REVIEW.md), conversation 2026-11-19, stage0/ailc.s, tests/fn_*, tests/call_*, tests/buf_*fn*]
status: current
---

> **2026-11-20:** stage0 (`stage0/ailc.s`) was removed; the compiler is `compiler/ailc.ai` alone, built from a seed ([Seed bootstrap](seed-bootstrap.md)). This page is kept for the reasons it records; routine names in it are those of stage0, and `docs/compiler.md` gives today's.
# Stage0 functions

**Summary.** Why `fn` / `end` / `call` / `ret` in `stage0/ailc.s` work the way they do, what was
checked, and what the choices cost. `AGENTS.md` and `docs/compiler.md` describe the mechanism;
this page records the reasoning.

## Facts
- Added on 2026-11-19: `fn name a b` ... `end`, `call name x y [as r]`, `ret value`. Up to six
  parameters, six variables per function with the parameters counted, labels local to a function,
  recursion and forward calls. New errors `ailc: undefined function` and
  `ailc: wrong argument count`.
- Values travel in argument positions 0-5 (`rax rdi rsi rdx r10 r8`), the result in `rax`. The
  callee pushes all six variable registers at entry and pops them at every `ret` and at `end`:
  21 bytes of code per function and per `ret`, 56 bytes of stack per call.
- `examples/fact.ai` compiles to 319 bytes and exits with 120.
- 66 tests were added with the feature and 4 after its review (214 in all). Mutations tried on a scratch copy of the compiler, each failing
  at least one new test: not saving `r13`; skipping the last entry of `calls`; not cutting
  `nlabels` or `nfix` back at `end`; no arity comparison; no `xor eax, eax` at `end`; not
  restoring the top-level variable count; wrapping the `calls` index at 4096; wrapping the
  function index at 512.
- Checked by hand after the change: `build/ailc <&-` and output to `/dev/full` still exit 2.
- `call_table_full` is exactly 65536 bytes (`fn a`, `end`, 9361 calls); `call_fills_source` runs
  9343 calls and counts them in a buffer; `fn_many` calls 1000 functions, half before their
  definitions.
- A review on 2026-11-19 found that `buf b 8` inside a function was accepted when the top level
  already had a variable `b`: `bufdef` searched only the open function's variables, and the
  top-level `b` then hid the buffer or was refused by its next `as`. `bufdef` now also searches
  the top-level variables (`lookup_topvar`). Tests: `buf_in_fn_name_is_top_variable`,
  `buf_in_fn_name_is_fn_variable`, and `buf_after_fn_variable` for the case that stays legal.
- The same review confirmed by hand that a parameter may share the name of a top-level variable,
  and that a jump to a function's last label reaches the default zero return while a top-level
  jump recorded before the function still resolves.
- The function table cannot be filled by a test: 7282 functions would need distinct names, which
  no longer fit in 64 KiB at 9 bytes each.

## Why
- **The callee saves all six registers, always:** the entry code is emitted before the body is
  read, so the number of variables is unknown there, and patching the entry afterwards would be a
  second kind of fixup. The caller then emits only `call rel32`, and top-level callers, nested
  calls and recursion are all covered by one rule. The cost is ten pushes and pops per call.
- **Arguments start at position 0 (`rax`):** the argument parser already fills positions in that
  order, so `call` needed no change to it. `r9`, the seventh position, is unused by calls.
- **One saved scope, no nesting:** `fn` stores the top-level variable count and the ends of
  `labels` and `fixs`; `end` resolves the function's jumps and cuts both tables back. Labels and
  jumps of a function are a stack on top of the top-level ones, which is what makes them local
  without a scope field per entry.
- **Calls have their own list, `calls`, not `fixs`:** jump fixups are dropped at `end`, while a
  call may name a function defined later and must survive until `fin`. One mixed list would have
  needed compaction at every `end`. The mechanism (an empty `rel32` and a table entry) is the same.
- **Arity is checked in `fin`, not at the call:** a forward call is read before its function.
- **Top-level variables are invisible inside a function:** every function owns the whole register
  pool; sharing would cost registers or need globals in memory. Buffers are compile-time
  addresses and stay global, including a `buf` written inside a function.
- **`ret` takes exactly one value; `end` returns 0:** as worded in the TODO item. A bare `ret` is
  a syntax error.
- **`ret` outside a function, `end` without `fn`, nested `fn` and a missing `end` are plain syntax
  errors:** they are mistakes of structure, and two new messages were already added for the
  mistakes an AI can only repair by knowing which name is at fault.
- **Function names are a separate name space, and `as` is allowed:** the name position of `fn` and
  `call` can hold nothing else, as with labels.

## How to apply
- A name check for something global (a buffer) must look at every scope that can still see it,
  not only the current one; a check for something local needs only the current scope.
- Code added to `emit_op` must keep `r8`: `capture` holds the variable register there across the
  call. `lookup` destroys `rax rcx rdx r10 r11 r12`.
- A statement whose name comes before its operands (as `call`) is read in `next`, after the
  keyword's blank, and then continues through `tokend`.
- Anything that needs to know a function's size or variable count at its entry needs a patch at
  `end`; today only the skip jump is patched there.
- A mutation that changes a loop counter must guard the empty case, or it breaks every test and
  proves nothing: `dec ebp` before the `calls` loop underflowed when there were no calls.
- More than six variables per function would need spilling to the stack; the frame is fixed at the
  six saved registers today and `rsp` is otherwise untouched.

## Open items
- 2026-11-19: six variables per function may not be enough for a compiler written in AIL.
- 2026-11-19: nothing checks that the stack does not overflow on deep recursion.

## Related
- [Stage0 design decisions](stage0-design-decisions.md)
- [Stage0 test suite](../testing/stage0-test-suite.md)
- [Open items](../status/open-items.md)

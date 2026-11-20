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

### 64 variables per scope, register reuse and stack slots (2026-11-19)
- A scope has 64 variables. Top level: six registers, then one memory cell each, no reuse.
  Functions: compiled twice; the first pass measures each variable's range and the loops, `alloc`
  then reuses a register once its variable is done and spills the rest to `[rsp + 8k]`.
- Existing functions keep their size but may use fewer registers: `fact` now keeps `r` in the
  register of `m`. A function without slots has no frame code (`fn_small_code_size`).
- A seventh parameter is still `too many variables`; stack arguments are the next item.
- Verified beyond the suite with a scratch generator: 671 random programs with up to 40 live
  variables, nested loops and skipped blocks gave the exit status computed in Python with stage0,
  517 with stage1, and 400 sources compiled to the same bytes by both.
- The suite went from 376 to 396 tests.

### More than six parameters (2026-11-19)
- A call loads each value after the sixth into `r11` and pushes it; the caller removes them with
  `add rsp` after the call. The callee copies them from above its frame into ordinary variables.
- The limit is the 64 variables of the callee. `sys` keeps the kernel's six arguments.
- While values are being pushed, the caller's stack slots are further from `rsp`: `pushed` is
  added to every slot distance (`call_stack_values_from_stack_variables`).
- A forward name passed on the stack is patched through `immpos`, not "four bytes back".
- The suite went from 396 to 407 tests.

### Reads on a path that skipped the assignment (2026-11-19)
- `unassigned variable`: a 64-bit mask of definitely assigned variables is carried through the
  single pass. Jumps record it, labels intersect the recorded masks, a backward jump must carry
  at least the mask of its label, and code after `jmp` or `ret` is unreachable until a label.
- A label only reached from below (loop entered at its test) starts from the mask before the
  `jmp` above it. Without that rule the common bottom-test loop was rejected.
- No existing test, example or line of stage1 tripped the check.
- The suite went from 407 to 434 tests.

### Accesses proven invalid at compile time (2026-11-19)
- `invalid access`: a load or store through a buffer or data name, a string, or a variable
  computed from one by `set`, `add` and `sub` with numbers, is checked against the object: the
  declared size of a buffer, the run of a data name, the length of a string; data and strings
  take no store. Knowledge is dropped at labels and at the end of a function.
- Checks through names are recorded and done in `fin`, since a name may be declared later and a
  run may grow. Strings are checked at once.
- `buf_two_distinct` stored 8 bytes into `buf a 3` and was the one existing program rejected; it
  now writes three bytes. `data_is_read_only` stores through a parameter to stay a run-time test.
- Stage1 marked its self-parsed statements with flag 128, which is now `IS_MEM`; they use 255.
- The suite went from 434 to 467 tests.

### Allocation, release and local storage (2026-11-19)
- `alloc n as p` and `free p` are two rows of `optab` whose code is written as instructions in
  stage0 and as bytes in stage1: `mmap` of the size plus a 16-byte header that keeps the length,
  0 on failure or when the size would wrap; `munmap` through the header, nothing for 0.
- `local name size` reserves bytes in the frame of the function. The name is a variable of the
  function with no place of its own; reading it is `lea`. Not zero-filled.
- `buf name 0` is allowed (a mark; any access through it is `invalid access`); alignment is not
  configurable: 8 for `buf` and `local`, 16 for `alloc`.
- A mutation that survived exposed a real fault: `clrloc` ran before `alloc`, so a local always
  took a register or slot as well. `local_takes_no_register` now pins the frame size through the
  distance between the locals of two nested calls.
- The suite went from 467 to 504 tests.

### Checked addresses; no borrow checking (2026-11-19)
- Evaluated: run-time bounds checks, lifetime and alias tracking for allocations, and borrow
  checking. Decided: add `at name offset count as p`, a run-time checked form of `add`, and
  nothing else.
- `at` traps with `ud2` (`SIGILL`) unless `offset + count` fits the object, which must be a
  buffer, a data name (to the end of its run) or a local: the objects whose size the compiler
  knows. It is one table row; its first value is passed as address and size.
- The row format gained a second flag byte, since all eight flags were in use; stage1's rows
  have one more number each.
- The suite went from 504 to 534 tests.

## Why
- **No borrow or ownership checking:** an address is an integer that can be stored in memory,
  computed and handed to a syscall. Tracking it needs types for values and for memory, which is
  the opposite of a language whose statements are machine operations. It would also cost tokens
  in every signature.
- **No lifetime tracking for `alloc`:** the same reason, and the failure mode is already
  defined: `free` unmaps, so a later use faults.
- **No checked `load` and `store`:** they would need the bounds as extra values at every access.
  `at` puts the check where the address is made and keeps the access statements as they are.
- **Only names as the object of `at`:** an address in a variable has no size. A checked form for
  `alloc` blocks could read the length header, but cannot tell such a block from any other
  address.
- **`ud2`, not a message:** two bytes, no runtime, and a status (132) that differs from the
  `SIGSEGV` of an unchecked fault.
- **One mapping per `alloc`:** no allocator state, no free list to corrupt, and both statements
  stay table rows. It is slow and page-sized; the reference says when to use `buf` or `local`.
- **A header instead of `free p n`:** the size is one more value to get wrong at every release.
- **`local` not zero-filled:** clearing costs a loop per call, and the program can clear what it
  needs.
- **No configurable alignment:** nothing measured asks for it, and `alloc` already gives 16.
- **Declared size, not rounded size:** the rounding is an implementation detail, and the bytes
  between the two belong to nothing the program named.
- **A data name reaches to the end of its run:** tables are written a row a line and indexed
  from the first name, so the single row would reject the intended use.
- **Only straight-line knowledge:** anything across a label needs the same fixed point the
  assignment check avoids. The check is a net for slips; `docs/language.md` says so.
- **No clear at function start:** the mutation check showed it changes nothing, because the first
  pass's checks are rolled back and the end of the previous function already cleared.
- **Refuse at the backward jump instead of iterating:** a fixed point over back edges needs the
  code between label and jump to be checked again, and the top level is compiled once. Checking
  every way into a label against the mask the label used is sound in one pass; it refuses a few
  programs whose missing variable is never read, and the fix is one `set` before the loop.
- **`sys 60` is not treated as an exit:** the compiler knows no syscall, and a wrong guess would
  hide a real unassigned read.
- **Caller pops:** the callee's `ret` stays one fixed sequence, and a wrong value count is still
  found at compile time, so the stack cannot be left unbalanced.
- **Copy stack parameters into variables at entry:** a parameter is then a variable like any
  other and the allocation needs no special case; an unused one costs two instructions.
- **64, not unlimited:** the planned check for reads that skipped their assignment keeps one
  64-bit mask per label; globals are unlimited, so 64 locals is not a practical limit.
- **Two passes per function instead of a liveness analysis:** the first pass is the normal
  compiler with its output discarded, so the ranges come from the same parser and no second
  description of the syntax exists. Rolling back is a snapshot of ten values.
- **Ranges stretched over loops, not real liveness:** correct for any jumps, since going back in
  the source needs a backward jump; it costs registers only in loops that mention many variables.
- **No reuse at top level:** it is interleaved with functions, so it would need a pass over the
  whole source; cells are simple and the top level is not re-entered.
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
- A statement that changes compiler state inside a function must have that state in the
  snapshot of `fndef` (`snap`; stage1: the vars `sip` to `sdr`), or the second pass adds it twice.
  `fn_stack_variables_with_fixups` covers calls, forward names, data and labels.
- When a row of `optab` changes, change the matching `data` line of stage1.

## Open items
- 2026-11-19: `data` items are bytes only; wider values wait for hex and 64-bit literals.

## Related
- [Stage0 design decisions](stage0-design-decisions.md)
- [Stage1 self-hosting](stage1-self-hosting.md)
- [Token cost measurement](token-cost-measurement.md)
- [Open items](../status/open-items.md)

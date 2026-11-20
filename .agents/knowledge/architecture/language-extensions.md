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

### Signed operations (2026-11-19)
- Seven rows: `sdiv`, `smod`, `sar`, `slt`, `sle`, `sgt`, `sge`. Everything else is the same for
  signed and unsigned values.
- Decided not to add checked arithmetic, checked shifts or a handler for division by zero:
  overflow wraps, a shift uses six bits, and a zero divisor or `-2^63 / -1` is `SIGFPE`.
- The first tests of `sle`, `sge` and `sar` passed with the unsigned opcodes, because their
  operands agreed in both orders or in the low byte of the result; mutation checks showed it.
- The suite went from 534 to 548 tests.

### Recursion: tail calls, fewer saved registers, probed frames (2026-11-19)
- `tail name values` releases the frame and jumps: a row with the flags of `call` and `ret`.
  At most six values. Ten million rounds of a self-`tail` run in one frame.
- A function saves only the registers it uses (`fnregs`), not all six: `fact` takes 24 bytes of
  stack a call instead of 56, and every function is shorter. Tests that measure code size or
  frame distance changed (`fn_small_code_size` 51 to 24, `local_takes_no_register` 64 to 24).
- Stack exhaustion is defined as `SIGSEGV` on the guard page. A frame of a page or more is
  entered a page at a time with a touch of each.
- The suite went from 548 to 569 tests.

### Multiple source units (2026-11-19)
- `use "path"` compiles a file in place, once per path as written, at top level only. The file
  is read into the input buffer behind everything read so far; all units share the 64 KiB.
- A relative path starts from the directory the compiler runs in, since the main source comes
  from stdin and has no path of its own.
- Stage1's tables are `stage1/tables.ai`, used from the last line of `stage1/ailc.ai`; the
  Makefile lists both as prerequisites and compiles from the top of the repository.
- Fixtures for the tests are in `tests/lib/`. The suite went from 569 to 596 tests.
- The mutation script now takes a third target, the tables file, and points the `use` of a
  scratch copy of the main file at the mutated tables.

### Function composition: several results, functions as values (2026-11-19)
- Evaluated three extensions separately. Added: `ret a b` with `call f x as q r` (up to six
  results, in the registers of the values), and `ref name as p` with `callp p values`. Rejected:
  functions defined inside functions.
- A function has one result count: every `ret` must agree, `end` returns that many zeros, and a
  call may name fewer variables than results but not more (`wrong result count`). A function
  whose only exit is `tail` passes on any number.
- `callp` is unchecked: no value count, no result count.
- Stage1's `vplace` returns kind and value as two results; the encoding of both in one number
  with magic offsets is gone.
- The suite went from 596 to 628 tests.

### Compare-and-jump statements and if blocks (2026-11-20)
- Measured first (`docs/tokens.md`): control flow was 29% of the tokens of stage1 and the
  examples; fusing a comparison with its jump saves 22% of that, an `if` block 15%. Both added;
  no loop statement (31 loop-shaped labels against 152 if-shaped ones).
- Ten jump rows (`jeq` ... `jsge`) and twelve block rows (`if`, `ifz`, `ifeq` ... `ifsge`) with
  `else` and `end`. A block is an unnamed jump and label; `end` closes the innermost block.
- `tools/fuse.py` rewrote stage1: 138 pairs fused, 119 blocks, 138 lines and 8.7% of the tokens
  gone. It fuses only when the comparison result is dead on every path, converts only short,
  properly nested regions, and keeps the documented state labels of the top level. A first run
  without those limits turned `fin` and `blkend` into blocks hundreds of lines long.
- The examples use the jumps: 411 to 384 tokens, C and Rust now at 0.89 and 0.90 of AIL.
- The suite went from 628 to 675 tests.

### Cheaper system interfaces (2026-11-20)
- `sys` accepts 37 built-in names for syscall numbers, in that position only; a const of the
  program with the same name wins. `args as p` gives the initial stack pointer at top level.
- `lib/io.ai` is the first library file: `print`, `eprint`, `fdwrite`, `die`, `putn`, `strlen`,
  `argc`, `argv`. It is tested through `use` like any program (`lib_io_*`).
- Raw error values stay; with the signed jumps a failed call is one line (`jslt r 0 fail`).
  Registers of omitted arguments stay unset; the reference now says what that means.
- Stage1 names its own syscalls. The suite went from 675 to 700 tests.

### Floating point and atomic operations; no vectors (2026-11-20)
- Evaluated with programs written as tests: Newton's method for a cube root, a square root
  scaled to an integer, and two processes adding to one counter in shared memory.
- Added ten double-precision rows (`fadd fsub fmul fdiv fsqrt itof ftoi flt fle feq`) and two
  atomic rows (`xadd`, `cas`). A double is the 64 bits in an ordinary variable; `xmm0` and
  `xmm1` are scratch inside a statement. All twelve are table rows.
- With `xadd` replaced by a plain load, add and store, the two-process test loses updates and
  fails, so the test does exercise the lock.
- No float literals, no single precision, no vectors. The suite went from 700 to 717 tests.

### Source limit of 8 MiB (2026-11-20)
- `INSZ` went from 64 KiB to 8 MiB, 128 times as much. Nothing grows at run time: the buffers
  are sized for the largest source (about 700 MiB of address space) and the kernel backs only
  the pages touched. A megabyte of statements compiles in 10 ms with stage0.
- The output buffer is 16 times the source and is checked (`outchk`) at every statement, value,
  data item and string byte; `fin` checks that code and writable segment do not meet. Both
  report `program too big` and cannot fail while the 16-to-1 bound holds, so they are untested.
- 8 MiB is what the fixed layout allows with that bound: 128 MiB of code fits below the
  writable segment at 0x10000000; twice as much would not.
- The suite went from 717 to 722 tests.

### Hashed symbol lookup (2026-11-20)
- Labels, functions and global names are found through a chained hash of 2^20 buckets instead
  of searches through their tables. A source of 4.3 MiB with 100000 labels and jumps, 100000
  data names and 20000 functions compiles in 0.06 s with stage0 and 0.18 s with stage1; before,
  stage0 took 19.6 s. The output is the same byte for byte.
- The masks of forward jumps moved into pending nodes, so defining a label no longer scans the
  jumps of its scope.
- Stage1 returned 99999 for "not found"; with the 8 MiB limit a table can have that many
  entries, so it returns -1 now (`globals_above_100000`).
- The suite went from 722 to 726 tests.

## Why
- **Chains with a fixed bucket array, not open addressing:** the nodes fill an arena in order,
  so memory use follows the number of names, and the bucket array is 4 MiB whatever the source.
  A table that is probed must be sized from the largest source and touches a page per name.
- **Nodes are not removed when a function ends:** a scope number per function makes them
  unreachable, and removing them would need the labels of a scope to be listed.
- **The comparisons of kind and scope stay although they cannot fail today:** for one name two
  kinds or scopes always hash apart, which a mutation check confirmed; the checks cost two
  instructions and protect a future change of the hash.
- **Sized once instead of grown:** growing a buffer moves it, and the compiler keeps addresses
  into the input (every name) and into the output (labels, fixups, the snapshot of a function).
  Turning all of them into offsets touches most of both compilers for a limit nobody will meet.
- **Lazy pages make the big buffers free:** resident memory for `hello` stayed at 392 KB.
- **The compiler does not start under a small address-space limit:** the price of the above; a
  `ulimit -v` below about 800 MiB kills it at load. Accepted and documented.
- **Doubles as bit patterns in integer variables:** no second kind of variable, no second
  register pool, and the allocation is untouched. The cost is that the language cannot stop
  `add` on two doubles; the reference says so.
- **No float literals:** converting a decimal fraction to the nearest double correctly is a
  large algorithm to write twice, in assembly and in AIL; `itof` and `fdiv`, or the bits in hex,
  cover constants.
- **No vector operations:** they need values wider than a variable, so a register class and a
  memory layout of their own; nothing measured asks for them.
- **Only `flt`, `fle`, `feq`:** the other orderings are the same statement with the values
  swapped.
- **Names only in the number position:** as global constants they would take `read`, `write`,
  `open`, `exit` away from the programmer; in one position they cost nothing.
- **A table in the compiler, not a library of consts:** a `use` and a const per call would cost
  more tokens than the numbers they replace, and the table is 300 bytes.
- **`args` instead of saving the stack pointer at start:** every program would pay for code that
  few need; at top level the pointer is still what the kernel left.
- **Helpers in AIL, not in the compiler:** they need no compiler support, and a library is the
  first real use of `use`, several results and `tail`.
- **The prefix `j` and `if` on the comparison name:** no new words to learn, and `jne`, `ifle`
  are single tokens while the others are two.
- **`end` for blocks too:** a second closing word would cost a keyword, and the innermost-first
  rule is unambiguous because functions do not nest.
- **Blocks are not scopes:** variables stay those of the function, so the allocation and the
  assignment check treat a block as the jump it is.
- **No reset of `dataend` at `else`:** `else` always emits a `jmp`, so data before and after it
  can never be adjacent; a mutation check showed the reset changed nothing.
- **Results in the argument registers:** `ret` already loads its values through the argument
  parser, so several values need no new mechanism, only the count.
- **Fewer names than results is allowed:** dropping a result is what a call without `as` does.
- **`callp` unchecked:** an address has no signature, and carrying one would be the type system
  the language does not have.
- **No nested functions:** names of functions are global and flat, a helper inside a function
  could not use its variables without closures, and writing it outside costs the same tokens.
- **One surviving mutation pushes an unused value for `callp`** (the push decision off by one):
  the stack stays balanced and the callee reads its values from the top, so nothing shows.
- **Textual inclusion, not separate compilation:** functions, buffers and data can already be
  used before they are declared, so one stream with a fixup at the end is a complete linker for
  this language. Object files and symbols would add a format and a second tool.
- **Once per path:** a library named by two files must not be a duplicate, and include guards
  are boilerplate that costs tokens in every file.
- **No escapes in the path:** nothing in a path needs them, and the bytes go to `open` as they
  are.
- **Two checks that a function ends in its unit** (at `use` and at the end of a unit) cover each
  other: with either one removed the other, or the second pass over the function, still gives a
  syntax error, so mutation checks cannot tell them apart. Both stay, as each states a rule.
- **An explicit `tail`, not an optimisation of `call` + `ret`:** recognising the pair needs a
  look at the next line, and whether the stack grows is something the writer of a recursion
  must be able to rely on, not hope for.
- **At most six values:** values on the stack would lie in the frame that `tail` gives up.
- **Probe instead of a checked limit:** the kernel already has the guard; touching every page
  is all that is needed to reach it, and it costs nothing for frames under a page.
- **Two mutations of the probe change nothing observable** (a frame of exactly one page with or
  without the loop, and the loop ending one round earlier): the stack pointer ends in the same
  place either way.
- **Prefix `s`:** at most two tokens each (`sle` and `sar` are one), and the unsigned names
  stay the short ones because addresses and sizes are the common case.
- **No checked forms:** a checked add needs a second result or a trap; the first costs a line at
  every use, the second ends the program where a wrap is often intended (hashes, masks). A
  divisor is tested with one `jz` where it matters.
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

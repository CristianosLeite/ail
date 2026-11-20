# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

AIL is a proof-of-concept programming language whose design goal is low token consumption when an AI writes it. `docs/tokens.md` has the measured cost and what it decides: fewer lines matter more than shorter words, and a number costs more than a name. It is hardware-oriented (assembly-like, no classes or objects) and human readability is explicitly not a goal. When adding syntax, prefer short common words and bare spaces over punctuation and boilerplate, and let the compiler infer anything derivable (for example, a string literal supplies its own length).

The compiler is bootstrapped: stage0 (`stage0/ailc.s`) is written in assembly, and stage1 (`stage1/ailc.ai`) is the same compiler written in AIL, built by stage0 and then by itself. The two must behave identically, byte for byte, so a change to the language goes into both.

## Rules

- All repository text is in English: documentation, code comments, commit messages, test names, compiler messages and the knowledge base. This holds even when the conversation is in another language.

## Commands

Requires GNU `as` and `ld` on x86-64 Linux.

```
make            # build build/ailc, every example in examples/ and build/ailc1 (stage1)
make test       # run every test in tests/ and the I/O checks of tests/io.sh with stage0,
                # compare the compilers (tests/stage1.sh), then run both again with stage1
make test T=hello   # run one test, with both compilers
make build/foo  # compile examples/foo.ai to build/foo
make clean
tools/tokens.sh  # token cost of examples/ against the C, Rust and assembly programs in bench/
tools/bench.sh   # check that bench/ behaves like examples/ (needs gcc and rustc)
```

The compiler reads source on stdin and writes the executable on stdout:

```
build/ailc < prog.ai > prog && chmod +x prog
```

`build/ailc1` is used the same way. A test is a set of files `tests/<name>.*`, run by `tests/run.sh` (with the compiler named by `AILC`, default `build/ailc`):

- `.ai`: the program, or `.ai.sh`, a script that prints it (used for generated sources such as the size-limit tests)
- `.out`: expected stdout of the compiled program
- `.code`: expected exit status of the compiled program, default 0
- `.err`: expected compiler stderr; the compiler must then exit 1

A test has either `.err` (compiling must fail) or `.out` (the program must run). The runner kills a compiler or a program after 10 seconds, with `SIGKILL` to its whole process group, and fails the test, so a loop that never ends cannot hang the suite or outlive it. The compiler's I/O errors do not fit that form and are checked by `tests/io.sh`, which `make test` runs after the suite when no `T` is given: closed stdin, output to `/dev/full`, output to a pipe whose reader is gone, and a short write (a non-blocking pipe that takes 4096 bytes: the compiler must write that prefix, then report the error). `make test` names the compiler of every run itself, so an `AILC` in its environment changes nothing. `tests/stage1.sh` gives the source of every test and example to both compilers and requires the same stdout, stderr and exit status, then requires `build/ailc1` (stage1 built by stage0) and `build/ailc2` (stage1 built by itself) to be the same file. Not covered and checked by hand: the Makefile's behaviour after a failed example build.

Compiler errors are one line on stderr with no location: `ailc: syntax error`, `ailc: undefined variable`, `ailc: too many variables`, `ailc: duplicate name`, `ailc: number too big`, `ailc: buffers too big`, `ailc: undefined label`, `ailc: undefined function`, `ailc: wrong argument count` or `ailc: source too big` exit 1; `ailc: read error` or `ailc: write error` exit 2.

## Language

`docs/language.md` is the language reference, `docs/compiler.md` explains stage0 and `docs/stage1.md` stage1; keep them in sync with `stage0/ailc.s` and `stage1/ailc.ai`. Statements:

- `sys n a b ...`: raw Linux syscall, up to 6 arguments; `n` must be a decimal number or a `const`.
- `set a as x`, and `add sub mul div mod and or xor shl shr` as `op a b as x`: 64-bit, wrapping, unsigned division and shift.
- `eq ne lt le gt ge` as `op a b as x`: 64-bit comparison, unsigned order, result `1` or `0`.
- `buf name size`: reserves zero-filled writable bytes (rounded up to 8); the name is a constant address. The size is a number or a `const`.
- `var a b c`: global 64-bit cells, zero at start, read as a value and written by `as`, visible in every function.
- `const name number`: a named number, usable as any value, as the `sys` number and as a `buf` size.
- `data name item ...`: read-only bytes from strings and byte values 0 to 255; the name is a constant address and is optional. Consecutive `data` lines are contiguous, so a table is one row a line. No limit on their number.
- `len x as n`: the length in bytes of a buffer (as declared), of a data name (its own line) or of a string.
- `load p as x`, `store p a`: 64-bit access at address `p`; `load4`/`store4`, `load2`/`store2` and `loadb`/`storeb` are the 32-bit, 16-bit and byte forms, loads zero-extended.
- `label name`, `jmp name`, `jz a name`, `jnz a name`: a label, and jumps to one always, if `a` is zero or if it is not (all 64 bits); labels may be used before they are defined.
- `fn name a b` ... `end`: a function with up to 6 parameters; top-level execution skips the body, functions do not nest, and reaching `end` returns 0. `ret a` returns a value and is only allowed inside a function.
- `call name a b as x`: calls a function with as many values as it has parameters; `as` is optional, and the function may be defined later.

Arguments are 64-bit integers (decimal, `0x` hexadecimal, or either after `-`; one that does not fit is `number too big`), string literals, variables or global names (`buf`, `data`, `var`, `const`); a string is two arguments, address then length, in `sys` and `call`, and its address alone in every other statement. `\xHH` in a string is the byte with that hexadecimal value. `as name` at the end of a statement keeps its result in a variable; that is the only way to set one besides being a parameter. It is required on everything that produces a value, forbidden on stores, jumps and `ret`, and optional on `sys` and `call`. Variables are 64-bit, at most 6 at top level and 6 in each function (parameters included), and each is bound to one register for its whole scope. A function sees only its own variables and labels; `buf`, `data`, `var` and `const` names are global; a `buf` or `data` may be declared after its uses, a `var` or `const` must come first. At top level variables and global names share one name space; inside a function a parameter or variable hides a `buf`, `data` or `const` of the same name from its definition on, while `as` on a `var` name writes the cell. Labels and functions each have their own name space, with no limit on their number; keywords are only special at the start of a line. Tokens are separated by spaces or tabs only and may not touch; lines end with LF or CRLF; any other separator byte is a syntax error. `#` comments to end of line; a CR in a comment must still be followed by LF. Execution starts at the first line and `exit(0)` is appended.

## Compiler architecture (`stage0/ailc.s`)

GNU as, Intel syntax (`.intel_syntax noprefix`). Single pass with no AST; the symbol tables are a variable table with six entries per scope, a table of global names, a label table and a function table, and the only fixups are jump and call displacements: it reads all of stdin into a buffer, emits machine code into an output buffer as it scans, and writes the buffer once at the end.

- **Output is a complete ELF64** emitted by the compiler itself: a 176-byte header template (ELF header plus two `PT_LOAD` segments) is copied in first, code follows at file offset 176, and the image is loaded R+X at the fixed address `0x400000`. The second segment is R+W, has no file bytes and maps the buffers at the fixed address `0x10000000`. The only back-patches are the jump and call displacements and the segment sizes at the end.
- **Fixed register roles** throughout: `rsi`/`r15` input cursor and end, `rdi`/`r14` output cursor and base, `ebx` index of the next syscall argument, `ebp` number of variables defined in the current scope. Routines rely on these rather than passing parameters.
- **Statements are rows of `optab`**: keyword, operand count, flags and instruction bytes. Operands go through the same parser as syscall arguments, so they land in `rax` and `rdi`; `emit_op` then copies the row's bytes where `sys` gets its `syscall`, and the result is left in `rax` for `as`. `curop` points at the current row. `buf`, `data`, `var`, `const`, `label`, `fn` and `end` are the statements parsed on their own (`bufdef`, `datadef`, `vardef`, `constdef`, `labdef`, `fndef`, `fnend`).
- **Arguments** are emitted by `emit_mov` into the register of the argument position (rax, rdi, rsi, rdx, r10, r8, r9) in the shortest of three forms: `mov r32, imm32` from `regtab` below 2^32, `mov r64, imm32` when sign extension gives the value, else `mov r64, imm64`. `rdnum` reads every integer and reports `number too big`. A fixup of `refs` relies on the first form: it patches the four bytes before the cursor.
- **Variables** live in the generated program's `rbx`, `rbp`, `r12`, `r13`, `r14`, `r15` (table `varnum`), assigned in order of first `as` within a scope. The compiler's table `vars` stores each name as a pointer into the input buffer plus a length; its first half is the top level and its second half the function being compiled (`infn`), and `defvar` finds or adds a name in the current half. `emit_mov_rr` emits the 64-bit register-to-register `mov` used both to pass a variable and to capture `rax`.
- **Buffers** are compile-time addresses in the writable segment (tables `bufs`, `bufaddr` and `bufsize`, total in `bsssz`), passed as an `imm32` by `emit_mov`. The same tables hold every global name, with its kind in `bufkind` (`G_ADDR` buffer or data, `G_VAR`, `G_CONST`), and are sized from the source limit; `newglob` enters a name after the duplicate checks. A `var` is a cell below the buffers (`0x10000000 - 8n`), read by `ident` with `mov r64, [abs32]` and written by `capture` with `mov [abs32], rax`; `fin` moves the start of the writable segment down over the cells. A `const` keeps its value in `bufsize`.
- **Labels and jumps**: `label` records the output cursor under its name (tables `labels` and `labaddr`). `jmp`, `jz` and `jnz` are `optab` rows flagged `IS_JMP` whose bytes stop before the `rel32`; the name after their operands is taken as a label by `jtarget`, which appends the name and the `rel32` address to `fixs`. `resolve` fills in every jump of the current scope, backward ones included, and reports `undefined label`; `fin` calls it for the top level and `end` for a function. Both tables are sized from the source limit and cannot overflow.
- **Functions**: `fn` emits a `jmp rel32` over the body (patched by `end`), then the entry: six `push`es of the variable registers and one `mov` per parameter from its argument register (`rax`, `rdi`, `rsi`, `rdx`, `r10`, `r8`). It saves `ebp` and remembers where the function's labels and jumps start (`labbase`, `fixbase`); `end` emits `xor eax, eax` and the epilogue, resolves the function's jumps and cuts `labels` and `fixs` back, which is what makes labels local. `ret` is an `optab` row (`IS_RET`) whose bytes are the six `pop`s and `ret`. `call` is a row flagged `IS_CALL`: `next` reads the function name into `callname`, and `emit_op` appends name, `rel32` address and value count to `calls`, which `fin` resolves against `funcs`, `funaddr` and `funargs`, reporting `undefined function` and `wrong argument count`.
- **Strings and data** are inlined in the code stream behind a `jmp rel32`, so their absolute address is known immediately and no data section or second pass is needed. The code segment is not writable, so they are read-only. `strbytes` copies the bytes of a literal for both. A `data` statement that starts where the previous one ended (`dataend`) appends to it and rewrites that jump (`datarel`) instead of emitting its own; `label` clears `dataend`, so a label after data stays the address of code. The row flag `IS_LEN` makes an operand its length instead of its address.

Adding a statement that takes values in `rax`/`rdi` and leaves a result in `rax` means adding a row to `optab`; anything else needs a keyword check in `next` (as `buf`, `data`, `var`, `const`, `label`, `fn` and `end` have) and its own parser ending in `eol`. Either way add tests for what it accepts and rejects. Do not name a label after an assembler keyword: `jbe word` assembles without a warning and jumps to the wrong place. Forward references go through a fixup list: `fixs` holds the `rel32` jump displacements to labels of the current scope, `calls` the `rel32` displacements of calls, `refs` the `imm32` of every name used as a value before a `buf` or `data` declared it (address or length); `fin` resolves `refs` last and reports `undefined variable` there. Code inside `emit_op` must keep `r8`, where `capture` holds the variable register.

## Stage1 (`stage1/ailc.ai`)

A translation of stage0, routine by routine; `docs/stage1.md` has the map. What to know before editing it:

- **The top level is the state machine** of stage0 under the same labels (`next`, `tokend`, `arg`, `num`, `str`, `ident`, `capture`, `bufdef`, `vardef`, `constdef`, `datadef`, `labdef`, `jtarget`, `fndef`, `fnend`, `fin`) and uses only the variables `c d r f p q`: a seventh name is `too many variables`. Everything stage0 calls is a function.
- **Global state is in `var`s**, since a function sees no top-level variable: `ip`, `ie`, `op`, `ai`, `nv`, `cur`, `ns`, `nl` for the fixed registers of stage0 and its counters under their own names (`nbufs`, `infn`, `nfix`, ...). `as` on one of those names writes the global, so no function may use them for a local. The tables are buffers (`vars`, `globs`, `labs`, `fixs`, `funs`, `calls`).
- **Errors are calls that never return** (`call err`, `call edup`, ...); `ok` and `no` are a syntax error unless their value is non-zero or zero. A lookup returns 99999 for a name that is not defined.
- **The read-only tables** (ELF header, statement rows, register tables) are `data` lines at the end of the file under the names of stage0 (`hdr`, `optab`, `fnpush`, `regtab`, `argnum`, `varnum`, `exit0`, and `retc` for the code of `ret`), one row a line. The statement rows have the layout of `optab`, plus seven rows flagged 128 for `fn`, `buf`, `end`, `label`, `data`, `var` and `const`; flag 64 is `IS_LEN` as in stage0.
- The source must stay within the 65536-byte limit of the compilers (it is about 21 KiB).

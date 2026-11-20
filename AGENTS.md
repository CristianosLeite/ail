# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

AIL is a proof-of-concept programming language whose design goal is low token consumption when an AI writes it. It is hardware-oriented (assembly-like, no classes or objects) and human readability is explicitly not a goal. When adding syntax, prefer short common words and bare spaces over punctuation and boilerplate, and let the compiler infer anything derivable (for example, a string literal supplies its own length).

The plan is to bootstrap: stage0 is written in assembly, and later compiler versions are to be written in AIL itself. Self-hosting is not started.

## Rules

- All repository text is in English: documentation, code comments, commit messages, test names, compiler messages and the knowledge base. This holds even when the conversation is in another language.

## Commands

Requires GNU `as` and `ld` on x86-64 Linux.

```
make            # build build/ailc and every example in examples/
make test       # run every test in tests/
make test T=hello   # run one test
make build/foo  # compile examples/foo.ai to build/foo
make clean
```

The compiler reads source on stdin and writes the executable on stdout:

```
build/ailc < prog.ai > prog && chmod +x prog
```

A test is a set of files `tests/<name>.*`, run by `tests/run.sh`:

- `.ai`: the program, or `.ai.sh`, a script that prints it (used for generated sources such as the size-limit tests)
- `.out`: expected stdout of the compiled program
- `.code`: expected exit status of the compiled program, default 0
- `.err`: expected compiler stderr; the compiler must then exit 1

A test has either `.err` (compiling must fail) or `.out` (the program must run). The runner kills a program after 10 seconds and fails the test, so a loop that never ends cannot hang the suite. Not covered by the runner and checked by hand: the compiler's I/O errors (`build/ailc <&-`, output to `/dev/full`) and the Makefile's behaviour after a failed example build.

Compiler errors are one line on stderr with no location: `ailc: syntax error`, `ailc: undefined variable`, `ailc: too many variables`, `ailc: duplicate name`, `ailc: too many buffers`, `ailc: undefined label`, `ailc: undefined function`, `ailc: wrong argument count` or `ailc: source too big` exit 1; `ailc: read error` or `ailc: write error` exit 2.

## Language (stage0)

`docs/language.md` is the language reference and `docs/compiler.md` explains the compiler; keep both in sync with `stage0/ailc.s`. Statements:

- `sys n a b ...`: raw Linux syscall, up to 6 arguments; `n` must be a decimal number.
- `set a as x`, and `add sub mul div mod and or xor shl shr` as `op a b as x`: 64-bit, wrapping, unsigned division and shift.
- `eq ne lt le gt ge` as `op a b as x`: 64-bit comparison, unsigned order, result `1` or `0`.
- `buf name size`: reserves zero-filled writable bytes (rounded up to 8); the name is a constant address, at most 16 buffers.
- `load p as x`, `loadb p as x`, `store p a`, `storeb p a`: 64-bit and byte access at address `p`.
- `label name`, `jmp name`, `jz a name`, `jnz a name`: a label, and jumps to one always, if `a` is zero or if it is not (all 64 bits); labels may be used before they are defined.
- `fn name a b` ... `end`: a function with up to 6 parameters; top-level execution skips the body, functions do not nest, and reaching `end` returns 0. `ret a` returns a value and is only allowed inside a function.
- `call name a b as x`: calls a function with as many values as it has parameters; `as` is optional, and the function may be defined later.

Arguments are unsigned 32-bit decimals, string literals, variables or buffer names; a string expands to two arguments, address then length, and is accepted only by `sys`. `as name` at the end of a statement keeps its result in a variable; that is the only way to set one besides being a parameter. It is required on everything that produces a value, forbidden on stores, jumps and `ret`, and optional on `sys` and `call`. Variables are 64-bit, at most 6 at top level and 6 in each function (parameters included), and each is bound to one register for its whole scope. A function sees only its own variables and labels; buffers are global. Variables and buffers share one name space, and labels and functions each have their own, with no limit on their number; keywords are only special at the start of a line. Tokens are separated by spaces or tabs only and may not touch; lines end with LF or CRLF; any other separator byte is a syntax error. `#` comments to end of line. Execution starts at the first line and `exit(0)` is appended.

## Compiler architecture (`stage0/ailc.s`)

GNU as, Intel syntax (`.intel_syntax noprefix`). Single pass with no AST; the symbol tables are a variable table with six entries per scope, a sixteen-entry buffer table, a label table and a function table, and the only fixups are jump and call displacements: it reads all of stdin into a buffer, emits machine code into an output buffer as it scans, and writes the buffer once at the end.

- **Output is a complete ELF64** emitted by the compiler itself: a 176-byte header template (ELF header plus two `PT_LOAD` segments) is copied in first, code follows at file offset 176, and the image is loaded R+X at the fixed address `0x400000`. The second segment is R+W, has no file bytes and maps the buffers at the fixed address `0x10000000`. The only back-patches are the jump and call displacements and the segment sizes at the end.
- **Fixed register roles** throughout: `rsi`/`r15` input cursor and end, `rdi`/`r14` output cursor and base, `ebx` index of the next syscall argument, `ebp` number of variables defined in the current scope. Routines rely on these rather than passing parameters.
- **Statements are rows of `optab`**: keyword, operand count, flags and instruction bytes. Operands go through the same parser as syscall arguments, so they land in `rax` and `rdi`; `emit_op` then copies the row's bytes where `sys` gets its `syscall`, and the result is left in `rax` for `as`. `curop` points at the current row. `buf`, `label`, `fn` and `end` are the statements parsed on their own (`bufdef`, `labdef`, `fndef`, `fnend`).
- **Arguments** are emitted by `emit_mov` as `mov r32, imm32` into the register chosen by `regtab` (rax, rdi, rsi, rdx, r10, r8, r9). This zero-extends, which is why values are limited to unsigned 32 bits.
- **Variables** live in the generated program's `rbx`, `rbp`, `r12`, `r13`, `r14`, `r15` (table `varnum`), assigned in order of first `as` within a scope. The compiler's table `vars` stores each name as a pointer into the input buffer plus a length; its first half is the top level and its second half the function being compiled (`infn`), and `defvar` finds or adds a name in the current half. `emit_mov_rr` emits the 64-bit register-to-register `mov` used both to pass a variable and to capture `rax`.
- **Buffers** are compile-time addresses in the writable segment (tables `bufs` and `bufaddr`, total in `bsssz`), passed as an `imm32` by `emit_mov`.
- **Labels and jumps**: `label` records the output cursor under its name (tables `labels` and `labaddr`). `jmp`, `jz` and `jnz` are `optab` rows flagged `IS_JMP` whose bytes stop before the `rel32`; the name after their operands is taken as a label by `jtarget`, which appends the name and the `rel32` address to `fixs`. `resolve` fills in every jump of the current scope, backward ones included, and reports `undefined label`; `fin` calls it for the top level and `end` for a function. Both tables are sized from the source limit and cannot overflow.
- **Functions**: `fn` emits a `jmp rel32` over the body (patched by `end`), then the entry: six `push`es of the variable registers and one `mov` per parameter from its argument register (`rax`, `rdi`, `rsi`, `rdx`, `r10`, `r8`). It saves `ebp` and remembers where the function's labels and jumps start (`labbase`, `fixbase`); `end` emits `xor eax, eax` and the epilogue, resolves the function's jumps and cuts `labels` and `fixs` back, which is what makes labels local. `ret` is an `optab` row (`IS_RET`) whose bytes are the six `pop`s and `ret`. `call` is a row flagged `IS_CALL`: `next` reads the function name into `callname`, and `emit_op` appends name, `rel32` address and value count to `calls`, which `fin` resolves against `funcs`, `funaddr` and `funargs`, reporting `undefined function` and `wrong argument count`.
- **Strings** are inlined in the code stream behind a `jmp rel32`, so their absolute address is known immediately and no data section or second pass is needed. The code segment is not writable, so string data is read-only.

Adding a statement that takes values in `rax`/`rdi` and leaves a result in `rax` means adding a row to `optab`; anything else needs a keyword check in `next` (as `buf`, `label`, `fn` and `end` have) and its own parser ending in `eol`. Either way add tests for what it accepts and rejects. Do not name a label after an assembler keyword: `jbe word` assembles without a warning and jumps to the wrong place. Forward references to code go through a fixup list: `fixs` holds the `rel32` jump displacements to labels of the current scope, `calls` the `rel32` displacements of calls. Code inside `emit_op` must keep `r8`, where `capture` holds the variable register.

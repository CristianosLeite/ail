# How the stage0 compiler works

`stage0/ailc.s` is the bootstrap compiler: about 1700 lines of x86-64 assembly (GNU as, Intel syntax) with no dependencies beyond Linux syscalls. It turns AIL source on stdin into a runnable ELF64 executable on stdout.

It is the seed of the bootstrap: [stage1](stage1.md) is the same compiler written in AIL, stage0 builds it the first time, and what this page says about the output holds for both.

## Pipeline

There is one pass over the top level and two over each function, and no intermediate representation.

1. Ignore `SIGPIPE`, so that writing to a closed pipe fails with an error the compiler can report instead of killing it. Read all of stdin into an input buffer that holds 64 KiB plus one spare byte; filling the spare byte means the source is too big.
2. Copy a 176-byte ELF header template to the start of a 1 MiB output buffer.
3. Scan the source. For each statement, append machine code directly to the output buffer.
4. Append the code for `exit(0)`.
5. Fill in the displacement of every top-level jump from the label table, of every call from the function table, and the value of every name used before its declaration from the table of global names.
6. Patch the two segment sizes in the header, write the buffer to stdout, exit.

Because code is emitted as it is read, an address that appears later in the source is not known yet. Jumps, calls and the names of buffers and data declared later each leave four empty bytes and an entry in a fixup list. The jumps of a function are filled in at its `end`, once all its labels are known, and the rest in step 5.

## Register conventions

The whole compiler shares a fixed set of registers instead of passing parameters:

| Register | Role |
|---|---|
| `rsi` | input cursor |
| `r15` | end of input |
| `rdi` | output cursor |
| `r14` | start of output buffer |
| `ebx` | index of the next syscall argument in the current statement |
| `ebp` | number of variables defined so far in the current scope |

The memory cell `curop` points at the operation-table entry of the statement being compiled.

`rsi` and `rdi` are chosen so that `lodsb`, `stosb` and `rep movsb` work on the cursors directly.

## Code map

| Label | Job |
|---|---|
| `_start` | ignore `SIGPIPE`, read stdin, copy the header template |
| `next` | start of a statement: skip indentation, blank lines and comments, find the keyword in `optab`, and for `sys` require its syscall number, for `call` read the function name, for `ret` require an open function |
| `crlf` | check that a CR is followed by LF; called wherever a line may end, and for every CR in a comment |
| `tokend`, `tokchk` | check that a token is followed by a space, tab, comment or line end; `tokend` then falls into `arg` |
| `arg` | dispatch the next argument, or end the statement by calling `emit_op` |
| `num` | an integer as an argument |
| `str` | copy the literal into the output and pass its address and length (`sys`, `call`), its length (`len`) or its address |
| `strbytes`, `hexdig` | copy the bytes of a string up to its closing quote, decoding the escapes; read one hexadecimal digit |
| `ident` | a name as an argument: pass a variable, the address of a buffer or of data, the cell of a `var`, the value of a `const`, or for `len` a size; hand over to `capture` on `as`, or to `jtarget` when a jump has its operands |
| `capture` | `as <name>`: call `emit_op` and store `rax` in the cell of the `var` with that name, or else in the variable, defined if new |
| `varplace`, `emit_varmov`, `emit_mem` | where a variable lives; a `mov` between a variable and a register; a `mov` between a register and memory |
| `alloc`, `emit_frame` | place the variables of a function after its first pass; reserve or release its stack slots |
| `defvar` | read a variable name and find it in the pool of the current scope, or add it |
| `bufdef` | `buf <name> <size>`: enter the buffer in the table of global names and reserve its bytes |
| `vardef`, `constdef` | `var <name>...` and `const <name> <number>`: enter the names with their kind and the address of a cell, or the value |
| `newglob` | refuse a name in use as a variable or a global name, else enter it in the next table slot |
| `rdname`, `rdnum`, `constname` | read a name that is not `as`; read an integer; read a name that must be a `const` and give its value |
| `datadef` | `data [<name>] <item>...`: copy the bytes into the output behind a jump, or behind the jump of the data statement just before; enter the name |
| `labdef` | `label <name>`: enter the label and the current output position in the label table |
| `jtarget` | the label name of a jump: call `emit_op`, leave room for the displacement and record a fixup |
| `fndef` | `fn <name> <parameter>...`: enter the function, emit the jump over it and its entry code, open its scope |
| `fnend` | `end`: emit the default return, resolve the function's jumps and close its scope |
| `resolve` | fill in the jumps of the current scope from its labels |
| `blanks`, `blank1`, `eol`, `name` | skip spaces and tabs; require at least one; check that the line ends; read a name |
| `lookup_var`, `lookup_buf`, `lookup_label`, `lookup_fn` | find a name among the variables or the labels of the current scope, the buffers or the functions |
| `emit_op` | check the operand count and emit the statement's instruction bytes; for `call`, also leave room for the displacement and record it |
| `emit_mov_rr` | emit a 64-bit `mov <register>, <register>` |
| `emit_mov` | emit `mov <argument register>, <value>` and advance `ebx` |
| `fin` | emit `exit(0)`, patch the top-level jumps, the calls, the forward uses of names and the sizes, write the output |
| `err`, `err_big`, `err_undef`, `err_vars`, `err_dup`, `err_num`, `err_bufs`, `err_label`, `err_fn`, `err_argc` | source errors: print a message, exit 1 |
| `err_read`, `err_write` | I/O errors: print a message, exit 2 |

## Output file layout

```
offset 0     ELF header            64 bytes
offset 64    program header        56 bytes   PT_LOAD, flags R+X: the whole file
offset 120   program header        56 bytes   PT_LOAD, flags R+W: buffers, no file bytes
offset 176   code and strings      entry point
```

The whole file is one segment loaded at the fixed address `0x400000`, so the byte at file offset `n` lives at `0x400000 + n` and the entry point is `0x4000b0`. There are no sections, no symbol table and no dynamic linking. This segment is readable and executable but not writable.

The second segment has a file size of zero and a memory size equal to the total of all `buf` statements, so the kernel maps that many zero-filled writable bytes at the fixed address `0x10000000`. A program without buffers keeps the header with a memory size of zero, which the kernel accepts. The cells of `var` lie below that address, the first one at `0x0ffffff8` and each next one 8 bytes lower; `fin` moves the start of the segment down by as many whole pages as they need and adds them to the memory size. Both addresses are fixed so that every address is known while the source is still being read.

## Code generation

**Integer argument.** `emit_mov` picks the shortest of three forms. A value below 2^32 is `mov r32, imm32` into the register for the current argument position, taken from `regtab`: 5 bytes, or 6 with a REX prefix for `r8`–`r10`; writing a 32-bit register clears the upper half. A value whose upper 33 bits are all ones is `mov r64, imm32` (`REX.W C7 /0`), which sign-extends: 7 bytes. Anything else is `mov r64, imm64` (`REX.W B8+r`): 10 bytes. `rdnum` reads the literal: decimal with a 64-bit overflow check on every digit, or up to sixteen hexadecimal digits after `0x`, negated after a `-`.

**String argument.** The bytes are placed in the code stream and jumped over. `sys` and `call` get both `mov`s, `len` only the second and every other statement only the first:

```
jmp  over          ; E9 + 32-bit length
<string bytes>
over:
mov  <reg>, address
mov  <next reg>, length
```

The address is known as soon as the string is read, so no data section and no back-patching of addresses is needed. The only patch is the jump distance, which is written when the closing quote is found.

**Variable argument.** `mov r64, r64` from the variable's register into the argument register: `REX.W 89 /r`, 3 bytes. The x86 register numbers come from `argnum` (argument position) and `varnum` (variable index); bit 3 of each goes into the REX prefix and the low bits into the ModRM byte.

**Buffer or data argument.** The address is a constant, so it is passed like an integer: `mov r32, imm32`. So is the length that `len` passes.

**Var argument.** `mov r64, [abs32]` from the cell into the argument register: `REX.W 8B /r` with a SIB byte for the absolute address, 8 bytes. The address is below `0x10000000`, so the sign extension of the 32-bit displacement does not matter. `as` on a `var` stores with `mov [abs32], rax`, also 8 bytes.

**Const argument.** Passed like an integer.

**Data.** `data` emits the same `jmp` and bytes as a string and no `mov`. If the output cursor still stands where the previous `data` statement ended (`dataend`), no code and no label came between: the bytes are appended and the displacement of that statement's jump (`datarel`) is written again, so the run is one block. `label` clears `dataend`, because a label after data must stay the address of code.

**End of statement.** The instruction bytes of the statement, copied from its `optab` entry by `emit_op`; for `sys` that is `syscall` (`0F 05`). With `as`, they are followed by `mov <variable register>, rax` in the same 3-byte encoding.

**End of program.** `mov eax, 60` / `xor edi, edi` / `syscall`.

## Operations

Every statement except `buf`, `data`, `var`, `const`, `label`, `fn` and `end` is one row of the table `optab`: keyword, operand count, flags and instruction bytes. The operands are parsed by the same code as syscall arguments, so the first lands in `rax` and the second in `rdi`, the registers of argument positions 0 and 1. The instruction bytes then compute the result into `rax`, where `as` picks it up exactly as it does after a syscall.

| Statement | Emitted after the operands |
|---|---|
| `sys` | `syscall` |
| `set` | nothing |
| `add` `sub` `and` `or` `xor` | `op rax, rdi` |
| `mul` | `imul rax, rdi` |
| `div` | `xor edx, edx` / `div rdi` |
| `mod` | `xor edx, edx` / `div rdi` / `mov rax, rdx` |
| `shl` `shr` | `mov rcx, rdi` / `shl` or `shr rax, cl` |
| `eq` `ne` `lt` `le` `gt` `ge` | `cmp rax, rdi` / `sete` `setne` `setb` `setbe` `seta` or `setae al` / `movzx eax, al` |
| `len` | nothing: its operand is the length |
| `load` | `mov rax, [rax]` |
| `load4` | `mov eax, [rax]` |
| `load2` | `movzx eax, word ptr [rax]` |
| `loadb` | `movzx eax, byte ptr [rax]` |
| `store` | `mov [rax], rdi` |
| `store4` | `mov [rax], edi` |
| `store2` | `mov [rax], di` |
| `storeb` | `mov [rax], dil` |
| `jmp` | `jmp rel32` |
| `jz` `jnz` | `test rax, rax` / `jz` or `jnz rel32` |
| `call` | `call rel32` |
| `ret` | `pop r15` / `pop r14` / `pop r13` / `pop r12` / `pop rbp` / `pop rbx` / `ret` |

The scratch registers `rax`, `rdi`, `rcx` and `rdx` are never variable registers. So `add x 1 as x` with `x` in `rbx` is `mov rax, rbx` / `mov edi, 1` / `add rax, rdi` / `mov rbx, rax`: 14 bytes, with no attempt to use shorter forms.

A comparison uses the unsigned conditions and turns the flags into a value at once: `setcc` writes only `al`, and `movzx eax, al` clears the other 56 bits, which still hold the first operand. Nothing depends on the flags after the statement, so a comparison emits no jump and `jz` and `jnz` test the value again.

The flags say whether `as` is required (everything that produces a value), forbidden (the stores, the jumps and `ret`) or optional (`sys` and `call`), whether a label name follows the operands (the jumps), whether a function name precedes them (`call`), whether the statement needs an open function (`ret`) and whether its operand is taken as a length (`len`). `emit_op` rejects a statement whose operand count differs from the table; `sys` is exempt and takes one to seven values, and `call` takes up to six, checked against the function when the call is resolved.

## Worked example

`examples/hello.ai` writes a line and exits with status 0 only if all 12 bytes went out:

```
sys 1 1 "hello world\n" as n
sub n 12 as n
sys 60 n
```

It compiles to 251 bytes: the 176-byte header followed by

```
b0:  b8 01 00 00 00      mov  eax, 1          ; syscall number: write
b5:  bf 01 00 00 00      mov  edi, 1          ; fd: stdout
ba:  e9 0c 00 00 00      jmp  0xcb            ; skip the 12 string bytes
bf:  68 65 6c 6c 6f 20 77 6f 72 6c 64 0a      ; "hello world\n"
cb:  be bf 00 40 00      mov  esi, 0x4000bf   ; address of the string
d0:  ba 0c 00 00 00      mov  edx, 12         ; its length
d5:  0f 05               syscall
d7:  48 89 c3            mov  rbx, rax        ; as n: n is the first variable, rbx
da:  48 89 d8            mov  rax, rbx        ; sub: first operand n
dd:  bf 0c 00 00 00      mov  edi, 12         ; second operand
e2:  48 29 f8            sub  rax, rdi        ; the instruction bytes of sub
e5:  48 89 c3            mov  rbx, rax        ; as n
e8:  b8 3c 00 00 00      mov  eax, 60         ; syscall number: exit
ed:  48 89 df            mov  rdi, rbx        ; status: n
f0:  0f 05               syscall
f2:  b8 3c 00 00 00      mov  eax, 60         ; implicit exit(0), never reached here
f7:  31 ff               xor  edi, edi
f9:  0f 05               syscall
```

The one-line program `sys 1 1 "hello world\n"` is the first seven lines plus the implicit exit: 224 bytes.

To inspect any compiled program the same way:

```
objdump -D -b binary -mi386:x86-64 -Mintel --start-address=176 build/hello
```

## Variables

The table `vars` has one 16-byte entry per variable: the address of the name inside the input buffer and its length. Names are not copied. It has two halves of 64 entries: the first for the top level, the second for the function being compiled. `ebp` counts the entries of the current half, and `lookup` searches them linearly.

Six registers hold variables: `rbx`, `rbp`, `r12`, `r13`, `r14`, `r15` (`varnum`). These are the registers that neither the `syscall` instruction (which destroys `rax`, `rcx` and `r11`) nor the argument positions use. `varplace` says where a variable lives, and `emit_varmov` emits the `mov` between it and a register: `emit_mov_rr` for a register, `emit_mem` for memory (`REX.W 8B` or `89` with a SIB byte, 8 bytes).

**Top level.** The first six variables get the registers in order of definition. Each later one gets a cell below the buffers, allocated like the cell of a `var` and recorded in `topcell`. Nothing is reused: the top level is interleaved with functions and is compiled in one pass.

**Functions** are compiled twice. On `fn`, `fndef` saves the cursors and every table counter in `snap` and sets `pass` to 1. The first pass compiles the function as usual, with every variable in `rbx`; its code is thrown away, but it finds every error and records for each variable where the source defines it (`vfirst`) and mentions it last (`vlast`), and for each jump to a label that is already defined, a loop: the source positions of the label and of the jump (`labpos`, `loops`). At `end`, `alloc` places the variables, `fnend` restores the snapshot, sets `pass` to 2 and jumps back to `fndef`, and the second pass emits the real code.

`alloc` first stretches the ranges: a variable whose range meets a loop is in use to the end of that loop, because the next round may read it again; this repeats until nothing changes, so nested and overlapping loops are covered. Then it takes the variables in order of definition and gives each the first place, among the six registers and then the stack slots, whose previous variable was mentioned last before this one is defined (`locfree`). The result is `fnloc` and the number of slots `fnslots`.

This is safe because execution only moves backward in the source through a backward jump. If a variable is read after another one with the same place was written, the path between the two must leave the first range and come back, and every way back is a loop that meets the range and would have stretched it over the other variable.

A function with slots reserves them after its pushes (`sub rsp, 8n`) and releases them before every return (`emit_frame`); a slot is `[rsp + 8k]`.

A name is only entered in the table when its `as` is reached, at the end of the statement, so `sys 1 n as n` with a new `n` is not the variable.

## Buffers

The table `bufs` has the same 16-byte entries as `vars` and holds every global name: buffers, data, vars and consts. `bufkind` says which (`G_ADDR`, `G_VAR`, `G_CONST`), `bufaddr` holds one 32-bit address per entry and `bufsize` its length for `len`, or the value of a const. The table is sized from the source limit, since `var a b c` declares a name every two bytes; `nvars` counts the vars. `buf` rounds the size up to 8 bytes, gives the buffer the address `0x10000000` plus the bytes reserved so far, and adds the size to the running total `bsssz`, which `fin` writes into the second program header. The total is kept below 4 GiB minus the base so that every address fits the `imm32` that `emit_mov` writes.

`ident` looks a name up among the variables first and the global names second. A name in neither is taken for a buffer or data declared later: `ident` passes `mov r32, 0` and appends the name, the address of that `imm32` and whether the address or the length is wanted to `refs`. `fin` looks every entry up, reports `undefined variable` for a name that is still unknown or is a var or a const, and writes the value. Inside a function `defvar` accepts the name of a global other than a var, so that a variable hides it for the rest of the function; at top level it refuses. Every declaration of a global name refuses a name found in either table (`newglob`), and `as` refuses a global name unless it is a `var`, so a name always means one thing. A buffer outlives the function it is declared in, so inside a function `buf` also searches the top-level half of `vars` (`lookup_topvar`); otherwise the buffer would be hidden by, or block, a top-level variable of the same name.

## Labels and jumps

The table `labels` has the same 16-byte entries as `vars`, and `labaddr` holds for each label the output cursor at the time its `label` line was read. Labels are looked up only in this table, which makes them a separate name space. `lookup_label` searches from the entry `labbase` on, which is zero outside a function, and returns an index counted from there.

A jump is an `optab` row whose instruction bytes stop just before the 32-bit displacement: `E9` for `jmp`, and `test rax, rax` followed by `0F 84` or `0F 85` for `jz` and `jnz`. Its row has the flag `IS_JMP`. When `ident` reads a name and the statement already has all its operands, the name is the label: `jtarget` checks that the line ends, emits the row through `emit_op`, skips four bytes and appends an entry to `fixs` with the label name and the address of those four bytes. A statement with `IS_JMP` that ends without reaching `jtarget` is a syntax error.

No jump is resolved while scanning, not even a backward one. `resolve` walks `fixs` from the entry `fixbase` on, looks each name up in `labels` and writes the label address minus the address of the byte after the displacement. A name that is not found is the `undefined label` error. One path for both directions keeps the code small; the price is a linear search per jump. `fin` calls `resolve` for the top level after the `exit(0)` code is in place, and `end` calls it for a function.

Neither table can overflow: the shortest `label` line is 8 bytes and the shortest jump line is 6, so the tables are sized for a 64 KiB source made only of those.

## Functions

`fn` and `end` are parsed on their own; `call` and `ret` are `optab` rows, so their values go through the argument parser like any operand.

**Definition.** `fndef` enters the name in `funcs` (16-byte entries like `vars`) and emits

```
jmp  after              ; E9 + rel32, so that top-level execution skips the body
entry:
push rbx / rbp / r12 / r13 / r14 / r15     ; 53 55 41 54 41 55 41 56 41 57
sub  rsp, 8 * slots                        ; only if a variable lives on the stack
mov  <variable i>, <argument i>            ; one per parameter
```

`funaddr` gets the address of `entry` and `funargs` the number of parameters. Each parameter is defined through `defvar` like a name after `as`, and `emit_varmov` copies it from the argument position of the same index to its place. A seventh parameter is `too many variables`: there are six argument registers.

**Scope.** `fndef` saves `ebp` in `topvars`, clears it and sets `infn`, which makes `lookup_var` use the second half of `vars`. It also sets `labbase` and `fixbase` to the current ends of `labels` and `fixs`: the function's labels and jumps are stacked on top of the top-level ones collected so far. `fnend` calls `resolve` for exactly that part, then cuts both tables back to the bases and restores `ebp`. That is all that makes labels and variables local, and it is why functions do not nest: there is one saved scope.

**Return.** `ret` is a row with one operand, which lands in `rax`, and whose instruction bytes are the six `pop`s in reverse order and `ret`. They are inlined at every `ret`, after `add rsp, 8 * slots` when the function has slots. `fnend` emits `xor eax, eax` and the same bytes, taken from the row at `retcode`, and then fills in the jump that `fndef` left before the entry. A `ret` outside a function is rejected in `next` by the flag `IS_RET`.

**Call.** `next` reads the function name of a `call` into `callname` before the values. The values land in argument positions 0 to 5: `rax`, `rdi`, `rsi`, `rdx`, `r10`, `r8`. At the end of the statement `emit_op` copies the row's single byte `E8`, appends the name, the address of the displacement and the number of values to `calls`, and skips four bytes. With `as`, `capture` then stores `rax` as after any statement.

`fin` walks `calls` once every function is known: a name missing from `funcs` is `undefined function`, a value count that differs from `funargs` is `wrong argument count`, and otherwise the displacement is written like a jump's. Calls have their own list because the jumps of a function are dropped from `fixs` at its `end`, while a call may refer to a function defined later.

Because the callee saves all six variable registers whether it uses them or not, the caller emits nothing but the `call`. `funcs` and `calls` are sized from the source limit like the label tables: `fn a` plus `end` is 9 bytes and `call a` is 7.

`examples/fact.ai` shows all of it; its function starts at `0x4000b5`, right after the 5-byte jump at the entry point:

```
b0:  e9 6a 00 00 00      jmp  0x11f           ; fn: skip the body
b5:  53 55 41 54 41 55 41 56 41 57            ; push rbx, rbp, r12, r13, r14, r15
bf:  48 89 c3            mov  rbx, rax        ; parameter n
...
dc:  48 89 e8            mov  rax, rbp        ; call fact m: the value m
df:  e8 d1 ff ff ff      call 0xb5
e4:  48 89 c5            mov  rbp, rax        ; as r: m is done, r takes its register
...
f4:  48 89 e8            mov  rax, rbp        ; ret r: the value
f7:  41 5f 41 5e 41 5d 41 5c 5d 5b c3         ; pop r15, r14, r13, r12, rbp, rbx ; ret
...
112: 31 c0               xor  eax, eax        ; end: return 0
114: 41 5f 41 5e 41 5d 41 5c 5d 5b c3
11f: b8 05 00 00 00      mov  eax, 5          ; top level: call fact 5
124: e8 8c ff ff ff      call 0xb5
```

## Limits

- 64 variables at top level and in each function, the size of the variable table; 6 parameters, the number of argument registers.
- Global names are limited only by the source size.
- Jumps and calls always use a 32-bit displacement, 5 bytes for `jmp` and `call` and 9 for `jz` and `jnz`.
- Every function saves and restores all six variable registers: 21 bytes of code per function and `ret`, and 56 bytes of stack per call, plus 8 per stack slot.
- A function is compiled twice, so compiling takes up to twice as long.
- Functions do not nest.
- Input 64 KiB (65536 bytes, inclusive), output 1 MiB. The input limit is checked; the output limit is safe because each source byte expands to fewer than four output bytes (`end` is the worst line: 4 bytes of source, 13 of code).
- x86-64 Linux only.
- Strings and data are read-only; the only writable memory is what `buf` reserves or the program maps itself.

## Adding a statement

A statement that takes values in `rax` and `rdi` and leaves a result in `rax` is one new row in `optab`. Anything else, like `buf`, `data`, `var`, `const`, `label`, `fn` and `end`:

1. Add a keyword check in `next`, beside the ones for `buf` and `label`.
2. Write the emitter, using `rdi` as the output cursor and leaving `rsi` after the statement. End its last token through `eol`.
3. Jump back to `next`.

Either way, document it in [language.md](language.md) and add tests in `tests/`, including one for each way it can be rejected. Make the same change in `stage1/ailc.ai`: `tests/stage1.sh` fails as long as the two compilers differ on any test.

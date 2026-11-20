# How the stage0 compiler works

`stage0/ailc.s` is the bootstrap compiler: about 2200 lines of x86-64 assembly (GNU as, Intel syntax) with no dependencies beyond Linux syscalls. It turns AIL source on stdin into a runnable ELF64 executable on stdout.

It is the seed of the bootstrap: [stage1](stage1.md) is the same compiler written in AIL, stage0 builds it the first time, and what this page says about the output holds for both.

## Pipeline

There is one pass over the top level and two over each function, and no intermediate representation.

1. Ignore `SIGPIPE`, so that writing to a closed pipe fails with an error the compiler can report instead of killing it. Read all of stdin into an input buffer that holds 8 MiB plus one spare byte; filling the spare byte means the source is too big.
2. Copy a 176-byte ELF header template to the start of the output buffer, which is 16 times the size of the input buffer.
3. Scan the source. For each statement, append machine code directly to the output buffer. A `use` reads another file into the input buffer behind what is there and scans it before going on.
4. Append the code for `exit(0)`.
5. Fill in the displacement of every top-level jump from the label table and of every call from the function table. Place the writable segment on the page after the code and fill in the distance to every buffer, data name and var cell, and the lengths of names used before their declaration.
6. Patch the segment sizes and the address of the second segment in the header, write the buffer to stdout, exit.

Because code is emitted as it is read, an address that appears later in the source is not known yet. Jumps, calls and the names of buffers and data declared later each leave four empty bytes and an entry in a fixup list. The jumps of a function are filled in at its `end`, once all its labels are known, and the rest in step 5.

## Units

The input buffer holds the source from stdin and, behind it, every file named by a `use`, each read whole at `srcend` when its statement is met. Names are still kept as addresses into that buffer, and every table is sized for its 8 MiB, so the files of a program share the limit.

`usedef` looks the path up in `uses`, where paths are kept as written; a hit means the file was compiled and the statement does nothing, which also ends any cycle. Otherwise it copies the path to `pathbuf` with a NUL, opens and reads the file, pushes the input cursor and the end of the current unit on `ustack`, and points both at the new bytes. `next` and the comment scanner go to `unitend` where they used to go to `fin`: it pops the stack, or finishes when it is empty. A function must end in its unit, which both the `use` and the end of a unit check, because the second pass over a function returns to a saved place in the input.

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
| `usedef`, `unitend` | `use "<path>"`: unless the path was seen, read the file behind the source read so far, remember where to go on and scan it; at the end of a unit, go on after its `use`, or to `fin` |
| `crlf` | check that a CR is followed by LF; called wherever a line may end, and for every CR in a comment |
| `tokend`, `tokchk` | check that a token is followed by a space, tab, comment or line end; `tokend` then falls into `arg` |
| `arg` | dispatch the next argument, or end the statement by calling `emit_op` |
| `num` | an integer as an argument |
| `str` | copy the literal into the output and pass its address and length (`sys`, `call`), its length (`len`) or its address |
| `strbytes`, `hexdig` | copy the bytes of a string up to its closing quote, decoding the escapes; read one hexadecimal digit |
| `atname`, `atfirst`, `addref` | the first value of `at`; refuse a number or a string there; record a fixup in `refs` |
| `ident` | a name as an argument: pass a variable, the address of a buffer or of data, the cell of a `var`, the value of a `const`, or for `len` a size; hand over to `capture` on `as`, or to `jtarget` when a jump has its operands |
| `capture` | `as <name>...`: call `emit_op` and store each result register in the cell of the `var` with that name, or else in the variable, defined if new |
| `varplace`, `emit_varmov`, `emit_mem` | where a variable lives; a `mov` between a variable and a register; a `mov` between a register and memory |
| `alloc`, `emit_frame`, `popskip` | place the variables of a function after its first pass; reserve or release its frame; how many of the pops a return leaves out |
| `defvar` | read a variable name and find it in the pool of the current scope, or add it |
| `localdef`, `clrloc` | `local <name> <size>`: a variable of the function whose value is the address of bytes in its frame; forget the locals |
| `bufdef` | `buf <name> <size>`: enter the buffer in the table of global names and reserve its bytes |
| `vardef`, `constdef` | `var <name>...` and `const <name> <number>`: enter the names with their kind and the address of a cell, or the value |
| `newglob` | refuse a name in use as a variable or a global name, else enter it in the next table slot |
| `rdname`, `rdnum`, `constname`, `sysname` | read a name that is not `as`; read an integer; read a name that must be a `const` and give its value; the same for the number of `sys`, with the table `sysnames` behind the consts |
| `datadef` | `data [<name>] <item>...`: copy the bytes into the output behind a jump, or behind the jump of the data statement just before; enter the name |
| `labdef` | `label <name>`: enter the label and the current output position in the label table |
| `jtarget` | the label name of a jump: call `emit_op`, leave room for the displacement and record a fixup |
| `fndef` | `fn <name> <parameter>...`: enter the function, emit the jump over it and its entry code, open its scope |
| `fnend` | `end`: close the innermost open block if there is one, else emit the default return, resolve the function's jumps and close its scope |
| `blkend`, `elsedef`, `blktop` | the `end` and the `else` of a block; fill in the jump recorded for the innermost block |
| `resolve` | fill in the jumps of the current scope from its labels |
| `opdptr`, `opdaddr`, `propagate`, `clrvk`, `memchk` | the access check: note what is known of a value, carry it to the variable assigned, forget it, and check or record a load or store |
| `godead`, `labasg` | the assignment check: what a `jmp` or `ret` and a `label` do to the set of assigned variables |
| `blanks`, `blank1`, `eol`, `name` | skip spaces and tabs; require at least one; check that the line ends; read a name |
| `lookup_var`, `lookup_buf`, `lookup_label`, `lookup_fn` | find a name among the variables or the labels of the current scope, the global names or the functions |
| `hhash`, `hfind`, `hadd`, `hundo`, `globdone` | the hash of names: bucket of a key, find a node, add one, remove the nodes of a first pass; make a global name findable |
| `outchk` | report `program too big` unless the output buffer has room for what is emitted before the next check |
| `emit_op` | check the operand count and emit the statement's instruction bytes; for `call`, also leave room for the displacement and record it |
| `emit_mov_rr` | emit a 64-bit `mov <register>, <register>` |
| `emit_mov` | emit `mov <argument register>, <value>` and advance `ebx` |
| `emit_lea` | emit `lea <argument register>, [rip+rel32]` with the distance left open, and advance `ebx` |
| `argidx`, `argnext` | the register row of the next value; count the value, and push it if it is a call value after the sixth |
| `fin` | emit `exit(0)`, patch the top-level jumps, the calls, the forward uses of names and the sizes, write the output |
| `err`, `err_stmt`, `err_place`, ..., `err_argc` | one stub per message, made by the macro `fail`: load the message and jump to the kind of `die` that fits |
| `die_at`, `die_name`, `die_plain`, `die_io`, `die`, `ewrite` | print `ailc: `, the place, the message and the name, and exit with status 1 or 2 |

## Output file layout

```
offset 0     ELF header            64 bytes   type ET_DYN
offset 64    program header        56 bytes   PT_LOAD, flags R+X: the whole file
offset 120   program header        56 bytes   PT_LOAD, flags R+W: cells and buffers, no file bytes
offset 176   code, strings, data   entry point
```

The output is a position-independent executable. Its addresses are distances from the start of an image that the kernel loads wherever it chooses, at a different place on each run unless address randomisation is off. There are no sections, no symbol table, no dynamic section and no relocations: no instruction contains an address, only distances to other parts of the image.

The whole file is the first segment, readable and executable but not writable: the byte at file offset `n` is at `n` in the image and the entry point is at 176. The second segment has a file size of zero and starts on the page after the code. It holds the 8-byte cells of the `var`s and of the top-level variables beyond the sixth, in the order they were made, and behind them the buffers in the order of their declaration; its memory size is the sum of both, which may be zero.

Where the second segment starts is only known when the code is complete. So everything that refers to it, and every global name that may still be declared later, is a fixup in `refs`: `fin` computes the start (`rwstart`) and writes the distances. The image must stay within `IMGMAX`, 2 GiB less one byte, so that every such distance fits a `rel32`; `fin` reports `buffers too big` otherwise.

## Code generation

**Integer argument.** `emit_mov` picks the shortest of three forms. A value below 2^32 is `mov r32, imm32` into the register for the current argument position, taken from `regtab`: 5 bytes, or 6 with a REX prefix for `r8`–`r10`; writing a 32-bit register clears the upper half. A value whose upper 33 bits are all ones is `mov r64, imm32` (`REX.W C7 /0`), which sign-extends: 7 bytes. Anything else is `mov r64, imm64` (`REX.W B8+r`): 10 bytes. `rdnum` reads the literal: decimal with a 64-bit overflow check on every digit, or up to sixteen hexadecimal digits after `0x`, negated after a `-`.

**String argument.** The bytes are placed in the code stream and jumped over. `sys` and `call` get both instructions that follow, `len` only the second and every other statement only the first:

```
jmp  over          ; E9 + 32-bit length
<string bytes>
over:
lea  <reg>, [rip - distance]
mov  <next reg>, length
```

The bytes lie just behind the `lea`, at a distance that is known as soon as the string is read, so no data section and no fixup is needed. The only patch is the jump distance, which is written when the closing quote is found. `emit_lea` emits the instruction, 7 bytes, and leaves the address of its `rel32` in `immpos`.

**Variable argument.** `mov r64, r64` from the variable's register into the argument register: `REX.W 89 /r`, 3 bytes. The x86 register numbers come from `argnum` (argument position) and `varnum` (variable index); bit 3 of each goes into the REX prefix and the low bits into the ModRM byte.

**Buffer or data argument.** `lea r64, [rip+rel32]` through `emit_lea`, with a fixup of kind 0 in `refs` whether the name is declared yet or not: a buffer is in the segment whose start is not known yet, and data is treated the same for simplicity. The length that `len` passes is an integer, `mov r32, imm32`.

**Var argument.** `mov r64, [rip+rel32]` from the cell into the argument register: `REX.W 8B /r`, 7 bytes, with a fixup of kind 3 that holds the number of the cell. `as` on a `var` stores with `mov [rip+rel32], rax` in the same way. Both are `emit_mem`.

**Const argument.** Passed like an integer.

**Data.** `data` emits the same `jmp` and bytes as a string and no `mov`. If the output cursor still stands where the previous `data` statement ended (`dataend`), no code and no label came between: the bytes are appended and the displacement of that statement's jump (`datarel`) is written again, so the run is one block. `label` clears `dataend`, because a label after data must stay the address of code.

**End of statement.** The instruction bytes of the statement, copied from its `optab` entry by `emit_op`; for `sys` that is `syscall` (`0F 05`). With `as`, they are followed by `mov <variable register>, rax` in the same 3-byte encoding.

**End of program.** `mov eax, 60` / `xor edi, edi` / `syscall`.

## Operations

Every statement except `use`, `buf`, `data`, `var`, `const`, `local`, `label`, `fn`, `else` and `end` is one row of the table `optab`: keyword, operand count, flags (two bytes) and instruction bytes. The operands are parsed by the same code as syscall arguments, so the first lands in `rax` and the second in `rdi`, the registers of argument positions 0 and 1. The instruction bytes then compute the result into `rax`, where `as` picks it up exactly as it does after a syscall.

| Statement | Emitted after the operands |
|---|---|
| `sys` | `syscall` |
| `set` | nothing |
| `add` `sub` `and` `or` `xor` | `op rax, rdi` |
| `mul` | `imul rax, rdi` |
| `div` | `xor edx, edx` / `div rdi` |
| `mod` | `xor edx, edx` / `div rdi` / `mov rax, rdx` |
| `shl` `shr` `sar` | `mov rcx, rdi` / `shl`, `shr` or `sar rax, cl` |
| `sdiv` | `cqo` / `idiv rdi` |
| `smod` | `cqo` / `idiv rdi` / `mov rax, rdx` |
| `eq` `ne` `lt` `le` `gt` `ge` | `cmp rax, rdi` / `sete` `setne` `setb` `setbe` `seta` or `setae al` / `movzx eax, al` |
| `slt` `sle` `sgt` `sge` | the same with `setl` `setle` `setg` or `setge` |
| `args` | `mov rax, rsp` |
| `len` | nothing: its operand is the length |
| `load` | `mov rax, [rax]` |
| `load4` | `mov eax, [rax]` |
| `load2` | `movzx eax, word ptr [rax]` |
| `loadb` | `movzx eax, byte ptr [rax]` |
| `at` | `add rdx, rsi` / `jc trap` / `cmp rdx, rdi` / `ja trap` / `add rax, rsi` / `jmp over` / `ud2` |
| `fadd` `fsub` `fmul` `fdiv` | `movq xmm0, rax` / `movq xmm1, rdi` / the `sd` instruction / `movq rax, xmm0` |
| `fsqrt` `itof` `ftoi` | `sqrtsd`, `cvtsi2sd`, `cvttsd2si` between `rax` and `xmm0` |
| `flt` `fle` `feq` | `ucomisd` / `seta`, `setae`, or `sete` and not parity / `movzx eax, al` |
| `xadd` | `lock xadd [rax], rdi` / `mov rax, rdi` |
| `cas` | `mov rcx, rax` / `mov rax, rdi` / `lock cmpxchg [rcx], rsi` / `sete al` / `movzx eax, al` |
| `alloc` | `mmap` of the size plus 16, the length stored in front, 0 on failure: 58 bytes |
| `free` | `munmap` of the mapping whose length lies 16 bytes before the address, unless it is 0: 19 bytes |
| `store` | `mov [rax], rdi` |
| `store4` | `mov [rax], edi` |
| `store2` | `mov [rax], di` |
| `storeb` | `mov [rax], dil` |
| `jmp` | `jmp rel32` |
| `jz` `jnz` | `test rax, rax` / `jz` or `jnz rel32` |
| `jeq` ... `jsge` | `cmp rax, rdi` / the conditional jump, `rel32` |
| `if` `ifz` | `test rax, rax` / the opposite jump, past the block |
| `ifeq` ... `ifsge` | `cmp rax, rdi` / the opposite jump, past the block |
| `call` | `call rel32` |
| `ref` | `lea rax, [rip+rel32]`, the address of the function |
| `callp` | `call rcx` |
| `ret` | `pop r15` / `pop r14` / `pop r13` / `pop r12` / `pop rbp` / `pop rbx` / `ret`, without the pops of registers the function does not use |
| `tail` | the same pops, then `jmp rel32` |

The scratch registers `rax`, `rdi`, `rcx` and `rdx` are never variable registers, and no variable is ever in `xmm0` or `xmm1`: a double lives in a general register or in memory as 64 bits and only passes through the vector registers inside one statement. So `add x 1 as x` with `x` in `rbx` is `mov rax, rbx` / `mov edi, 1` / `add rax, rdi` / `mov rbx, rax`: 14 bytes, with no attempt to use shorter forms.

A comparison uses the unsigned conditions and turns the flags into a value at once: `setcc` writes only `al`, and `movzx eax, al` clears the other 56 bits, which still hold the first operand. Nothing depends on the flags after the statement, so a comparison emits no jump and `jz` and `jnz` test the value again.

The flags say whether `as` is required (everything that produces a value), forbidden (the stores, the jumps and `ret`) or optional (`sys` and `call`), whether a label name follows the operands (the jumps), whether a function name precedes them (`call`), whether the statement needs an open function (`ret`), whether its operand is taken as a length (`len`) and whether it accesses memory (the loads and stores). `IS_TOP` (`args`) is checked in `next` like `IS_RET`, the other way round: the statement is refused inside a function, because only at top level does `rsp` still point at what the kernel passed, the top level keeping its variables in registers and cells and pushing nothing between statements. The ninth flag, `IS_AT`, is in the second byte: the first value of `at` must be a name, and `atname` passes it as two values, its address and its size, so that the row has four operands in `rax`, `rdi`, `rsi` and `rdx`. A local gives both at once; for a global name the size is a fixup of kind 2 in `refs`, which `fin` fills with the declared size of a buffer or the bytes from a data name to the end of its run. `emit_op` rejects a statement whose operand count differs from the table; `sys` is exempt and takes one to seven values, and `call` takes any number, checked against the function when the call is resolved.

## Worked example

`examples/hello.ai` writes a line and exits with status 0 only if all 12 bytes went out:

```
sys write 1 "hello world\n" as n
sub n 12 as n
sys exit n
```

It compiles to 253 bytes: the 176-byte header followed by

```
b0:  b8 01 00 00 00      mov  eax, 1          ; syscall number: write
b5:  bf 01 00 00 00      mov  edi, 1          ; fd: stdout
ba:  e9 0c 00 00 00      jmp  0xcb            ; skip the 12 string bytes
bf:  68 65 6c 6c 6f 20 77 6f 72 6c 64 0a      ; "hello world\n"
cb:  48 8d 35 ed ff ff ff   lea  rsi, [rip-19]   ; address of the string: 0xbf
d2:  ba 0c 00 00 00      mov  edx, 12         ; its length
d7:  0f 05               syscall
d9:  48 89 c3            mov  rbx, rax        ; as n: n is the first variable, rbx
dc:  48 89 d8            mov  rax, rbx        ; sub: first operand n
df:  bf 0c 00 00 00      mov  edi, 12         ; second operand
e4:  48 29 f8            sub  rax, rdi        ; the instruction bytes of sub
e7:  48 89 c3            mov  rbx, rax        ; as n
ea:  b8 3c 00 00 00      mov  eax, 60         ; syscall number: exit
ef:  48 89 df            mov  rdi, rbx        ; status: n
f2:  0f 05               syscall
f4:  b8 3c 00 00 00      mov  eax, 60         ; implicit exit(0), never reached here
f9:  31 ff               xor  edi, edi
fb:  0f 05               syscall
```

The one-line program `sys write 1 "hello world\n"` is the first seven lines plus the implicit exit: 226 bytes.

To inspect any compiled program the same way:

```
objdump -D -b binary -mi386:x86-64 -Mintel --start-address=176 build/hello
```

## Variables

The table `vars` has one 16-byte entry per variable: the address of the name inside the input buffer and its length. Names are not copied. It has two halves of 64 entries: the first for the top level, the second for the function being compiled. `ebp` counts the entries of the current half, and `lookup` searches them one by one.

Six registers hold variables: `rbx`, `rbp`, `r12`, `r13`, `r14`, `r15` (`varnum`). These are the registers that neither the `syscall` instruction (which destroys `rax`, `rcx` and `r11`) nor the argument positions use. `varplace` says where a variable lives, and `emit_varmov` emits the `mov` between it and a register: `emit_mov_rr` for a register, `emit_mem` for memory (`REX.W 8B` or `89` with a SIB byte, 8 bytes).

**Top level.** The first six variables get the registers in order of definition. Each later one gets a cell in the writable segment, numbered like the cell of a `var` and recorded in `topcell`. Nothing is reused: the top level is interleaved with functions and is compiled in one pass.

**Functions** are compiled twice. On `fn`, `fndef` saves the cursors and every table counter in `snap` and sets `pass` to 1. The first pass compiles the function as usual, with every variable in `rbx`; its code is thrown away, but it finds every error and records for each variable where the source defines it (`vfirst`) and mentions it last (`vlast`), and for each jump to a label that is already defined, a loop: the source positions of the label and of the jump (`labpos`, `loops`). At `end`, `alloc` places the variables, `fnend` restores the snapshot, sets `pass` to 2 and jumps back to `fndef`, and the second pass emits the real code.

`alloc` first stretches the ranges: a variable whose range meets a loop is in use to the end of that loop, because the next round may read it again; this repeats until nothing changes, so nested and overlapping loops are covered. Then it takes the variables in order of definition and gives each the first place, among the six registers and then the stack slots, whose previous variable was mentioned last before this one is defined (`locfree`). The result is `fnloc` and the number of slots `fnslots`.

This is safe because execution only moves backward in the source through a backward jump. If a variable is read after another one with the same place was written, the path between the two must leave the first range and come back, and every way back is a loop that meets the range and would have stretched it over the other variable.

A function with slots reserves them after its pushes (`sub rsp, 8n`) and releases them before every return (`emit_frame`); a slot is `[rsp + 8k]`.

**Locals.** `local` defines a variable of the function through `defvar` and gives it an offset among the locals in `vlocal`. Such a variable has no place of its own: `alloc` skips it, `varplace` answers with kind 3 and the distance of its bytes from `rsp`, above the slots, and `emit_varmov` turns that into `lea`. `capture` refuses to assign it. The frame is `8 * slots + locals`; the total of the locals is counted in `loccur` during a pass and kept in `fnlocal` after the first, like the slot count. `clrloc` empties `vlocal` where a function starts and after its second pass, not before `alloc` has run.

A name is only entered in the table when its `as` is reached, at the end of the statement, so `sys 1 n as n` with a new `n` is not the variable.

## Assigned variables

`asg` has one bit per variable of the current scope, set when every way to the current line has assigned it. `capture` and a parameter set the bit; `ident` reports `unassigned variable` when it reads a variable whose bit is clear.

- A jump stores `asg` in its `fixs` entry. `jmp` and `ret` then call `godead`: it saves `asg` in `jmask`, sets `dead` and sets every bit, so that code no way leads to raises no error.
- `label` calls `labasg`: the new `asg` is the old one and-ed with the mask of every jump to that name recorded so far in the scope. If the line before cannot be reached and no jump was found, the label is only reached from below, and `asg` becomes `jmask`. The result is kept in `labmask`.
- A jump to a label that is already defined must have every bit of its `labmask`; otherwise the code after the label was checked with a variable that this way does not assign.

Every way into a label is thus either part of its mask or checked against it, which is what makes one pass enough. The cost is that a jump back may be refused although no later line reads the variable. `fndef` saves `asg`, `dead` and `jmask` in `topasg` and clears them, and `fnend` restores them: the top level goes on after a function as if it were not there.

## Known addresses

To reject accesses that are provably wrong, the compiler notes what it knows of values. `opd` describes the first two values of the statement and `vk` each variable of the current scope, in 32 bytes: a kind, then a number (`K_CONST`), a global name and a number (`K_ADDR`), or the length of a string (`K_LIT`). `num`, `str` and `ident` fill `opd` as they parse; reading a variable copies its entry. `capture` calls `propagate`, which keeps knowledge through three statements only: `set` copies it, `add` and `sub` adjust the number. It recognises them by their row: no code and exactly the flag `AS_REQ` for `set`, the three instruction bytes for the other two. Anything else leaves the variable unknown, and `clrvk` forgets all variables at a label and at the end of a function.

The rows of the loads and stores carry the flag `IS_MEM`, and `emit_op` calls `memchk` for them. The last letter of the keyword gives the width (`b`, `2`, `4`, otherwise 8) and `AS_NONE` says it is a store. An access through a string is checked at once. One through a name is appended to `chks` (name, offset, width, store or load), because the name may be declared later and the run of a data name may still grow; `fin` checks them after the forward names: the offset and the width must fit the declared size of a buffer, or the bytes from a data name to the end of its run (`bufrun`, `runend`), and data takes no store.

## Buffers

The table `bufs` has the same 16-byte entries as `vars` and holds every global name: buffers, data, vars and consts. `bufkind` says which (`G_ADDR`, `G_VAR`, `G_CONST`), `bufaddr` holds 32 bits per entry and `bufsize` its length for `len`, or the value of a const. The table is sized from the source limit, since `var a b c` declares a name every two bytes; `nvars` counts the vars. `bufaddr` is not an address in memory: for a buffer it is the distance from the first buffer, for data the offset of its bytes in the file, and for a var the number of its cell, from 1. `buf` rounds the size up to 8 bytes, places the buffer behind those declared so far and adds the size to the running total `bsssz`. `fin` turns each use into a distance once it knows where the writable segment starts.

`ident` looks a name up among the variables first and the global names second. A name in neither is taken for a buffer or data declared later: `ident` passes `mov r32, 0` and appends the name, the address of that `imm32` (which `emit_mov` leaves in `immpos`) and whether the address or the length is wanted to `refs`. `fin` looks every entry up, reports `undefined variable` for a name that is still unknown or is a var or a const, and writes the value. Inside a function `defvar` accepts the name of a global other than a var, so that a variable hides it for the rest of the function; at top level it refuses. Every declaration of a global name refuses a name found in either table (`newglob`), and `as` refuses a global name unless it is a `var`, so a name always means one thing. A buffer outlives the function it is declared in, so inside a function `buf` also searches the top-level half of `vars` (`lookup_topvar`); otherwise the buffer would be hidden by, or block, a top-level variable of the same name.

## Labels and jumps

The table `labels` has the same 16-byte entries as `vars`, and `labaddr` holds for each label the output cursor at the time its `label` line was read. Labels are looked up only in this table, which makes them a separate name space. `lookup_label` searches from the entry `labbase` on, which is zero outside a function, and returns an index counted from there.

A jump is an `optab` row whose instruction bytes stop just before the 32-bit displacement: `E9` for `jmp`, and `test rax, rax` followed by `0F 84` or `0F 85` for `jz` and `jnz`. Its row has the flag `IS_JMP`. When `ident` reads a name and the statement already has all its operands, the name is the label: `jtarget` checks that the line ends, emits the row through `emit_op`, skips four bytes and appends an entry to `fixs` with the label name and the address of those four bytes. A statement with `IS_JMP` that ends without reaching `jtarget` is a syntax error.

No jump is resolved while scanning, not even a backward one. `resolve` walks `fixs` from the entry `fixbase` on, looks each name up in `labels` and writes the label address minus the address of the byte after the displacement. A name that is not found is the `undefined label` error. One path for both directions keeps the code small; the price is a linear search per jump. `fin` calls `resolve` for the top level after the `exit(0)` code is in place, and `end` calls it for a function.

Neither table can overflow: the shortest `label` line is 8 bytes and the shortest jump line is 6, so the tables are sized for a source of the largest size made only of those.

## Blocks

The `if` forms are rows flagged `IS_IF` whose bytes, like those of a jump, stop before the `rel32`; the jump is the opposite of the condition and leads past the block. When such a statement ends, `arg` pushes an entry on `blks`: the address of the `rel32` and `asg`, the variables assigned on the way past the block. No label is involved.

`end` goes to `blkend` when a block is open (`nblk` above `blkbase`, the depth at which the function began), and only otherwise ends the function. `blktop` fills in the recorded jump. The variables assigned afterwards are those of both ways there: `asg` is and-ed with the recorded mask, or replaced by it when the block ended in `jmp` or `ret`. `else` emits a `jmp` past the rest, lets the jump of the `if` land behind it, and swaps the entry: it now holds the new `rel32`, the mask at the end of the first part and whether that part was dead, while `asg` goes back to what the `if` had. `end` then merges the two parts, and if both were dead the code after it is dead too. `end` and `else` call `clrvk`, and `end` clears `dataend`, as a label does.

## Functions

`fn` and `end` are parsed on their own; `call` and `ret` are `optab` rows, so their values go through the argument parser like any operand.

**Definition.** `fndef` enters the name in `funcs` (16-byte entries like `vars`) and emits

```
jmp  after              ; E9 + rel32, so that top-level execution skips the body
entry:
push rbx / rbp / r12 / r13 / r14 / r15     ; as many of them as the function uses
sub  rsp, frame                            ; only if it has stack slots or locals
mov  <variable i>, <argument i>            ; one per parameter
```

`funaddr` gets the address of `entry` and `funargs` the number of parameters. Each parameter is defined through `defvar` like a name after `as`, and `emit_varmov` copies it from the argument position of the same index to its place. From the seventh on the value is on the stack, above the slots, the locals, the six saved registers and the return address, the last one nearest; the entry code loads it into `r11` and stores it like the others. That distance needs the number of parameters, `fnnpar`, which the first pass over the function leaves behind.

**Scope.** `fndef` saves `ebp` in `topvars`, clears it and sets `infn`, which makes `lookup_var` use the second half of `vars`. It also sets `labbase` and `fixbase` to the current ends of `labels` and `fixs`: the function's labels and jumps are stacked on top of the top-level ones collected so far. `fnend` calls `resolve` for exactly that part, then cuts both tables back to the bases and restores `ebp`. That is all that makes labels and variables local, and it is why functions do not nest: there is one saved scope.

**Return.** `ret` is a row whose one to six values land in the argument registers, the first in `rax`, and whose instruction bytes are the six `pop`s in reverse order and `ret`. They are inlined at every `ret`, without the pops of the registers the function does not use, after `add rsp, frame` when the function has a frame. `emit_op` keeps the number of values of the first `ret` of the function in `fnres` and reports `wrong result count` for a `ret` that differs. `fnend` writes the count into `funres` (1 for a function without `ret`, 6 for one that only has a `tail`, whose results are those of another function), emits `xor` for each result register (`zeroes`, `zerolen`) and the same bytes, taken from the row at `retcode`, and then fills in the jump that `fndef` left before the entry. A `ret` outside a function is rejected in `next` by the flag `IS_RET`.

**Call.** `next` reads the function name of a `call` into `callname` before the values. The values land in argument positions 0 to 5: `rax`, `rdi`, `rsi`, `rdx`, `r10`, `r8`. Every value after those is loaded into `r11`, row 7 of `regtab` and `argnum`, and pushed (`argidx`, `argnext`); `pushed` counts the bytes, `varplace` adds it to the distance of a stack slot, and `emit_op` emits `add rsp, pushed` after the `call`. At the end of the statement `emit_op` copies the row's single byte `E8`, appends the name, the address of the displacement and the number of values to `calls`, and skips four bytes. With `as`, `capture` then stores the results: it collects the names after `as` in `caps` (a variable or the cell of a var each, at most six, more than one only for `call` and `callp`), calls `emit_op`, and stores the register of value position `k` into name `k`. The number of names goes into the `calls` entry beside the number of values.

`fin` walks `calls` once every function is known: a name missing from `funcs` is `undefined function`, a value count that differs from `funargs` is `wrong argument count`, more names than `funres` is `wrong result count`, and otherwise the displacement is written like a jump's. An entry whose value count is all ones comes from `ref`: its four bytes are the `rel32` of a `lea` and get the same distance, without the checks.

**Indirect call.** `callp` is a row flagged `IS_PTR` with the bytes of `call rcx`. `argidx` sends its first value to `rcx`, row 8 of `regtab` and `argnum`, and treats the values after it as those of a call, one position lower; `argnext` and the removal of pushed values follow. Nothing is recorded, so nothing is checked. Calls have their own list because the jumps of a function are dropped from `fixs` at its `end`, while a call may refer to a function defined later.

Because the callee saves every variable register it uses, the caller emits nothing but the `call`. `alloc` counts the registers in `fnregs`; since it always takes the lowest free one, they are the first `fnregs` of the six. `fndef` copies that many pushes (`pushlen` gives the bytes) and `popskip` tells `ret`, `tail` and `end` how many bytes of the six pops to leave out. The first pass works with all six; its code is dropped.

**Tail call.** `tail` is a row with the flags of both `call` and `ret` whose bytes are the six pops and `E9`: `emit_op` releases the frame, copies the pops of the saved registers and the `jmp`, and records the displacement in `calls` like a call's, so the value count is checked the same way. More than six values are refused there, since the pushed ones would lie in the released frame.

**Large frames.** A frame of 4096 bytes or more is not reserved with one `sub`: `emit_frame` copies the template `probe`, which goes down a page at a time and touches each page with `test [rsp], rsp`, using `r11` as the counter. A stack that is too small is then found at its guard page. `funcs` and `calls` are sized from the source limit like the label tables: `fn a` plus `end` is 9 bytes and `call a` is 7.

`examples/fact.ai` shows all of it; its function starts at offset `0xb5`, right after the 5-byte jump at the entry point. It has three variables in two registers, so it saves two:

```
b0:  e9 4a 00 00 00      jmp  0xff            ; fn: skip the body
b5:  53 55               push rbx ; push rbp  ; the registers it uses
b7:  48 89 c3            mov  rbx, rax        ; parameter n
...
d4:  48 89 e8            mov  rax, rbp        ; call fact m: the value m
d7:  e8 d9 ff ff ff      call 0xb5
dc:  48 89 c5            mov  rbp, rax        ; as r: m is done, r takes its register
...
ec:  48 89 e8            mov  rax, rbp        ; ret r: the value
ef:  5d 5b c3            pop  rbp ; pop rbx ; ret
...
fa:  31 c0               xor  eax, eax        ; end: return 0
fc:  5d 5b c3
ff:  b8 05 00 00 00      mov  eax, 5          ; top level: call fact 5
104: e8 ac ff ff ff      call 0xb5
```

## Limits

- 64 variables at top level and in each function, the size of the variable table; so at most 64 parameters.
- Global names are limited only by the source size.
- Jumps and calls always use a 32-bit displacement, 5 bytes for `jmp` and `call` and 9 for `jz` and `jnz`.
- A call uses 8 bytes of stack for the return address and 8 for each register the function uses, plus 8 per stack slot and the bytes of its locals.
- A function is compiled twice, so compiling takes up to twice as long.
- Functions do not nest.
- Input 8 MiB (8388608 bytes, inclusive), all units together; see [Capacity](#capacity).
- x86-64 Linux only, and a complete executable only: no object files, no dynamic linking, and a calling convention of its own. This was evaluated and kept; the target is in every layer of the compilers, and `use` joins sources without a linker.
- Strings and data are read-only; writable memory is what `buf`, `local` and `alloc` give, or what the program maps itself.
- `alloc` is one mapping per call: at least a page and two system calls for every allocation and release.

## Finding names

Labels, functions and global names are found through one hash table; only the variables of a scope, at most 64, and the paths of `use` are searched one by one (`lookup`).

`buckets` has 2^20 entries, each the number of the first node of a chain or 0. `hnodes` holds the nodes in the order they were added: the name (an address into the input and a length), the kind (`NS_GLOB`, `NS_FN`, `NS_LABEL`, `NS_PEND`), the scope, the index in the table of that kind, the next node of the chain and the bucket. `hhash` is FNV-1a over the bytes of the name, mixed with the kind and the scope by exclusive or and folded to 20 bits. `hfind` walks the chain of the bucket and compares kind, scope, length and bytes; `hadd` puts a new node in front of its chain. `lookup_label`, `lookup_fn` and `lookup_buf` are wrappers that answer as the linear searches did: the index, or carry and the free slot of the table in `r10`.

- **Scope.** A label belongs to the function it stands in. Each `fn` takes the next number from `nscope` as `scope`, on each of its two passes, and the top level is 0. The label nodes of a finished function are never removed: no later lookup has their scope.
- **Visibility.** A global name gets its node only when its statement is complete (`globdone`), and a function when its parameter line is, as the tables counted them before.
- **Rollback.** The first pass over a function adds nodes that the second pass must not find. `fndef` saves the node count in the snapshot, and `hundo` takes the later nodes out again, last first, each being the first of its chain when its turn comes.
- **Pending labels.** A jump to a label that is not defined yet finds or adds a node of kind `NS_PEND` for the name and and-s `asg` into its mask (`HN_MASK`). `labasg` reads that mask when the label is defined, instead of searching all jumps of the scope for the name.

For two keys with the same name, a different kind or scope always gives a different bucket, because both are mixed in by exclusive or and the fold is linear over it. The comparisons of kind and scope in `hfind` can therefore never decide a lookup today; they stay so that a change of the hash cannot make names of different kinds meet. The comparison of lengths does decide: `tools/hashcol.py` finds a name and a longer one that starts with it in one bucket, and `tests/hash_collision_prefix` uses the pair.

## Errors

Every error ends the compiler through `die`, which writes one line to stderr in pieces: `ailc: `, the place, the message, the name, a line end.

- **Message.** Each has a stub made by the macro `fail`, which loads the text and its length and jumps to one of four entries: `die_at` for a fault at a place, `die_name` when the name at fault is in `r8`/`r9`, `die_plain` and `die_io` for faults without a place, the latter with exit status 2.
- **Place.** `epos` says where: 0 means the input cursor, which is where parsing stopped, in the unit `curunit`; -1 means nowhere; any other value is an address in the source. The routines that run after a line was parsed set it from the name in the entry they work on: `resolve` for an undefined label, the loops of `fin` for calls and names, and for the access checks the position that `memchk` stored in the entry. For such an address `die` finds the unit whose bytes hold it (`mainend`, `ustart`, `uendp`).
- **Line.** `die` counts the line ends from the start of the unit to the place. Nothing is counted while the source compiles, so a correct program pays nothing for it.
- **Unit.** `usedef` records where each file lies and makes it the current unit; `unitend` goes back to the unit that named it (`ucur`). A used file is printed as the path of its `use`.

The output carries no debugging information, by decision: sections and a symbol table would be the first bytes in the file that the program does not need to run.

## Capacity

Nothing in the compiler grows: every buffer has the size that the largest source needs, and the kernel only gives memory to the pages that are touched. The compiler therefore has about 700 MiB of zero-filled address space and uses a few hundred kilobytes for a small program; it does not start under a limit on address space below that (`ulimit -v`).

- **Source.** `INSZ` is 8 MiB. The read loops of stdin and of `use` stop with `source too big` when the buffer is full.
- **Tables.** Each is sized for a source of `INSZ` bytes made only of the shortest line that adds an entry, as the comments beside the `.equ` lines say, so no append is checked: `label a` is 8 bytes, `jmp a` 6, `call a` 7, a name used as a value 2. The hash has room for every global name, label, function and jump at once.
- **Output.** `OUTSZ` is 16 times `INSZ`. No line produces 16 bytes of code for each of its own: the worst are `fn a` with a frame of a page (51 bytes for 5) and the `end` of a function with six results (32 for 4). Because that is an argument and not a structure, the buffer is also checked: `outchk` reports `program too big` when fewer than `OUTGAP` (4096) bytes are left, and it runs at every statement, every value, every item of `data` and every byte of a string, between which no more than a few hundred bytes are emitted.
- **Layout.** `fin` checks that the image, from the header to the last buffer, stays within 2 GiB (`buffers too big`), since every distance in it must fit 32 bits.

The `program too big` check cannot fail while the 16-to-1 argument holds, so no test reaches it.

## Adding a statement

A statement that takes values in `rax` and `rdi` and leaves a result in `rax` is one new row in `optab`. Anything else, like `buf`, `data`, `var`, `const`, `label`, `fn` and `end`:

1. Add a keyword check in `next`, beside the ones for `buf` and `label`.
2. Write the emitter, using `rdi` as the output cursor and leaving `rsi` after the statement. End its last token through `eol`.
3. Jump back to `next`.

Either way, document it in [language.md](language.md) and add tests in `tests/`, including one for each way it can be rejected. Make the same change in `stage1/ailc.ai`: `tests/stage1.sh` fails as long as the two compilers differ on any test. A row of `optab` or of another table is written a second time in `stage1/tables.ai`, as decimal bytes, with a case in `tests/insn.cases` that checks them against an assembler's.

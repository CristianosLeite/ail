# How the compiler works

`compiler/ailc.aw` is the AIL compiler, written in AIL. It holds the declarations and the top level and names the other files with `use`: its functions in `compiler/diag.aw` (errors), `compiler/lex.aw` (input), `compiler/names.aw` (tables of names), `compiler/expr.aw` (expressions and their code) and `compiler/emit.aw` (output), and its read-only tables in `compiler/tables.aw`: about 4700 lines together, a tenth of them comments, and no dependencies beyond Linux syscalls. It turns AIL source on stdin into a runnable ELF64 executable on stdout.

It is the only compiler. It began as a translation, routine by routine, of a compiler in x86-64 assembly (`stage0/ailc.s`) that built it the first time; that one was removed on 2026-11-20 and is in the history of the repository. The directory was called `stage1` until 2026-11-20; the seeds of `seed/MANIFEST` were built from it under that name.

## Building it

The compiler is built by a released copy of itself, a seed, and then by itself:

```
tools/seed.sh build/ailc0                      # the pinned seed, checked against its SHA-256
build/ailc0 < compiler/ailc.aw > build/ailc1     # built by the seed, from the top of the repository
build/ailc1 < compiler/ailc.aw > build/ailc      # built by that: the compiler
build/ailc  < compiler/ailc.aw > build/ailc2     # built by itself
cmp build/ailc build/ailc2                     # the same file: a fixed point
```

`make` builds `build/ailc`, and `make test` builds `build/ailc2` and checks the fixed point. Three generations are needed because the seed may be an older compiler: it understands the source but may write other code for it, so `build/ailc1` behaves like the current compiler without being the same file. `build/ailc` and `build/ailc2` are both written by a compiler that behaves like the current one, and must be equal.

`seed/MANIFEST` lists the seeds, one a line: the version, the commit whose source in `compiler/` it was built from, the SHA-256 of the file and the address of the release that keeps it (`seed-<version>`, file `ailc-<version>`). The last line is the seed the build is pinned to; earlier lines stay, so that an older revision can be built with its own seed. A local copy is `seed/ailc-<version>`, which git ignores. `tools/seed.sh` writes the pinned seed to `build/ailc0`: it uses the local copy when there is one and otherwise fetches it there, with `curl`, or with `gh release download` when the release needs a login, as that of a private repository does. A copy whose checksum is not the manifest's is refused and the build stops; a fetched one is then removed. Seed 1 is the compiler as the one in assembly built it on 2026-11-20, 30796 bytes, the same file when built again by itself. Seed 2, of the same day, is the fixed point of the build that started from seed 1, 41784 bytes: the first compiler that understands expressions, `name=expression` and `while`, and that compiles the statements which only compute, compare or access memory like expressions. It is pinned so that the source of the compiler may use those forms. Seed 3, of commit 9cc44dd the same day, is the fixed point of the build that started from seed 2, 42322 bytes: it has `spawn` and `join`, async functions and `await`, and is the first seed built from the source under the names `compiler/` and `.aw`. The build is pinned to it.

The source of the compiler may only use what the pinned seed understands. A new statement is first implemented in the old language; then a seed is released and pinned; from then on the source may use the statement.

## Pipeline

There is one pass over the top level and two over each function, and no intermediate representation.

1. Ignore `SIGPIPE`, so that writing to a closed pipe fails with an error the compiler can report instead of killing it. Read all of stdin into an input buffer that holds 8 MiB plus one spare byte; filling the spare byte means the source is too big.
2. Copy a 176-byte ELF header template to the start of the output buffer, which is 16 times the size of the input buffer.
3. Scan the source. For each statement, append machine code directly to the output buffer. A `use` reads another file into the input buffer behind what is there and scans it before going on.
4. Append the code for `exit_group(0)`.
5. Fill in the displacement of every top-level jump from the label table and of every call from the function table. Place the writable segment on the page after the code and fill in the distance to every buffer, data name and var cell, and the lengths of names used before their declaration.
6. Patch the segment sizes and the address of the second segment in the header, write the buffer to stdout, exit.

Because code is emitted as it is read, an address that appears later in the source is not known yet. Jumps, calls and the names of buffers and data declared later each leave four empty bytes and an entry in a fixup list. The jumps of a function are filled in at its `end`, once all its labels are known, and the rest in step 5.

## Units

The input buffer holds the source from stdin and, behind it, every file named by a `use`, each read whole at `srcend` when its statement is met. Names are kept as addresses into that buffer, and every table is sized for its 8 MiB, so the files of a program share the limit.

`usedef` looks the path up in `uses`, where paths are kept as written; a hit means the file was compiled and the statement does nothing, which also ends any cycle. Otherwise it copies the path to `pathbuf` with a NUL, opens and reads the file, pushes the input cursor and the end of the current unit on `ustack`, and points both at the new bytes. `next` and the comment scanner go to `uend` at the end of the input they scan: it pops the stack, or finishes when it is empty. A function must end in its unit, which both the `use` and the end of a unit check, because the second pass over a function returns to a saved place in the input.

## Shape of the program

The source is seven files, joined by `use`. `compiler/ailc.aw` is the one given to the compiler: the declarations of every `var`, `const` and `buf`, then a `use` for each file of functions, then the top level, then the `use` of the tables. A used file is compiled where its `use` stands and shares every global name, so the split changes nothing in the compiled program: the functions stand in `build/ailc` in the order of the five lines, `compiler/diag.aw` (the errors), `compiler/lex.aw` (reading the input), `compiler/names.aw` (the tables of names), `compiler/expr.aw` (expressions, their code, loads and stores, and the statements compiled like expressions) and `compiler/emit.aw` (output, the checks of accesses and assignments, frames and the fixups of jumps). A function is whole in one file, because a function may not span units, and the top level stays in one file, because its states share labels and variables. Each path is written the same way everywhere, since a `use` is done once per path as written, and all of them are opened from the top of the repository.

Parsing is a state machine whose states jump to each other. Labels are local to a function in AIL, so the states are the top level of the program: `next`, `tokend`, `arg`, `num`, `str`, `ident`, `capture`, `usedef`, `uend`, `bufdef`, `localdef`, `vardef`, `constdef`, `datadef`, `labdef`, `blkend`, `elsedef`, `jtarget`, `fndef`, `fnend` and `fin`.

The top level uses the six variables `c d r f p q`, which are the ones that get registers there.

| State | Job |
|---|---|
| (start) | ignore `SIGPIPE`, read stdin, copy the header template |
| `next` | start of a statement: skip indentation, blank lines and comments, find the keyword with `kw`, go to the state of a statement parsed on its own, and for `sys` require its syscall number, for `call` read the function name, for `ret` require an open function |
| `usedef`, `uend` | `use "<path>"`: unless the path was seen, read the file behind the source read so far, remember where to go on and scan it; at the end of a unit, go on after its `use`, or to `fin` |
| `tokend`, `arg` | check the end of a token, then dispatch the next argument, or end the statement by calling `eop` |
| `num`, `str`, `ident`, `atname` | an integer; a string (its address and length for `sys` and `call`, its length for `len`, else its address); a name (a variable, the address of a buffer or of data, the cell of a `var`, the value of a `const`, or for `len` a size), handing over to `capture` on `as` or to `jtarget` when a jump has its operands; the first value of `at` |
| `capture` | `as <name>...`: call `eop` and store each result register in the cell of the `var` with that name, or else in the variable, defined if new |
| `bufdef`, `localdef`, `vardef`, `constdef`, `datadef`, `labdef` | the statements `buf`, `local`, `var`, `const`, `data` and `label` |
| `jtarget` | the label name of a jump: call `eop`, leave room for the displacement and record a fixup |
| `fndef`, `fnend` | `fn`: enter the function, emit the jump over it and its entry code, open its scope; `end`: close the innermost open block if there is one, else emit the default return, resolve the jumps and close the scope |
| `blkend`, `elsedef`, `whiledef`, `wclose` | the `end` and the `else` of a block; `while`; the test and the jump back, when its value has been read again at the end |
| `earg` | an argument that is an expression: parse it and compute it into the register of its position |
| `xarg` | a value of a statement that is compiled like an expression: parse it, compute nothing yet |
| `asgn` | `name=expression` and `name+=expression`: compute and store |
| `fin` | emit `exit_group(0)`, patch the top-level jumps, the calls, the uses of names and the sizes, write the output |

Everything else is a function:

| Function | Job |
|---|---|
| `err`, `estmt`, `eplace`, ..., `erd`, `ewr` | one function per message: set the name or drop the place if the message wants that, and call `die`; a function cannot jump out, so every error is a call that does not return |
| `die`, `ew` | print the line of an error from `epos`, `curunit` and the name in `ename`, and exit |
| `ok`, `no`, `nodup` | syntax error unless a value is not zero, or is zero; duplicate name unless a lookup found nothing |
| `pk`, `adv` | the byte at the input cursor, or 256 at the end of the input; advance the cursor |
| `ochk` | report `program too big` unless the output buffer has room for what is emitted before the next check |
| `low`, `dig`, `blank` | character classes |
| `crlf`, `blanks`, `blank1`, `eol`, `tokchk`, `name`, `rname`, `isas` | check that a CR is followed by LF; skip spaces and tabs; require at least one; check that the line ends; check that a token is followed by a space, tab, comment or line end; read a name; read one that must start with a letter; is the name `as` |
| `hexd`, `sbytes` | read one hexadecimal digit; copy the bytes of a string up to its closing quote, decoding the escapes |
| `eqn`, `same`, `look` | compare bytes; compare a table entry with the name read last; search a table |
| `vbase`, `lvar`, `ltop`, `lbuf`, `llab`, `lfn` | the lookups: a variable of the current scope or of the top level, a global name, a label, a function; they return an index, or -1 for a name that is not defined |
| `hhash`, `hfind`, `hadd`, `hundo`, `hval`, `globdone` | the hash of names, with nodes of 64 bytes: bucket of a key, find a node, add one, remove the nodes of a first pass, the index in a node, make a global name findable; `hfind` returns the node or 0, and `hval` its index or -1 |
| `gent`, `newglob`, `cname`, `sname`, `rdname`, `rdnum` | the entry of a global name; refuse a name in use, else enter it; read a name that must be a `const` and give its value; the same for the number of `sys`, with the table `sysnames` behind the consts; read a name that is not `as`; read an integer |
| `ldvar` | the `mov` that reads the cell of a `var` |
| `putn`, `getn` | write the name read last into a table entry, or read it back |
| `defvar`, `kw` | find or add a variable; find the statement row of a keyword |
| `areg`, `aidx`, `anext` | x86 register number of an argument position; the register row of the next value; count the value, and push it if it is a call value after the sixth |
| `vplace`, `vmov`, `emem`, `frame`, `popskip`, `alloc`, `clrloc` | where a variable lives, as two results, kind and value; a `mov` between a variable and a register; a `mov` between a register and memory; reserve or release the frame; how many of the pops a return leaves out; place the variables of a function after its first pass; forget the locals |
| `eb`, `e4`, `z`, `cp` | append a byte, four bytes, a gap, or a copy; a displacement is patched with `store4` |
| `mrr`, `mov`, `elea`, `eop`, `resolve` | emit `mov <register>, <register>`; `mov <argument register>, <value>`; `lea <argument register>, [rip+rel32]` with the distance left open; check the operand count and emit the instruction bytes of the statement, for `call` also the fixup; fill in the jumps of the current scope from its labels |
| `atfirst`, `addref`, `blktop` | refuse a number or a string as the first value of `at`; record a fixup in `refs`; fill in the jump of the innermost block |
| `opdp`, `opda`, `prop`, `clrvk`, `memchk`, `cp4` | the access check: note what is known of a value, carry it to the variable assigned, forget it, check or record a load or store; `cp4` copies an entry |
| `godead`, `labasg` | the assignment check: what a `jmp` or `ret` and a `label` do to the set of assigned variables |
| `excomp`, `exinit`, `exparse`, `exop`, `exprec`, `exname`, `exred`, `exfold` | [expressions](#expressions): is the token one; parse it into `ex`; read an operator; how tightly it binds; a name as a value; apply an operator to the two values on top; compute it for two numbers |
| `exnode`, `exvpush`, `exspush`, `exspop`, `exarg`, `movi`, `lear` | append a node; push a value; push and pop an operator; make the expression the next value of the statement; `mov <register>, <number>` and `lea <register>, [rip+rel32]` for any register |
| `exasg`, `exasn`, `xstore`, `defv` | is the line an assignment; compile one; keep the expression in a variable or a var; find or add the variable whose name was read last |
| `xclass`, `xcap`, `xjcond` | is the statement one that only computes, compares or accesses memory; end one that computes, at its `as`; end one that compares or tests, before its jump |
| `xaddr`, `xmload`, `xmstore`, `xmins`, `xwidth`, `erexm`, `emodm` | an address as base, index and number; end a load; end a store; the instruction of either; its width; REX, and ModRM with SIB and displacement, for a memory operand |
| `xgen`, `xop`, `xarith`, `xshift`, `xdiv`, `xcmp`, `xcmpv`, `xfin`, `xinit` | the code of an expression: walk the nodes; an operator; its four kinds; compare two values; the result into a register; an empty stack and the free registers |
| `xinreg`, `xint`, `xtarget`, `xswap` | does a variable live in a register; in that of the variable assigned; the result is being made there; the operands change places |
| `xpush`, `xpop2`, `xalloc`, `xrel`, `xtake`, `xld`, `xsrc`, `xdst`, `xmuli` | push a waiting value; take two operands off; a free register, pushing a value if none is; free one; take a certain one; load a value; how a value can be an operand; the register an operator computes in; `imul` of a variable and a number |
| `rexw`, `modrr`, `orr`, `ori`, `epush`, `epop`, `esetcc` | REX and ModRM of two registers; `op reg, reg`; `op reg, imm`; `push` and `pop`, counted in `pushed`; `setcc` and `movzx` |

Because `pk` returns 256 at the end of the input, "at the end?" and "which byte?" are one comparison.

## State

The compiler is a state machine at top level that calls functions, and a function sees no top-level variable, so everything the two share is a global `var`:

| Var | Holds |
|---|---|
| `ip`, `ie` | input cursor and end |
| `op` | output cursor |
| `ai` | index of the next argument of the statement |
| `nv` | number of variables in the current scope |
| `cur` | statement row, at its operand count |
| `ns`, `nl` | start and length of the name read last |

The counters and the saved scope are `var`s too (`nbufs`, `bsssz`, `nlabels`, `infn`, ...). `as` on one of those names writes the global, so no function may use them for a variable of its own. The buffers are `in` and `out`, `sig` for the `sigaction` structure, and the tables `vars`, `globs` (global names), `labs`, `fixs`, `funs`, `calls`, `refs` and `chks`, the knowledge tables `opd` and `vk`, `runend`, and the tables of the variable allocation (`topcell`, `vfirst`, `vlast`, `fnloc`, `vms`, `vwt`, `vdone`, `loops`). The state saved before the first pass over a function is in the vars `sip` to `sdr`. The buffers have the sizes that a source of 8 MiB needs, written out as numbers, with the input size as the const `inmax`. A table entry carries all the fields of its name: a label entry is name, length, address and what follows.

## Output file layout

```
offset 0     ELF header            64 bytes   type ET_DYN
offset 64    program header        56 bytes   PT_LOAD, flags R+X: the whole file
offset 120   program header        56 bytes   PT_LOAD, flags R+W: cells and buffers, no file bytes
offset 176   code, strings, data   entry point
```

The output is a position-independent executable. Its addresses are distances from the start of an image that the kernel loads wherever it chooses, at a different place on each run unless address randomisation is off. There are no sections, no symbol table, no dynamic section and no relocations: no instruction contains an address, only distances to other parts of the image.

The whole file is the first segment, readable and executable but not writable: the byte at file offset `n` is at `n` in the image and the entry point is at 176. The second segment has a file size of zero and starts on the page after the code. It holds the 8-byte cells of the `var`s and of the top-level variables beyond the sixth, in the order they were made, and behind them the buffers in the order of their declaration; its memory size is the sum of both, which may be zero.

Where the second segment starts is only known when the code is complete. So everything that refers to it, and every global name that may still be declared later, is a fixup in `refs`: `fin` computes the start (`rwstart`) and writes the distances. The image must stay within 2 GiB less one byte, so that every such distance fits a `rel32`; `fin` reports `buffers too big` otherwise.

## Code generation

**Integer argument.** `mov` picks the shortest of three forms. A value below 2^32 is `mov r32, imm32` into the register for the current argument position, taken from `regtab`: 5 bytes, or 6 with a REX prefix for `r8`–`r10`; writing a 32-bit register clears the upper half. A value whose upper 33 bits are all ones is `mov r64, imm32` (`REX.W C7 /0`), which sign-extends: 7 bytes. Anything else is `mov r64, imm64` (`REX.W B8+r`): 10 bytes. `rdnum` reads the literal: decimal with a 64-bit overflow check on every digit, or up to sixteen hexadecimal digits after `0x`, negated after a `-`.

**String argument.** The bytes are placed in the code stream and jumped over. `sys` and `call` get both instructions that follow, `len` only the second and every other statement only the first:

```
jmp  over          ; E9 + 32-bit length
<string bytes>
over:
lea  <reg>, [rip - distance]
mov  <next reg>, length
```

The bytes lie just behind the `lea`, at a distance that is known as soon as the string is read, so no data section and no fixup is needed. The only patch is the jump distance, which is written when the closing quote is found. `elea` emits the instruction, 7 bytes, and leaves the address of its `rel32` in `immpos`.

**Variable argument.** `mov r64, r64` from the variable's register into the argument register: `REX.W 89 /r`, 3 bytes. The x86 register numbers come from `argnum` (argument position) and `varnum` (variable index); bit 3 of each goes into the REX prefix and the low bits into the ModRM byte.

**Buffer or data argument.** `lea r64, [rip+rel32]` through `elea`, with a fixup of kind 0 in `refs` whether the name is declared yet or not: a buffer is in the segment whose start is not known yet, and data is treated the same for simplicity. The length that `len` passes is an integer, `mov r32, imm32`.

**Var argument.** `mov r64, [rip+rel32]` from the cell into the argument register: `REX.W 8B /r`, 7 bytes, with a fixup of kind 3 that holds the number of the cell. `as` on a `var` stores with `mov [rip+rel32], rax` in the same way. Both are `emem`.

**Const argument.** Passed like an integer.

**Data.** `data` emits the same `jmp` and bytes as a string and no `mov`. If the output cursor still stands where the previous `data` statement ended (`dataend`), no code and no label came between: the bytes are appended and the displacement of that statement's jump (`datarel`) is written again, so the run is one block. `label` clears `dataend`, because a label after data must stay the address of code.

**End of statement.** The instruction bytes of the statement, copied from its `optab` entry by `eop`; for `sys` that is `syscall` (`0F 05`). With `as`, they are followed by `mov <variable register>, rax` in the same 3-byte encoding.

**End of program.** `mov eax, 231` / `xor edi, edi` / `syscall`: `exit_group(0)`, which ends every thread of the process, where `exit` (60) would end only the one that reached the last line and leave a program with other threads running.

## Operations

Every statement except `use`, `buf`, `data`, `var`, `const`, `local`, `label`, `fn`, `else`, `end` and `while` is one row of the table `optab`: keyword, operand count, flags (two bytes) and instruction bytes. The operands are parsed by the same code as syscall arguments, so the first lands in `rax` and the second in `rdi`, the registers of argument positions 0 and 1. The instruction bytes then compute the result into `rax`, where `as` picks it up exactly as it does after a syscall.

That is the general way, and what the table below shows. The statements that only compute, compare or access memory (`set`, the arithmetic and the unsigned comparisons, the jumps and blocks on a value or a comparison, the loads and the stores) are compiled [like expressions](#expressions) instead, with better code, unless their line has a string; their rows are then only the keyword, the operand count and the jump.

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
| `padd` `psub` `pmul` `pdiv` | `movupd xmm0, [rdi]` / `movupd xmm1, [rsi]` / the `pd` instruction / `movupd [rax], xmm0` |
| `pmadd` | the two loads / `mulpd xmm0, xmm1` / `movupd xmm1, [rax]` / `addpd xmm1, xmm0` / `movupd [rax], xmm1` |
| `fsum` | `movq xmm0, rax` / `test rsi, rsi` / `jz` over / `addsd xmm0, [rdi]` / `add rdi, rdx` / `dec rsi` / `jnz` back / `movq rax, xmm0` |
| `fdot` | the same around `movsd xmm1, [rdi]` / `mulsd xmm1, [rsi]` / `addsd xmm0, xmm1`, both addresses stepped by 8, the count in `rdx` |
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
| `spawn` | `lea rax, [rip+rel32]` (the function), then `call rel32` (the function `spawn`) |
| `join` | `call rel32` (the function `join`) |
| `ret` | `pop r15` / `pop r14` / `pop r13` / `pop r12` / `pop rbp` / `pop rbx` / `ret`, without the pops of registers the function does not use |
| `tail` | the same pops, then `jmp rel32` |

The scratch registers `rax`, `rdi`, `rcx` and `rdx` are never variable registers, and no variable is ever in `xmm0` or `xmm1`: a double lives in a general register or in memory as 64 bits and only passes through the vector registers inside one statement. So `sdiv x 3 as x` with `x` in `rbx` is `mov rax, rbx` / `mov edi, 3` / `cqo` / `idiv rdi` / `mov rbx, rax`, with no attempt to use shorter forms; `add x 1 as x`, which is compiled like the expression, is `add rbx, 1`.

A comparison uses the unsigned conditions and turns the flags into a value at once: `setcc` writes only `al`, and `movzx eax, al` clears the other 56 bits, which still hold the first operand. Nothing depends on the flags after the statement, so a comparison emits no jump and a `jz` or `jnz` on its result tests the value again; write the comparison and the jump as one statement.

The two flag bytes are numbers in the table; this page gives the bits names. In the first byte: 1 `AS_REQ`, 2 `AS_NONE`, 4 `IS_SYS`, 8 `IS_JMP`, 16 `IS_CALL`, 32 `IS_RET`, 64 `IS_LEN`, 128 `IS_MEM`. In the second: 1 `IS_AT`, 2 `IS_REF`, 4 `IS_PTR`, 8 `IS_IF`, 16 `IS_TOP`, 32 `IS_LIB`, 64 `IS_AWT`; a new flag goes there, the first byte being full. A first byte of 255 marks a statement parsed on its own. The flags say whether `as` is required (everything that produces a value), forbidden (the stores, the jumps and `ret`) or optional (`sys` and `call`), whether a label name follows the operands (the jumps), whether a function name precedes them (`call`), whether the statement needs an open function (`ret`), whether its operand is taken as a length (`len`) and whether it accesses memory (the loads and stores). `IS_TOP` (`args`) is checked in `next` like `IS_RET`, the other way round: the statement is refused inside a function, because only at top level does `rsp` still point at what the kernel passed, the top level keeping its variables in registers and cells and pushing nothing between statements. The ninth flag, `IS_AT`, is in the second byte: the first value of `at` must be a name, and `atname` passes it as two values, its address and its size, so that the row has four operands in `rax`, `rdi`, `rsi` and `rdx`. A local gives both at once; for a global name the size is a fixup of kind 2 in `refs`, which `fin` fills with the declared size of a buffer or the bytes from a data name to the end of its run. `eop` rejects a statement whose operand count differs from the table; `sys` is exempt and takes one to seven values, and `call` takes any number, checked against the function when the call is resolved.

## Worked example

`examples/hello.aw` writes a line and exits with status 0 only if all 12 bytes went out:

```
sys write 1 "hello world\n" as n
sys exit n-12
```

It compiles to 243 bytes: the 176-byte header followed by

```
b0:  b8 01 00 00 00      mov  eax, 1          ; syscall number: write
b5:  bf 01 00 00 00      mov  edi, 1          ; fd: stdout
ba:  e9 0c 00 00 00      jmp  0xcb            ; skip the 12 string bytes
bf:  68 65 6c 6c 6f 20 77 6f 72 6c 64 0a      ; "hello world\n"
cb:  48 8d 35 ed ff ff ff   lea  rsi, [rip-19]   ; address of the string: 0xbf
d2:  ba 0c 00 00 00      mov  edx, 12         ; its length
d7:  0f 05               syscall
d9:  48 89 c3            mov  rbx, rax        ; as n: n is the first variable, rbx
dc:  b8 3c 00 00 00      mov  eax, 60         ; syscall number: exit
e1:  48 89 df            mov  rdi, rbx        ; n-12, computed in the register of
e4:  48 83 ef 0c         sub  rdi, 12         ; its position: n, then the number
e8:  0f 05               syscall
ea:  b8 e7 00 00 00      mov  eax, 231        ; implicit exit_group(0), never reached here
ef:  31 ff               xor  edi, edi
f1:  0f 05               syscall
```

The one-line program `sys write 1 "hello world\n"` is the first seven lines plus the implicit exit: 226 bytes.

To inspect any compiled program the same way:

```
objdump -D -b binary -mi386:x86-64 -Mintel --start-address=176 build/hello
```

## Variables

The table `vars` has one 16-byte entry per variable: the address of the name inside the input buffer and its length. Names are not copied. It has two halves of 64 entries: the first for the top level, the second for the function being compiled. `nv` counts the entries of the current half, and `look` searches them one by one.

Six registers hold variables: `rbx`, `rbp`, `r12`, `r13`, `r14`, `r15` (`varnum`). These are the registers that neither the `syscall` instruction (which destroys `rax`, `rcx` and `r11`) nor the argument positions use. `vplace` says where a variable lives, and `vmov` emits the `mov` between it and a register: `mrr` for a register, `emem` for memory (`REX.W 8B` or `89` with a SIB byte, 8 bytes).

**Top level.** The first six variables get the registers in order of definition. Each later one gets a cell in the writable segment, numbered like the cell of a `var` and recorded in `topcell`. Nothing is reused: the top level is interleaved with functions and is compiled in one pass.

**Functions** are compiled twice. On `fn`, `fndef` saves the cursors and every table counter in the vars `sip` to `sdr`, `snk`, `snu` and `snh` (the snapshot) and sets `pass` to 1. The first pass compiles the function as usual, with every variable in `rbx`; its code is thrown away, but it finds every error and records for each variable where the source defines it (`vfirst`) and mentions it last (`vlast`), and for each jump to a label that is already defined, a loop: the source positions of the label and of the jump (`loops`; a `labs` entry keeps the position of its label). At `end`, `alloc` places the variables, `fnend` restores the snapshot, sets `pass` to 2 and jumps back to `fndef`, and the second pass emits the real code.

`alloc` first stretches the ranges: a variable whose range meets a loop is in use to the end of that loop, because the next round may read it again; this repeats until nothing changes, so nested and overlapping loops are covered. Then it weighs the variables. The first pass noted every mention of a variable with its place in the source (`vment`, into `vms`); a mention counts 1, and 8 times that for each loop it stands in, up to 8 loops (`vwt`). For a function with more than fifty million pairs of a mention and a loop the loops are not looked at and a mention counts 1. The variables are then placed by weight, the heaviest first and of equal ones the one defined first: each gets the first place, among the six registers and then the stack slots, in which no variable placed before it is in use anywhere between its own first and last mention (`vdone` marks the ones placed). So the registers go to what the inner loops read and write, and a parameter that is read once before a loop lives on the stack; before 2026-11-20 the order was that of definition, which gave the registers to the parameters. The result is `fnloc`, the number of registers `fnregs` and the number of slots `fnslots`.

This is safe because execution only moves backward in the source through a backward jump. If a variable is read after another one with the same place was written, the path between the two must leave the first range and come back, and every way back is a loop that meets the range and would have stretched it over the other variable.

A function with slots reserves them after its pushes (`sub rsp, 8n`) and releases them before every return (`frame`); a slot is `[rsp + 8k]`. `emem` writes the distance as an assembler would: no byte for 0, one below 128, four from there, and `frame` its number in one byte below 128. The first pass, whose code is thrown away, need not write the same lengths. A store to a slot leaves a note, the distance, the register and the output position behind the store (`slotp`, `slotr`, `slotpos`); a load of that slot at that very position is a `mov` from the register, or nothing if it is the same one, so a value that one line stores and the next reads is not fetched from memory. A label, the end of a block and the two ends of a body compiled in place forget the note, as they do `xflg`: those are the places control reaches with no byte written since.

**Locals.** `local` defines a variable of the function through `defvar` and gives it an offset among the locals in `vlocal`. Such a variable has no place of its own: `alloc` skips it, `vplace` answers with kind 3 and the distance of its bytes from `rsp`, above the slots, and `vmov` turns that into `lea`. `capture` refuses to assign it. The frame is `8 * slots + locals`; the total of the locals is counted in `loccur` during a pass and kept in `fnlocal` after the first, like the slot count. `clrloc` empties `vlocal` where a function starts and after its second pass, not before `alloc` has run. The locals of a function may take 2 GiB less a page together (`buffers too big` beyond): the distance of a local is a signed 32-bit number, and before the locals lie the slots of the variables and either the values pushed for a call or the 64 bytes of the record of a task, which that page is room for.

A name is only entered in the table when its `as` is reached, at the end of the statement, so `sys 1 n as n` with a new `n` is not the variable.

## Assigned variables

`asg` has one bit per variable of the current scope, set when every way to the current line has assigned it. `capture` and a parameter set the bit; `ident` reports `unassigned variable` when it reads a variable whose bit is clear.

- A jump stores `asg` in its `fixs` entry. `jmp` and `ret` then call `godead`: it saves `asg` in `jmask`, sets `dead` and sets every bit, so that code no way leads to raises no error.
- `label` calls `labasg`: the new `asg` is the old one and-ed with the mask of every jump to that name recorded so far in the scope. If the line before cannot be reached and no jump was found, the label is only reached from below, and `asg` becomes `jmask`. The result is kept in the entry of the label, its mask.
- A jump to a label that is already defined must have every bit of that mask; otherwise the code after the label was checked with a variable that this way does not assign.

Every way into a label is thus either part of its mask or checked against it, which is what makes one pass enough. The cost is that a jump back may be refused although no later line reads the variable. `fndef` saves `asg`, `dead` and `jmask` in `tasg`, `tdead` and `tjmask` and clears them, and `fnend` restores them: the top level goes on after a function as if it were not there.

## Expressions

An argument is an expression when its token starts with a parenthesis or has, after its first byte, a byte that no name or number has (`excomp`); every other token takes the paths it always took, so a source without expressions compiles to the bytes it compiled to before. `arg` sends an expression to the state `earg`, which refuses it where a name must stand and calls `exinit`, `exparse` and `exarg`.

`exparse` reads the token with two stacks and no recursion, so that neither the depth of parentheses nor the length of an expression has a limit but the source: `exs` holds the operators and open parentheses that wait, a byte each, and `exv` the values they will take. A value read is appended to `ex` as a node and pushed on `exv`; an operator first applies (`exred`) every waiting operator that binds at least as tightly (`exprec`), which makes all of them left-associative, and a closing parenthesis applies those back to its opening. `exop` reads an operator of one or two bytes. A name is resolved by `exname` as `ident` resolves it, with the same check that a variable is assigned and the same note of its last mention.

`ex` is therefore the expression in the order a stack machine runs it: both operands of an operator stand before it, the right one directly before. A node is 32 bytes, a kind and three cells: a number; the address of a global name plus a number, with the name; a variable; the cell of a `var`; or an operator with the node of its left operand.

`exred` computes at once what needs no instruction. Two numbers under an operator become one number (`exfold`), with the arithmetic of the instructions, except a division by zero, which is left to fail when the program runs. A global name and a number under `+` or `-` become the name with another number, when that fits the displacement of an instruction. Both replace the last two nodes, so they only apply to operands that stand next to each other, which constants always do once what is inside them is computed.

An entry of `exv` also carries what is [known](#known-addresses) of the value, four cells as in `opd`: a number, or a global name and a number. A variable brings its entry of `vk`, and `exred` carries the knowledge through `+` and `-` as `prop` does for `add` and `sub`. `exarg` copies it to `opd`, so a load or store through `b+8` is checked like one through a variable that was computed with `add`.

What is left is computed by `xgen`, which walks `ex` once as a stack machine whose stack the compiler keeps: `exv`, free again once parsing is over, has an entry for every value that waits. A value that needs no instruction yet stays what its node was, a number, a variable, a `var` or an address, and costs nothing until its operator comes; a computed value is in a register, or pushed. So a number reaches its operator as a number and can be its immediate operand, and a variable is used where it lives, in its register or in memory, without a copy. That is safe because nothing in an expression assigns: a variable has the same value wherever in the expression it is read. A variable in a stack slot is addressed when it is used, with the `pushed` of that moment.

Registers come from `xfree`, a set of the scratch registers that hold no value of the statement, taken in the order of the table `xord` after the preferred one (`xalloc`). `rcx` and `rdx` are never in it: a shift counts in `rcx` and a division needs `rdx`. When no register is free, the lowest waiting value that is in one is pushed and gives up its register; `xspl` is the entry below which none is in a register, so the pushed values are the lowest and `xpop2`, which takes the two operands of an operator off the stack, pops them back in order. Every push and pop moves `pushed`, since a variable in a stack slot is addressed from `rsp`.

`xop` sends an operator to one of four routines. Each computes in the register of the left operand, or for an operator whose operands may change places in that of the right one, or loads the left operand into a new register (`xdst`); `xsrc` says how the right operand can stand in the instruction: as a register, as a number that fits 32 bits signed, or as memory. The table `xopc` has the opcodes of each operator.

| Operator | Routine | Code |
|---|---|---|
| `+ - & ^ \|` | `xarith` | `op reg, reg`, `op reg, imm` (83 with one byte, 81 with four, the form without ModRM for `rax`), `op reg, [mem]` |
| `*` | `xarith` | `imul reg, reg`, `imul reg, [mem]`, `imul reg, reg, imm`; a variable in a register times a number is that last form into a new register (`xmuli`), and times 3, 5 or 9 it is `lea reg, [v+v*2]` (or 4, 8), whose displacement is the number that the next operator adds to the product or takes from it: `xgen` gives `xmuli` its place in the list (`xgi`, `xgh`) and skips the two nodes it took along (`xgskip`), so `x=x*3+1` is one instruction |
| `<< >>` | `xshift` | by a number `shl reg, imm8` (`D1` for 1, nothing for 0), else the count goes to `rcx` and `shl reg, cl` |
| `/ %` | `xdiv` | by a power of two `shr reg, n` or `and reg, n-1`; else the left operand goes to `rax` (`xtake` moves a waiting value out of it), `xor edx, edx`, `div reg` or `div [mem]`, and for `%` `mov rax, rdx` |
| comparisons | `xcmpv` | `cmp` (`xcmp`: the left operand in the register of its variable, or loaded), then `setcc` and `movzx` on a register that an operand had for itself, or a new one |

A number that does not fit 32 bits is loaded into a register first. The encodings are the shortest ones, those an assembler writes, so the cases of `tests/insn.cases` can be written as instructions. With `x` in `rbx`, `x=(x^x>>13)*1664525+1013904223` is

```
mov  rax, rbx
shr  rax, 13
xor  rax, rbx
imul rax, rax, 1664525
add  rax, 1013904223
mov  rbx, rax
```

The last move is there because `x` is read after the first value is computed, so that value cannot be made in the register of `x`.

`xfin` moves the result to the register it is wanted in. `exarg` makes the expression the next value of the statement: it takes out of the free set the registers that hold earlier values of the statement, prefers the register of the position, and pushes around the computation `rax` and `rdx` when the expression divides (`exdm`) and they hold values, and `rcx` when it holds the address of a `callp` and the expression shifts (`exsh`).

**Statements compiled like expressions.** `add a b as x` says what `x=a+b` says, and `jlt a b l` what `jnz a<b l` says, so the compiler makes them one thing. When `next` has found the row of a statement, `xclass` says whether it only computes or compares: kind 1 is `set` and the sixteen statements whose operators an expression has (`xso` is the operator; their rows are found once, by name, and kept in `xrows`), kind 2 the statements that compare two values and jump or open a block, signed ones included, kind 3 those that test one value (`jz`, `jnz`, `if`, `ifz`, and so `while`), kinds 4 and 5 the loads and the stores. For such a statement `arg` sends every value to the state `xarg`, which parses it with `exparse` on top of the values before it, whether it is a plain name or an expression, and writes no code. A name there may still be `as`, or the label of a jump that has its values.

- Kind 1 ends at `as`: `capture` reads the name and calls `xcap`, which applies the operator of the statement to the two values with `exred`, so that constants fold and knowledge is carried as in an expression, and stores with `xstore`, the routine that `exasn` ends in. `add a b as x` and `x=a+b` are therefore the same nodes, the same target and the same bytes.
- Kinds 2 and 3 end at the label or at the end of the line, where `xjcond` runs before `eop`. For two values it computes both sides and compares them where they are (`xcmp`); for one value it brings it into a register, that of its variable if it has one, and emits `test reg, reg`. Either way it sets `xskip` to 3, which makes `eop` leave out the `cmp rax, rdi` or `test rax, rax` of the row and copy only its jump. A comparison as the whole value of a statement of kind 3 is not turned into 1 or 0 and tested: `xjcond` builds the name of the statement that compares and jumps in `exnm` (`if a<b` becomes `iflt a b`, `jnz a<b l` becomes `jlt a b l`, and `ifz` and `jz` take the opposite comparison), points `cur` at its row and goes on as for two values. So `if x*3<100` is `imul rax, rbx, 3` / `cmp rax, 100` / `jae`, and `if a<b` with both in registers is `cmp rbx, rbp` / `jae`. A comparison deeper in the value is still computed as 1 or 0.

- Kinds 4 and 5 are the loads and the stores, recognised by their rows (flagged as accessing memory, with at most three bytes of code); the width comes from the last letter of the name (`xwidth`). `xaddr` computes the address as `[base + index + number]`, the form an instruction can name: a number added or subtracted last is the number, what is then added last is the index if it is a variable that has a register, alone or times 2, 4 or 8 or shifted left by 1, 2 or 3 (`xms` holds the power of two, which `emodm` writes into the SIB byte), a name with a number gives its number, and the rest is computed into a register, which is that of a variable if the rest is one. A load ends at `as` (`xmload`): one `mov` or `movzx` from that memory into the register of the variable, or into `rax` for a variable in memory or a `var`. A store ends at the end of the line (`xmstore`): the address, then the value, written from its register, or as an immediate if it is a number that fits the instruction (any number for the narrower stores, 32 bits signed for 64). `erexm` and `emodm` write REX, ModRM, SIB and the displacement for any registers, with the cases that `rsp`/`r12` and `rbp`/`r13` need as a base. What is known of the address goes to `opd`, and `memchk` checks the access as before. So `load q-8 as v` is `mov r13, [r15-8]`, `load p+i*8+8 as x` is `mov r12, [rbx+rbp*8+8]`, `storeb s+j 1` is `lea rax, [rip+s]` / `mov byte ptr [rax+rbx], 1`.

A line that has a string is of kind 0 and is compiled the old way, values into `rax` and `rdi` and the bytes of the row after them, since a string is not a value of an expression; those lines are what still uses the instruction bytes of these rows, and the cases of `tests/insn.cases` with `"s"` check them. One difference between the spellings remains: the compiler computes an expression of numbers, so `jz 8!=4096 l` tests a constant, while `jeq 8 4096 l` compares the two numbers when it runs.

`tools/randvars.aw` checks the equivalence: it writes each random program with statements and again line for line with expressions, and the two must compile to the same file.

**Assignment.** `next` reads the name that starts a line and asks `exasg` whether `=` or an operator and `=` follows, before it looks for a statement of that name, so that an assignment is not mistaken for anything and a variable may carry the name of a statement. The state `asgn` calls `exasn`: for `x+=e` it pushes `x` as a value first, parses the right side on top of it and applies the operator, which also folds and carries knowledge as usual; then it stores as `capture` does for one name, into the cell of a `var` or into the variable, defined if it is new (`defv`, the part of `defvar` after the name is read) before the code is written, so that its place is known. A new variable of a function gets its first position one byte behind the line, after the last mention of every operand, so that `alloc` may give it the place of an operand that is done, as it does for the name after `as`.

A `var` and a variable that lives in memory are computed in `rax` and stored. A variable with a register is computed in that register where that is possible, `xtr`:

- If no variable of the expression lives in it, neither the variable itself nor one that is done and left it its place, the register holds nothing the expression reads. It joins the free registers as the preferred one, so the first value computed is computed there, and when the chain of operators stays on it the result needs no move: `y=x/2+x%8` is `mov rbp, rbx` / `shr rbp, 1` / `mov rax, rbx` / `and rax, 7` / `add rbp, rax`.
- Otherwise it holds a value that is still read, and only the last operator may write it, since a single instruction reads its operands before it writes. `xdst` does that for the last operator (`xlast`): if its left operand lives in the register, or its right one and the two may change places, it computes there at once, so `x+=1` is `add rbx, 1` and `x=y+x` is `add rbx, rbp`; else it loads the left operand there first, unless the right one is in it, as in `x=y-x`, which goes through a scratch register. `xmuli` writes the register directly.

`xtarget` notes that the result is in place (`xtin`) and takes the register out of the free ones: a number too large for an immediate would otherwise be loaded into it behind the left operand. Random programs found that; `tests/insn.cases` has the case.

## Known addresses

To reject accesses that are provably wrong, the compiler notes what it knows of values. `opd` describes the first two values of the statement and `vk` each variable of the current scope, in 32 bytes: a kind, then a number (kind 1), a global name and a number (kind 2), or the length of a string (kind 3). `num`, `str` and `ident` fill `opd` as they parse; reading a variable copies its entry. `capture` calls `prop`, which keeps knowledge through three statements only: `set` copies it, `add` and `sub` adjust the number. It recognises them by their row: no code and exactly the flag `AS_REQ` for `set`, the three instruction bytes for the other two. Anything else leaves the variable unknown, and `clrvk` forgets all variables at a label and at the end of a function.

The rows of the loads and stores carry the flag `IS_MEM`, and `eop` calls `memchk` for them. The last letter of the keyword gives the width (`b`, `2`, `4`, otherwise 8) and `AS_NONE` says it is a store. An access through a string is checked at once. One through a name is appended to `chks` (name, offset, width, store or load), because the name may be declared later and the run of a data name may still grow; `fin` checks them after the forward names: the offset and the width must fit the declared size of a buffer, or the bytes from a data name to the end of its run (`runend`, by the run number in the entry of the name), and data takes no store.

## Buffers

The table `globs` holds every global name, buffers, data, vars and consts, in entries of 48 bytes: the name and its length, an address, a size, the kind (address, var or const) and for data the number of its run. The size is the length that `len` gives, or the value of a const. The table is sized from the source limit, since `var a b c` declares a name every two bytes; `ngv` counts the cells of vars and of top-level variables. The address is not an address in memory: for a buffer it is the distance from the first buffer, for data the offset of its bytes in the file, and for a var the number of its cell, from 1. `buf` rounds the size up to 8 bytes, places the buffer behind those declared so far and adds the size to the running total `bsssz`. `fin` turns each use into a distance once it knows where the writable segment starts.

`ident` looks a name up among the variables first and the global names second. A name in neither is taken for a buffer or data declared later: `ident` passes `mov r32, 0` and appends the name, the address of that `imm32` (which `mov` leaves in `immpos`) and whether the address or the length is wanted to `refs`. `fin` looks every entry up, reports `undefined variable` for a name that is still unknown or is a var or a const, and writes the value. Inside a function `defvar` accepts the name of a global other than a var, so that a variable hides it for the rest of the function; at top level it refuses. Every declaration of a global name refuses a name found in either table (`newglob`), and `as` refuses a global name unless it is a `var`, so a name always means one thing. A buffer outlives the function it is declared in, so inside a function `buf` also searches the top-level half of `vars` (`ltop`); otherwise the buffer would be hidden by, or block, a top-level variable of the same name.

## Labels and jumps

The table `labs` has an entry of 40 bytes per label: the name and its length, the output cursor at the time its `label` line was read, the place of that line in the source, and the mask of assigned variables. Labels are found only as labels of their scope, which makes them a separate name space; `llab` returns the index of one.

A jump is an `optab` row whose instruction bytes stop just before the 32-bit displacement: `E9` for `jmp`, and `test rax, rax` followed by `0F 84` or `0F 85` for `jz` and `jnz`. Its row has the flag `IS_JMP`. When `ident` reads a name and the statement already has all its operands, the name is the label: `jtarget` checks that the line ends, emits the row through `eop`, skips four bytes and appends an entry to `fixs` with the label name and the address of those four bytes. A statement with `IS_JMP` that ends without reaching `jtarget` is a syntax error.

No jump is resolved while scanning, not even a backward one. `resolve` walks `fixs` from the entry `fixbase` on, looks each name up with `llab` and writes the label address minus the address of the byte after the displacement. A name that is not found is the `undefined label` error. One path for both directions keeps the code small. `fin` calls `resolve` for the top level after the `exit(0)` code is in place, and `end` calls it for a function.

Neither table can overflow: the shortest `label` line is 8 bytes and the shortest jump line is 6, so the tables are sized for a source of the largest size made only of those.

## Blocks

The `if` forms are rows flagged `IS_IF` whose bytes, like those of a jump, stop before the `rel32`; the jump is the opposite of the condition and leads past the block. When such a statement ends, `arg` pushes an entry of 40 bytes on `blks`: the address of the `rel32` and `asg`, the variables assigned on the way past the block. No label is involved.

`end` goes to `blkend` when a block is open (`nblk` above `blkbase`, the depth at which the function began), and only otherwise ends the function. `blktop` fills in the recorded jump. The variables assigned afterwards are those of both ways there: `asg` is and-ed with the recorded mask, or replaced by it when the block ended in `jmp` or `ret`. `else` emits a `jmp` past the rest, lets the jump of the `if` land behind it, and swaps the entry: it now holds the new `rel32`, the mask at the end of the first part and whether that part was dead, while `asg` goes back to what the `if` had. `end` then merges the two parts, and if both were dead the code after it is dead too. `end` and `else` call `clrvk`, and `end` clears `dataend`, as a label does.

**Loops.** `while` is the last of the statements parsed on their own, row 11. A loop is compiled with a test at each end, so that a round is one jump:

```
        <value>
        jz   past        ; or the opposite jump of a comparison
body:   ...
        <value>
        jnz  body        ; or the jump of the comparison
past:
```

The value stands once in the source, and the compiler has no tree to keep it in, so it reads it twice. The state `whiledef` forgets what is known of the variables and clears `dataend`, as a label does, since a jump will reach this place; notes the place of the value in the source in `wsrc` and sets `whead`; and makes the statement an `if`, so that the value is parsed and its test and jump written by the code that does it for `if`. When that statement ends, the entry pushed on `blks` takes along the output cursor behind the jump, which is the first line of the loop, and `wsrc`; an entry is 40 bytes, and those two cells are zero for an `if`.

`blkend` finds them in the entry and ends a loop instead of a block. The jump back is a way to the head like a jump back to a label, so it must have assigned what was assigned there (`unassigned variable` otherwise), unless the line cannot be reached. In the first pass over a function the loop is added to `loops`, from the place before the value to the place after `end`, so that `alloc` keeps every variable that is alive in the loop in its place to the end of it. Then `asg` becomes what it was at the head, and the source is read again from `wsrc`, with the statement now a `jnz`: `wend` is set, the cursor is kept in `wip`, and control goes to `arg`. At the end of the value `arg` goes to `wclose`, which lets `xjcond` and `eop` write the test and the jump, fills in the distance back to the first line (`wbody`), lets the jump of the head land behind it (`blktop`), and puts the cursor back after `end`. **Two comparisons.** A value of `while` that is two comparisons joined by `&`, as `(i<p)&(j<q)`, with no division in it, is not computed as 1 or 0: `xjcond` writes the first comparison with a jump of its own, taken when it does not hold, and then treats the second as the whole value. At the head both jumps go past the loop (the place of the first is kept in the 4 bytes at 16 of the `blks` entry, as its distance from the other, and `blktop` fills in both); at the end the first goes past the jump back (`xsc`, filled in by `wclose`). So a round is two compares and two jumps, where it was two `setcc`, two `movzx`, an `and` and a jump. A comparison neither traps nor assigns, so leaving the second out when the first fails cannot be told from computing both; a value with a `/` or `%`, with `|`, with three parts, and the value of an `if` or a jump are computed whole as before. Reading a value twice mentions its variables twice, the second time at an earlier place, so `exname` never moves the last mention of a variable back. A name of the value must also be what it was at the head: a variable defined in the loop hides a global name from its definition on, not before. The entry therefore keeps `nv` of the head (in the four bytes the `else` of a block uses), `blkend` puts it in `wnv`, and while `wend` is set `lvar` looks at that many variables only, so the name is found among the global names again. `else` refuses an entry of a loop.

**Where a loop starts.** The first line of a loop starts at a multiple of 64 in the file, which is one in memory too, since the file is loaded at a multiple of a page: a line of the cache, and the unit by which the processor keeps decoded instructions. `pad` writes instructions that do nothing up to there, of up to 9 bytes each from the table `nops`, the forms an assembler writes. For a `while` that is behind the jump of its head, which is where `arg` then notes the first line in `blks`; the padding runs once when the loop is entered. For a loop written with a label, the label is padded if a jump of the first pass went back to it: `jtarget` sets a byte of `lback` for the number of the label, which is the same in both passes, and `labdef` reads and clears it in the second. That needs two passes, so a label of the top level stays where it is, and so does one in a body compiled in place. The bytes of padding in a function are counted in `fnpad` and left out of the limit `inlsz`, so that whether a function is compiled in place does not depend on where it stands. Without it the time of a short loop moved by a fifth, and of one by more than a third, with a few bytes more or less before it ([measurements](performance.md#the-place-of-a-loop-2026-11-21)).

**A mask as a condition.** A statement of kind 3 whose value ends in `&` with a number, or in `%` with a power of two, does not compute it: `xjcond` computes the left side only and writes `test` on it with the mask, on the low byte for a mask below 256 (`test bl, 1`; with a REX prefix from `spl` on, and the short form for `al`), on 32 bits for one that fits them, and the general way for a larger one. `if x%2` is `test r12b, 1` and a jump.

**The zero flag.** `add`, `sub`, `and`, `or`, `xor` and a shift by a number leave the zero flag saying whether their result is zero, which is what `test reg, reg` would find out. `xarith` and `xshift` note the register of the result and the output cursor behind the instruction in `xflg` and `xflgpos`; `xjcond`, about to test a value in a register, leaves the `test` out when that register is the one noted and the cursor has not moved. So `i-=1` followed by the end of a `while i`, or by `jnz i top`, is `sub rbx, 1` / `jnz`. A place that control reaches from elsewhere without a byte being written there would break that, so a label and the end of a block forget the note; every other such place writes a jump first. That is also why a loop tests at its head instead of jumping to the test at its end: the test at the end is then reached only from the line before it.

## Functions

`fn` and `end` are parsed on their own; `call` and `ret` are `optab` rows, so their values go through the argument parser like any operand.

**Definition.** `fndef` enters the name in `funs` (40 bytes: name, length, entry, parameters, results) and emits

```
jmp  after              ; E9 + rel32, so that top-level execution skips the body
entry:
push rbx / rbp / r12 / r13 / r14 / r15     ; as many of them as the function uses
sub  rsp, frame                            ; only if it has stack slots or locals
mov  <variable i>, <argument i>            ; one per parameter
```

The entry gets the address of `entry` and the number of parameters. Each parameter is defined through `defvar` like a name after `as`, and `vmov` copies it from the argument position of the same index to its place. From the seventh on the value is on the stack, above the slots, the locals, the six saved registers and the return address, the last one nearest; the entry code loads it into `r11` and stores it like the others. That distance needs the number of parameters, `fnnpar`, which the first pass over the function leaves behind.

**Scope.** `fndef` saves `nv` in `topvars`, clears it and sets `infn`, which makes `lvar` use the second half of `vars`. It also sets `labbase` and `fixbase` to the current ends of `labs` and `fixs`: the function's labels and jumps are stacked on top of the top-level ones collected so far. `fnend` calls `resolve` for exactly that part, then cuts both tables back to the bases and restores `nv`. That is all that makes labels and variables local, and it is why functions do not nest: there is one saved scope.

**Return.** `ret` is a row whose one to six values land in the argument registers, the first in `rax`, and whose instruction bytes are the six `pop`s in reverse order and `ret`. They are inlined at every `ret`, without the pops of the registers the function does not use, after `add rsp, frame` when the function has a frame. `eop` keeps the number of values of the first `ret` of the function in `fnres` and reports `wrong result count` for a `ret` that differs. `fnend` writes the count into the entry of the function (1 for a function without `ret`, 0 for one that only has a `tail`, whose results are those of another function and are found in `fin`), emits `xor` for each result register (`zeroes`, `zerolen`) and the same bytes, from `retc`, and then fills in the jump that `fndef` left before the entry. A `ret` outside a function is rejected in `next` by the flag `IS_RET`.

**The results of a tail.** The entry of `calls` that a `tail` makes has, where a call has the number of names after `as`, the number of the function it stands in with the bit 31 set. Before `fin` checks the calls, `tailres` gives the functions with the count 0 theirs: it puts every tail in the list of its target (`tails`, 8 bytes: the function it stands in and the next tail to the same target; the head of the list is at 36 of the target's entry in `funs`), then takes each function with a known count from a stack (`tailq`) and writes the count into the functions that tail to it and have none, which go on the stack in turn. A function is on the stack once, so the time grows with the number of functions and tails, whatever the order of a chain. A function still at 0 reaches no `ret` on any way: it never returns, and `fin` lets a call name up to six results of it. For a tail `fin` then requires the count of the target to be that of the function it stands in, unless the target never returns, and reports `wrong result count` with the name of the target.

**Call.** `next` reads the function name of a `call` into `cn` and `cl` before the values. The values land in argument positions 0 to 5: `rax`, `rdi`, `rsi`, `rdx`, `r10`, `r8`. Every value after those is loaded into `r11`, row 7 of `regtab` and `argnum`, and pushed (`aidx`, `anext`); `pushed` counts the bytes, `vplace` adds it to the distance of a stack slot, and `eop` emits `add rsp, pushed` after the `call`. At the end of the statement `eop` copies the row's single byte `E8`, appends the name, the address of the displacement and the number of values to `calls`, and skips four bytes. With `as`, `capture` then stores the results: it collects the names after `as` in `caps` (a variable or the cell of a var each, at most six, more than one only for `call` and `callp`), calls `eop`, and stores the register of value position `k` into name `k`. The number of names goes into the `calls` entry beside the number of values.

`fin` walks `calls` once every function is known: a name missing from `funs` is `undefined function`, a value count that differs from the parameters is `wrong argument count`, more names than results is `wrong result count`, and otherwise the displacement is written like a jump's. An entry whose value count is all ones comes from `ref`: its four bytes are the `rel32` of a `lea` and get the same distance, without the checks.

**A call compiled in place.** A `call` in a function, of a short function that stands before it, is not a `call` instruction: the body of that function is read again from the source, as lines of the function with the call. There is no tree to copy, so the input cursor goes to the callee and comes back, as it does for the value of a `while`.

- *Which functions.* At the end of its second pass (`e1`) a function is found fit and gets an entry in `finl` (where its parameters stand in the source, its variables, and the mask `fnwr` of those it assigns after its entry). Its code, entry and returns included and the padding before its loops left out, is at most `inlsz` bytes, 160; it has at most six parameters, no `local`, no `tail`, no variable without a register (`fnslots` is 0: a body that needs more than six places at once takes them from its caller, and `sortsift` was 7% slower in place), is no task, and its body declares no global name (no `buf`, no `data`). A body may call, and may name a `buf`, `data` or `var`: each such line adds an entry to `calls`, `refs` or `chks`, tables sized from the source limit for a body that is read once, so the entry of `finl` (48 bytes) also says how many entries the body adds to each, and `inlchk` refuses a call in place where one of the three would pass its capacity; the call is then a call. `labs`, `fixs`, `blks` and the nodes of the hash are cut back at the end of each body, and `vment` stops noting at the room of `vms`.
- *Bodies in bodies.* A function with a call compiled in place is fit like any other, so a body may be read inside a body, up to four in one another (`ildp`); a fifth is a call. `inlopen` puts what the outer body's call goes on with, the `il*` variables, `vlo`, `ilcaps` and `ilvk`, into `ilstk` (2304 bytes a depth, `ilpush`), and `inlclose` takes it back (`ilpop`). Mentions count at the call of the outermost body (`ilpos` is kept), and `ildep` goes on counting. A parameter handed on untouched is the variable of the outermost caller at every depth, since `lvar` gave the inner call the number it stands for. What must hold is that both passes, and every place a body is read, decide alike or more carefully: in a body only a function that stands before the one of the body is compiled in place (`ilfn`), since that one was complete, fit or not, when the body's function was compiled, where a later one was an unknown name and a call; the entry of `finl` has the variables the function had at once with its bodies (`vhi`), so room for the outer body is room for the inner ones; and its count for `calls` has one more for each call it compiled in place (`ilcnt`), since where the body is read again deeper, or with the tables fuller, such a call may be refused and written as a call.
- *Which calls.* `inlchk`, asked where `eop` would write the call (`a1`, `cp4`), wants a plain `call` in a function that is no task, the number of values that the callee has parameters, no more names than it has results, and room for its variables: `nv` plus those of the callee is 64 at most. Any other call is written as before, so the checks of `fin` are unchanged.
- *Variables.* `inlopen` keeps what the statement goes on with (the cursor, `cur`, the names after `as`, `asg`, `dead`, `jmask`, the bases of blocks, labels and jumps, the scope of the hash, what `vk` knows) and sets `vlo` to `nv`: `lvar` looks from there, so the body sees its own variables and no variable of the caller, which may have the same names. The values are already in the registers of a call, and each parameter is defined from its register as `fndef` does. A parameter that the body never assigns (`fnwr`), given a variable by itself (`ilnote` in `ident`, `ilpl`, `ilarg`), is that variable under another name: its entry in `vars` has the caller's number in `valias`, which `lvar` returns, and no code. If every parameter is such, the output cursor goes back to where the statement began (`ilop`) and the loads of the values are gone. At the end `nv` goes back, so the numbers are used again by what the caller defines next and by the next body; `vhi` is how many the function had at once, and `alloc` works on that many.
- *Places.* Every mention in the body counts as made at the call (`vpos`, `ilpos`), after the values and before the line that follows, so `alloc` needs no other order than that of the source: a variable of the caller that is read later is in use across that place, one that was only a value of the call is done before it. A number that only bodies had (`vinl` 1) is in use at single places and is not stretched to the end of a loop around the call, since a body assigns its variables before it reads them; a number that both a body and the caller had is one variable from its first place to its last. A `while` of the body is no entry of `loops`, and neither is a jump back to one of its labels, since that table is sized for a source read once: the mentions note how many whiles are open (`ildep`, two bits of the entry in `vms`), which weighs them as a loop would.
- *Return.* A `ret` in the body (`eop`) leaves its values in the registers and writes a `jmp` to the end of the body, each `rel32` holding the place of the one before (`ilret`) until `inlclose` fills them in; a jump that would be the last instruction of the body is taken back. If the last line is reached, `zeroes` gives each result 0. Then `resolve` fills in the jumps to the labels of the body, which have a scope of their own, and the statement goes on at `cp5`, which stores the registers into the names after `as`.
- *Errors.* The body was compiled where it stands, so it has no error left; `eunasg` and `eunasgj` return inside one, since `asg` is not kept exact there.

**Tasks.** `spawn` and `join` are rows flagged `IS_LIB`: the function they call is the one of the program named like the keyword, so the compiler holds no code of the tasks and a program that has the statements defines the functions, with `use "lib/task.aw"`. `next` keeps the keyword's place in the source in `kwn` and `kwl`, and `eop` makes it the name of the call entry, so an `undefined function spawn` has the line of the statement. `join` is otherwise a `call`: values from position 0, the count checked against the one parameter of `join`. `spawn` has `IS_REF` as well: `next` reads a function name into `cn` and `cl` as for `ref` and starts the values at position 1 (`rdi`), leaving `rax` for the address. `eop` copies the row, `lea rax, [rip+rel32]`, and records it in `calls` with the number of values, where `ref` records all ones, so `fin` reports `wrong argument count` for the function of the task; then it writes `call rel32` with an entry of all ones, since the function `spawn` takes the address and five values whether or not the statement gave five (a register that was not set holds a value that the task's function does not read). More than five values are `wrong operand count`.

**Async functions.** `async` is the statement parsed on its own with the number 12: `asydef` keeps the place of the word in `asyn` and `asyl`, requires `fn` after it, sets `fnasy` and enters `fndef`; `fnend` clears `fnasy` after the second pass. Such a function is compiled as the poll function of a task of `lib/async/task.aw`, and three things differ from a plain one.

- *Places.* `alloc` starts its search behind the six registers (`j=fnasy*6`), so every variable gets a slot, reused by lifetime as stack slots are; `vplace` returns the slot as a distance from the record of the task, 64 bytes of record first and the locals behind the slots, and adds no `pushed`; `emem` writes kind 2 as `[rbx+disp8]`, or `disp32` from 128 on; `frame` writes nothing. Every memory operand of a variable goes through `emem`, so nothing else changes. `rbx` holds the record and no expression register is `rbx`.
- *Entry.* `asyent` writes two pieces where a function has its pushes. The address in `funs` is the first, the code a call runs: it pushes the parameters (the count of the first pass, at most six), the last first, loads the size of the record, `64 + 8 * fnslots + fnlocal`, and the address of the second piece, calls the function `async` of the program through an entry of `calls` that carries the place of the word, as an `IS_LIB` row does, and, unless the result is 0, pops each parameter into its slot (`asytst`), the first first; then `ret`. The order matters: a parameter that is never mentioned is done where it is defined, so `alloc` gives its slot to the next one, and of two parameters with one slot the later must be stored last. So a `call` is unchanged and so are its checks. The second piece is the poll function (`asypoll`): `push rbx`, `mov rbx, rax`, then a jump to the address at 8 of the record if there is one, and into the body if not. The loop that reads the parameters defines them and emits nothing.
- *Await.* `await` is a row flagged `IS_CALL`, `IS_LIB` and `IS_AWT`, without bytes. `next` looks at its first word: a name that is neither a variable (`lvar`) nor a global name (`lbuf`) is a function, kept in `cn` and `cl` with `awf` set, as for a `call`; anything else is the handle, an ordinary value. `eop` writes, for a function, its `call` with an entry of `calls` that carries the count of the values and one result, and takes the pushed values off the stack at once, since the task may return in this statement. The handle is now in `rax`. Outside an async function `xor edi, edi` and the call of the program's function `await` follow, an entry named by the keyword with two values. In an async function the call is inside `asyawt` and `asysus`: the handle goes to 48 of the record, the address of the next instruction to 8, and that instruction, where a later poll enters, loads the handle again, passes the record in `rdi` and calls; if the second result is 0 the poll function returns 0, with its `pop rbx`, and else the first result is in `rax` for `as`. A statement boundary has nothing pushed and every variable in the record, which is why a task can leave and enter there; nothing is saved or restored. `capture` allows several names on a call, so `eop` refuses a second one here.
- *Return.* `ret` copies `asyret` in `eop`: the value to 16 of the record, `mov eax, 1`, `pop rbx`, `ret`; `fnend` writes the same after `xor eax, eax`. The function has one result in `funs`, the handle.

**Indirect call.** `callp` is a row flagged `IS_PTR` with the bytes of `call rcx`. `aidx` sends its first value to `rcx`, row 8 of `regtab` and `argnum`, and treats the values after it as those of a call, one position lower; `anext` and the removal of pushed values follow. Nothing is recorded, so nothing is checked. Calls have their own list because the jumps of a function are dropped from `fixs` at its `end`, while a call may refer to a function defined later.

Because the callee saves every variable register it uses, the caller emits nothing but the `call`. `alloc` counts the registers in `fnregs`; since it always takes the lowest free one, they are the first `fnregs` of the six. `fndef` copies that many pushes (`pushlen` gives the bytes) and `popskip` tells `ret`, `tail` and `end` how many bytes of the six pops to leave out. The first pass works with all six; its code is dropped.

**Tail call.** `tail` is a row with the flags of both `call` and `ret` whose bytes are the six pops and `E9`: `eop` releases the frame, copies the pops of the saved registers and the `jmp`, and records the displacement in `calls` like a call's, so the value count is checked the same way. More than six values are refused there, since the pushed ones would lie in the released frame. In a function with a `local` (`fnlocal`, known from the first pass) the frame must outlive the callee, which may hold the address of the local: `eop` writes `E8` with the same entry of `calls`, then the release of the frame, the pops and `ret` from `retc`, and nothing zeroes the result registers, so every result of the callee is returned.

**Large frames.** A frame of 4096 bytes or more is not reserved with one `sub`: `frame` copies the template `probe`, which goes down a page at a time and touches each page with `test [rsp], rsp`, using `r11` as the counter. A stack that is too small is then found at its guard page. `funs` and `calls` are sized from the source limit like the label tables: `fn a` plus `end` is 9 bytes and `call a` is 7.

`examples/fact.aw` shows all of it; its function starts at offset `0xb5`, right after the 5-byte jump at the entry point. It has two variables, the parameter `n` and the result `r` of the call, and saves a register for each:

```
b0:  e9 34 00 00 00      jmp  0xe9            ; fn: skip the body
b5:  53 55               push rbx ; push rbp  ; the registers it uses
b7:  48 89 c3            mov  rbx, rax        ; parameter n
ba:  48 85 db            test rbx, rbx        ; ifz n
bd:  0f 85 08 00 00 00   jne  0xcb
c3:  b8 01 00 00 00      mov  eax, 1          ; ret 1
c8:  5d 5b c3            pop  rbp ; pop rbx ; ret
cb:  48 89 d8            mov  rax, rbx        ; call fact n-1: the value, in the
ce:  48 83 e8 01         sub  rax, 1          ; register of its position
d2:  e8 de ff ff ff      call 0xb5
d7:  48 89 c5            mov  rbp, rax        ; as r
da:  48 89 d8            mov  rax, rbx        ; ret n*r
dd:  48 0f af c5         imul rax, rbp
e1:  5d 5b c3            pop  rbp ; pop rbx ; ret
e4:  31 c0               xor  eax, eax        ; end: return 0
e6:  5d 5b c3
e9:  b8 05 00 00 00      mov  eax, 5          ; top level: call fact 5
ee:  e8 c2 ff ff ff      call 0xb5
```

## Limits

- 64 variables at top level and in each function, the size of the variable table; so at most 64 parameters.
- Global names are limited only by the source size.
- Jumps and calls always use a 32-bit displacement, 5 bytes for `jmp` and `call` and 9 for `jz` and `jnz`.
- A call uses 8 bytes of stack for the return address and 8 for each register the function uses, plus 8 per stack slot and the bytes of its locals.
- A function is compiled twice, so compiling takes up to twice as long.
- Functions do not nest.
- Input 8 MiB (8388608 bytes, inclusive), all units together; see [Capacity](#capacity).
- x86-64 Linux only, and a complete executable only: no object files, no dynamic linking, and a calling convention of its own. This was evaluated and kept; the target is in every layer of the compiler, and `use` joins sources without a linker.
- Strings and data are read-only; writable memory is what `buf`, `local` and `alloc` give, or what the program maps itself.
- `alloc` is one mapping per call: at least a page and two system calls for every allocation and release.

## Finding names

Labels, functions and global names are found through one hash table; only the variables of a scope, at most 64, and the paths of `use` are searched one by one (`look`).

`buckets` has 2^20 entries, each the number of the first node of a chain or 0. `hnodes` holds the nodes in the order they were added: the name (an address into the input and a length), the kind (a global name, a function, a label, or a label that is not defined yet), the scope, the index in the table of that kind, the next node of the chain and the bucket. `hhash` is FNV-1a over the bytes of the name, mixed with the kind and the scope by exclusive or and folded to 20 bits. `hfind` walks the chain of the bucket and compares kind, scope, length and bytes; `hadd` puts a new node in front of its chain. `llab`, `lfn` and `lbuf` are wrappers that return the index, or -1.

- **Scope.** A label belongs to the function it stands in. Each `fn` takes the next number from `nscope` as `scope`, on each of its two passes, and the top level is 0. The label nodes of a finished function are never removed: no later lookup has their scope.
- **Visibility.** A global name gets its node only when its statement is complete (`globdone`), and a function when its parameter line is, as the tables counted them before.
- **Rollback.** The first pass over a function adds nodes that the second pass must not find. `fndef` saves the node count in the snapshot, and `hundo` takes the later nodes out again, last first, each being the first of its chain when its turn comes.
- **Pending labels.** A jump to a label that is not defined yet finds or adds a pending node for the name and and-s `asg` into its mask. `labasg` reads that mask when the label is defined, instead of searching all jumps of the scope for the name.

For two keys with the same name, a different kind or scope always gives a different bucket, because both are mixed in by exclusive or and the fold is linear over it. The comparisons of kind and scope in `hfind` can therefore never decide a lookup today; they stay so that a change of the hash cannot make names of different kinds meet. The comparison of lengths does decide: `tools/hashcol.aw` (`build/tools/hashcol` after `make tools`) finds a name and a longer one that starts with it in one bucket, and `tests/hash_collision_prefix` uses the pair.

## Errors

Every error ends the compiler through `die`, which writes one line to stderr in pieces: `ailc: `, the place, the message, the name, a line end.

- **Message.** Each has a function of three lines (`err`, `estmt`, `eplace`, ...) that sets the name at fault in `ename` and `enamel` if the message has one, sets `epos` to -1 if it has no place, and calls `die` with the text and the exit status, 1, or 2 for `read error` and `write error`. A function cannot jump out, so every error is a call that does not return.
- **Place.** `epos` says where: 0 means the input cursor, which is where parsing stopped, in the unit `curunit`; -1 means nowhere; any other value is an address in the source. The routines that run after a line was parsed set it from the name in the entry they work on: `resolve` for an undefined label, the loops of `fin` for calls and names, and for the access checks the position that `memchk` stored in the entry. For such an address `die` finds the unit whose bytes hold it (`mainend`, `ustart`, `uendp`).
- **Line.** `die` counts the line ends from the start of the unit to the place. Nothing is counted while the source compiles, so a correct program pays nothing for it.
- **Unit.** `usedef` records where each file lies and makes it the current unit; `uend` goes back to the unit that named it (`ucur`). A used file is printed as the path of its `use`.

The output carries no debugging information, by decision: sections and a symbol table would be the first bytes in the file that the program does not need to run.

## Capacity

Nothing in the compiler grows: every buffer has the size that the largest source needs, and the kernel only gives memory to the pages that are touched. The compiler therefore has about 1.6 GiB of zero-filled address space and uses a few hundred kilobytes for a small program; it does not start under a limit on address space below that (`ulimit -v`).

- **Source.** The limit is 8 MiB; `inmax` is one byte more, the size of the input buffer. The read loops of stdin and of `use` stop with `source too big` when the buffer is full.
- **Tables.** Each is sized for a source of 8 MiB made only of the shortest line that adds an entry, as the comment beside each `buf` says, so no append is checked: `label a` is 8 bytes, `jmp a` 6, `await a` 8 for two entries of `calls`, a name used as a value 2. The hash has room for every global name, label, function and jump at once.
- **Output.** `out` is 16 times the source limit. No line produces 16 bytes of code for each of its own: the worst are `fn a` with a frame of a page (51 bytes for 5) and the `end` of a function with six results (32 for 4). Because that is an argument and not a structure, the buffer is also checked: `ochk` reports `program too big` when fewer than 4096 bytes are left, and it runs at every statement, every value, every item of `data` and every byte of a string, between which no more than a few hundred bytes are emitted.
- **Layout.** `fin` checks that the image, from the header to the last buffer, stays within 2 GiB (`buffers too big`), since every distance in it must fit 32 bits.

The `program too big` check cannot fail while the 16-to-1 argument holds, so no test reaches it.

## Read-only tables

The tables are `data` statements in a file of their own, `compiler/tables.aw`, which the last line of `compiler/ailc.aw` names with `use "compiler/tables.aw"`. The path is relative to the directory the compiler runs in, so the compiler is compiled from the top of the repository, as the Makefile does. The tables stand after the code that uses them, : `hdr`, `optab`, `sysnames`, `fnpush`, `zeroes`, `zerolen`, `pushlen`, `probe`, `regtab`, `argnum`, `varnum`, `exit0`, `exkw` (the names of the comparisons), `xopc` (the opcodes of the operators of an expression) and `xord` (the order in which registers are taken), and `retc`, the code of `ret`.  A table is a run of `data` lines, one row a line, with the name on the first.

The file is the definition of the tables. It was first printed from the bytes that the compiler in assembly assembled to; now a row is edited here. A row is decimal bytes, which no one reads as instructions, so two checks stand where the generator stood. `tests/tables.sh` checks the form: every length is that of its name or code, no statement or syscall name occurs twice, the flags are ones that exist, the two tables with rows end, the others have their size, and each syscall number is the one in a list of the script's own. `tests/insn.sh` checks the bytes: `tests/insn.cases` has a line for every row of the statement table and for the other tables, with a source, the code it must compile to in hex, and the same code as instructions. The hex is what GNU `as` writes for the instructions (`tests/insn.sh hex '<instructions>'` prints it and `tests/insn.sh asm` checks the two columns), so the expected bytes do not come from the compiler; the run in `make test` needs no assembler.

The statement table has each row as its name length, its name as a string, the operand count, the two flag bytes, the code length and the code. Its last eleven rows have the flags 255 and no code: they are the statements parsed on their own, and the operand count of such a row says which (1 `fn`, 2 `buf`, 3 `end`, 4 `label`, 5 `data`, 6 `var`, 7 `const`, 8 `local`, 9 `use`, 10 `else`, 11 `while`), so `next` finds every keyword with the one search `kw`.

## How the source is written

The states of the top level are labels and jump to each other. The source is written with expressions since seed 2 was pinned: `tools/infix.py`, since ported to AIL as `tools/infix.aw`, rewrote it on 2026-11-20, spelling 1849 statements as assignments, turning 12 label loops into `while` and folding 725 variables that were read once into the line that read them. That took it from 25635 tokens to 20172 without comments, 21% fewer, and from 4888 lines of code to 4140; the compiler it compiles to is 39217 bytes where the statement-written source gave 41784, since a folded value needs no variable to pass through. Inside a state and inside the functions, a test with its consequence is written as a block (`ifz d` ... `end`) and a comparison with its jump as one statement (`jeq c 10 n1`). `tools/fuse.py`, since ported to AIL as `tools/fuse.aw`, made that change mechanically from the version with `eq`/`jnz` pairs: it fuses a pair only when the result of the comparison is not read on any path afterwards, turns a forward jump to a label that nothing else uses into a block when the region is short and nests, and leaves the state labels alone. It removed 138 lines and about 9% of the tokens.

- A decimal literal is checked for overflow before the multiplication: `rdnum` refuses a value above 0x1999999999999999 (2^64 / 10, rounded down), or equal to it with a digit above 5.
- A negative syscall result is tested unsigned: a `read` result above the buffer size is an error, and a `write` result is good when `result - 1` is below the bytes left.
- The order of the checks in a routine decides which message a source with two faults gets, and the tests fix it.

## Tests

The compiler was first checked by comparing it with the one in assembly on every test, on random sources and at the fixed point. Without that one the suite stands on four things. The tests say what a program must print and how every faulty source must be refused. `tests/insn.sh` and `tests/bytes.sh` compare emitted bytes with bytes that no compiler wrote. `tools/randvars.aw` runs random programs whose result it computed from the tree, each written from one tree as statements with labels and jumps and as expressions with `while` and `if` on a value; since the compiler compiles that tool, `tests/randvars.sh` replays programs whose result Python computed. And the compiler is compared with itself: `build/ailc1` and `build/ailc` are one source in two translations, by the seed and by the compiler the seed built, so `tests/self.sh` requires the same output, message and status from both for every test source and example, and `tests/fuzz.sh` for random edits of them, which must also end properly (status 0 with an executable, or status 1 with one message line). A compiler that miscompiles itself shows there as a difference between the two, and at the fixed point `build/ailc` = `build/ailc2`.

## Adding a statement

A statement that takes values in `rax` and `rdi` and leaves a result in `rax` is one new row of `optab` in `compiler/tables.aw`: write the instructions, take their bytes from `tests/insn.sh hex`, and add the case to `tests/insn.cases`. Anything else, like `buf`, `data`, `var`, `const`, `label`, `fn` and `end`:

1. Add a row with the flags 255 and the next number, and a `jeq` for that number in `next`; a number without one falls into `whiledef`.
2. Write the state: it reads from `ip`, appends at `op`, and ends its last token through `eol`.
3. Jump back to `next`.

Anything a statement adds to the state of the compiler inside a function must be in the snapshot that `fndef` takes, or the second pass adds it again. Either way, document the statement in [language.md](language.md) and add tests in `tests/`, including one for each way it can be rejected. The source may not use the new statement until a seed that understands it is pinned.

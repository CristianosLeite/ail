# How the stage0 compiler works

`stage0/ailc.s` is the bootstrap compiler: about 700 lines of x86-64 assembly (GNU as, Intel syntax) with no dependencies beyond Linux syscalls. It turns AIL source on stdin into a runnable ELF64 executable on stdout.

It exists to be replaced. Once AIL can express a compiler, the next version is written in AIL and stage0 is only used to build it the first time.

## Pipeline

There is one pass and no intermediate representation.

1. Read all of stdin into an input buffer that holds 64 KiB plus one spare byte; filling the spare byte means the source is too big.
2. Copy a 176-byte ELF header template to the start of a 1 MiB output buffer.
3. Scan the source. For each statement, append machine code directly to the output buffer.
4. Append the code for `exit(0)`.
5. Patch the two segment sizes in the header, write the buffer to stdout, exit.

Because code is emitted as it is read, nothing can refer to something that appears later in the source. That is enough for the current statements; labels and functions will need a fixup list or a second pass.

## Register conventions

The whole compiler shares a fixed set of registers instead of passing parameters:

| Register | Role |
|---|---|
| `rsi` | input cursor |
| `r15` | end of input |
| `rdi` | output cursor |
| `r14` | start of output buffer |
| `ebx` | index of the next syscall argument in the current statement |
| `ebp` | number of variables defined so far |

The memory cell `curop` points at the operation-table entry of the statement being compiled.

`rsi` and `rdi` are chosen so that `lodsb`, `stosb` and `rep movsb` work on the cursors directly.

## Code map

| Label | Job |
|---|---|
| `_start` | read stdin, copy the header template |
| `next` | start of a statement: skip indentation, blank lines and comments, find the keyword in `optab`, and for `sys` require its syscall number |
| `crlf` | check that a CR is followed by LF |
| `tokend` | check that a token is followed by a space, tab, comment or line end, then fall into `arg` |
| `arg` | dispatch the next argument, or end the statement by calling `emit_op` |
| `num` | parse a decimal integer |
| `str` | reject a string outside `sys`; copy the literal into the output and pass its address and length |
| `ident` | a name as an argument: pass a variable or a buffer address, or hand over to `capture` on `as` |
| `capture` | `as <name>`: define the variable if new, call `emit_op` and store `rax` in it |
| `bufdef` | `buf <name> <size>`: enter the buffer in its table and reserve its bytes |
| `blanks`, `blank1`, `eol`, `name` | skip spaces and tabs; require at least one; check that the line ends; read a name |
| `lookup_var`, `lookup_buf` | find a name in the variable or the buffer table |
| `emit_op` | check the operand count and emit the statement's instruction bytes |
| `emit_mov_rr` | emit a 64-bit `mov <register>, <register>` |
| `emit_mov` | emit `mov <argument register>, <value>` and advance `ebx` |
| `fin` | emit `exit(0)`, patch sizes, write the output |
| `err`, `err_big`, `err_undef`, `err_vars`, `err_dup`, `err_bufs` | source errors: print a message, exit 1 |
| `err_read`, `err_write` | I/O errors: print a message, exit 2 |

## Output file layout

```
offset 0     ELF header            64 bytes
offset 64    program header        56 bytes   PT_LOAD, flags R+X: the whole file
offset 120   program header        56 bytes   PT_LOAD, flags R+W: buffers, no file bytes
offset 176   code and strings      entry point
```

The whole file is one segment loaded at the fixed address `0x400000`, so the byte at file offset `n` lives at `0x400000 + n` and the entry point is `0x4000b0`. There are no sections, no symbol table and no dynamic linking. This segment is readable and executable but not writable.

The second segment has a file size of zero and a memory size equal to the total of all `buf` statements, so the kernel maps that many zero-filled writable bytes at the fixed address `0x10000000`. A program without buffers keeps the header with a memory size of zero, which the kernel accepts. Both addresses are fixed so that every address is known while the source is still being read.

## Code generation

**Integer argument.** `mov r32, imm32` into the register for the current argument position, taken from `regtab`. It is 5 bytes, or 6 with a REX prefix for `r8`–`r10`. Writing a 32-bit register zero-extends into the 64-bit one, which is why integers are limited to unsigned 32 bits.

**String argument.** The bytes are placed in the code stream and jumped over:

```
jmp  over          ; E9 + 32-bit length
<string bytes>
over:
mov  <reg>, address
mov  <next reg>, length
```

The address is known as soon as the string is read, so no data section and no back-patching of addresses is needed. The only patch is the jump distance, which is written when the closing quote is found.

**Variable argument.** `mov r64, r64` from the variable's register into the argument register: `REX.W 89 /r`, 3 bytes. The x86 register numbers come from `argnum` (argument position) and `varnum` (variable index); bit 3 of each goes into the REX prefix and the low bits into the ModRM byte.

**Buffer argument.** The buffer's address is a constant, so it is passed like an integer: `mov r32, imm32`.

**End of statement.** The instruction bytes of the statement, copied from its `optab` entry by `emit_op`; for `sys` that is `syscall` (`0F 05`). With `as`, they are followed by `mov <variable register>, rax` in the same 3-byte encoding.

**End of program.** `mov eax, 60` / `xor edi, edi` / `syscall`.

## Operations

Every statement except `buf` is one row of the table `optab`: keyword, operand count, flags and instruction bytes. The operands are parsed by the same code as syscall arguments, so the first lands in `rax` and the second in `rdi`, the registers of argument positions 0 and 1. The instruction bytes then compute the result into `rax`, where `as` picks it up exactly as it does after a syscall.

| Statement | Emitted after the operands |
|---|---|
| `sys` | `syscall` |
| `set` | nothing |
| `add` `sub` `and` `or` `xor` | `op rax, rdi` |
| `mul` | `imul rax, rdi` |
| `div` | `xor edx, edx` / `div rdi` |
| `mod` | `xor edx, edx` / `div rdi` / `mov rax, rdx` |
| `shl` `shr` | `mov rcx, rdi` / `shl` or `shr rax, cl` |
| `load` | `mov rax, [rax]` |
| `loadb` | `movzx eax, byte ptr [rax]` |
| `store` | `mov [rax], rdi` |
| `storeb` | `mov [rax], dil` |

The scratch registers `rax`, `rdi`, `rcx` and `rdx` are never variable registers. So `add x 1 as x` with `x` in `rbx` is `mov rax, rbx` / `mov edi, 1` / `add rax, rdi` / `mov rbx, rax`: 14 bytes, with no attempt to use shorter forms.

The flags say whether `as` is required (everything that produces a value), forbidden (the stores) or optional (`sys`). `emit_op` rejects a statement whose operand count differs from the table; `sys` is exempt and takes one to seven values.

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

The table `vars` has one 16-byte entry per variable: the address of the name inside the input buffer and its length. Names are not copied. `ebp` counts the entries, and `lookup` searches them linearly.

Variable `i` lives in the register `varnum[i]`: `rbx`, `rbp`, `r12`, `r13`, `r14`, `r15`. These are the registers that neither the `syscall` instruction (which destroys `rax`, `rcx` and `r11`) nor the argument positions use. `rsp` is left alone for a future stack. A register is assigned on the first `as` for a name and kept for the rest of the program, so the generated code never saves or restores anything.

A name is only entered in the table when its `as` is reached, at the end of the statement, so `sys 1 n as n` with a new `n` is an undefined variable.

## Buffers

The table `bufs` has the same 16-byte entries as `vars`, and `bufaddr` holds one 32-bit address per buffer. `buf` rounds the size up to 8 bytes, gives the buffer the address `0x10000000` plus the bytes reserved so far, and adds the size to the running total `bsssz`, which `fin` writes into the second program header. The total is kept below 4 GiB minus the base so that every address fits the `imm32` that `emit_mov` writes.

`ident` looks a name up among the variables first and the buffers second. `buf` refuses a name found in either table and `as` refuses a buffer name, so a name always means one thing.

## Limits

- 6 variables, the size of the register pool.
- 16 buffers, the size of the buffer table.

- Input 64 KiB (65536 bytes, inclusive), output 1 MiB. The input limit is checked; the output limit is safe because each source byte expands to at most about three output bytes.
- x86-64 Linux only.
- Strings are read-only; the only writable memory is what `buf` reserves or the program maps itself.

## Adding a statement

A statement that takes values in `rax` and `rdi` and leaves a result in `rax` is one new row in `optab`. Anything else, like `buf`:

1. Add a keyword check in `next`, beside the one for `buf`.
2. Write the emitter, using `rdi` as the output cursor and leaving `rsi` after the statement. End its last token through `eol`.
3. Jump back to `next`.

Either way, document it in [language.md](language.md) and add tests in `tests/`, including one for each way it can be rejected.

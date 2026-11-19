# How the stage0 compiler works

`stage0/ailc.s` is the bootstrap compiler: about 250 lines of x86-64 assembly (GNU as, Intel syntax) with no dependencies beyond Linux syscalls. It turns AIL source on stdin into a runnable ELF64 executable on stdout.

It exists to be replaced. Once AIL can express a compiler, the next version is written in AIL and stage0 is only used to build it the first time.

## Pipeline

There is one pass and no intermediate representation.

1. Read all of stdin into a 64 KiB input buffer.
2. Copy a 120-byte ELF header template to the start of a 1 MiB output buffer.
3. Scan the source. For each statement, append machine code directly to the output buffer.
4. Append the code for `exit(0)`.
5. Patch the segment size in the header, write the buffer to stdout, exit.

Because code is emitted as it is read, nothing can refer to something that appears later in the source. That is enough for `sys`; labels and functions will need a fixup list or a second pass.

## Register conventions

The whole compiler shares a fixed set of registers instead of passing parameters:

| Register | Role |
|---|---|
| `rsi` | input cursor |
| `r15` | end of input |
| `rdi` | output cursor |
| `r14` | start of output buffer |
| `ebx` | index of the next syscall argument in the current statement |

`rsi` and `rdi` are chosen so that `lodsb`, `stosb` and `rep movsb` work on the cursors directly.

## Code map

| Label | Job |
|---|---|
| `_start` | read stdin, copy the header template |
| `next` | start of a statement: skip whitespace and comments, match `sys` |
| `arg` | dispatch the next argument, or end the statement by emitting `syscall` |
| `num` | parse a decimal integer |
| `str` | copy a string literal into the output and pass its address and length |
| `emit_mov` | emit `mov <argument register>, <value>` and advance `ebx` |
| `fin` | emit `exit(0)`, patch sizes, write the output |
| `err` | print `ailc: syntax error`, exit 1 |

## Output file layout

```
offset 0     ELF header            64 bytes
offset 64    program header        56 bytes   one PT_LOAD, flags R+X
offset 120   code and strings      entry point
```

The whole file is one segment loaded at the fixed address `0x400000`, so the byte at file offset `n` lives at `0x400000 + n` and the entry point is `0x400078`. There are no sections, no symbol table and no dynamic linking. The segment is readable and executable but not writable.

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

**End of statement.** `syscall` (`0F 05`).

**End of program.** `mov eax, 60` / `xor edi, edi` / `syscall`.

## Worked example

`sys 1 1 "hello world\n"` compiles to 168 bytes: the 120-byte header followed by

```
78:  b8 01 00 00 00      mov  eax, 1          ; syscall number: write
7d:  bf 01 00 00 00      mov  edi, 1          ; fd: stdout
82:  e9 0c 00 00 00      jmp  0x93            ; skip the 12 string bytes
87:  68 65 6c 6c 6f 20 77 6f 72 6c 64 0a      ; "hello world\n"
93:  be 87 00 40 00      mov  esi, 0x400087   ; address of the string
98:  ba 0c 00 00 00      mov  edx, 12         ; its length
9d:  0f 05               syscall
9f:  b8 3c 00 00 00      mov  eax, 60         ; implicit exit(0)
a4:  31 ff               xor  edi, edi
a6:  0f 05               syscall
```

To inspect any compiled program the same way:

```
objdump -D -b binary -mi386:x86-64 -Mintel --start-address=120 build/hello
```

## Limits

- Input 64 KiB, output 1 MiB. The input limit is checked; the output limit is safe because each source byte expands to at most about three output bytes.
- x86-64 Linux only.
- No writable memory in the generated program.

## Adding a statement

1. Add a keyword check in `next`, beside the one for `sys`.
2. Write the emitter, using `rdi` as the output cursor and leaving `rsi` after the statement.
3. Jump back to `next`.
4. Document it in [language.md](language.md) and add a test in `tests/`.

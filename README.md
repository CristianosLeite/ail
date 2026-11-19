# AIL

Proof of concept: a hardware-oriented language designed to cost few tokens when an AI writes it.

```
sys 1 1 "hello world\n"
```

## Build

```
make test      # builds build/ailc, compiles examples/hello.ai, runs it
```

Needs GNU `as` and `ld`, x86-64 Linux. The compiler itself reads source on stdin and writes a static ELF64 on stdout, with no assembler or linker involved:

```
build/ailc < prog.ai > prog && chmod +x prog
```

## Language (stage0)

One statement per line.

| Form | Meaning |
|---|---|
| `sys n a b ...` | Raw Linux syscall `n` with up to 6 arguments |
| `123` | Unsigned 32-bit decimal argument |
| `"text"` | Expands to two arguments: address and length. Escapes: `\n \t \0 \\ \"` |
| `# ...` | Comment to end of line |

The program starts at the first line and an `exit(0)` is appended at the end.

## Layout

- `stage0/ailc.s`: bootstrap compiler in assembly
- `examples/hello.ai`: hello world

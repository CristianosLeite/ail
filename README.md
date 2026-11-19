# AIL

Proof of concept: a hardware-oriented programming language designed to cost few tokens when an AI writes it. Assembly-like in what it does, modern in how little it makes you write, with no classes or objects. Human readability is not a goal.

This is a complete program:

```
sys 1 1 "hello world\n"
```

It compiles to a 224-byte static Linux executable.

## Status

Early proof of concept. The language has raw syscalls, six register variables, integer arithmetic, comparisons and byte or 64-bit memory access, but no control flow yet, and the compiler is a bootstrap version written in assembly. The plan is to grow the language until the compiler can be rewritten in AIL itself; see the [roadmap](docs/roadmap.md).

## Quick start

Requires x86-64 Linux with GNU `as` and `ld` (binutils) and `make`.

```
make                # builds build/ailc and the examples
build/hello         # prints: hello world
echo hi | build/echo     # prints: hi
echo hi | build/count    # prints: 0003
make test           # runs the tests in tests/
make test T=hello   # runs one test
```

To compile your own program, give the compiler source on stdin and take the executable from stdout:

```
build/ailc < prog.ai > prog && chmod +x prog
```

Or put it in `examples/foo.ai` and run `make build/foo`.

## The language in one minute

| Form | Meaning |
|---|---|
| `sys n a b ...` | Raw Linux syscall `n` with up to 6 arguments |
| `sys ... as x` | Same, keeping the return value in variable `x` (at most 6 variables) |
| `set a as x` | `x = a` |
| `add a b as x` | `x = a + b`; also `sub mul div mod and or xor shl shr` |
| `lt a b as x` | `x = 1` if `a < b`, else `0`, unsigned; also `eq ne le gt ge` |
| `buf b 4096` | Reserve 4096 zero-filled writable bytes; `b` is their address |
| `load p as x`, `loadb p as x` | Read the 64-bit value or the byte at address `p` |
| `store p a`, `storeb p a` | Write `a` as 64 bits or as one byte at address `p` |
| `123` | Unsigned 32-bit decimal argument |
| `x` | Variable (64-bit) or buffer name (its address) |
| `"text"` | Two arguments: address and length. Escapes: `\n \t \0 \\ \"` |
| `# ...` | Comment to end of line |

One statement per line. The program starts at the first line and `exit(0)` is appended at the end.

## Documentation

- [Language reference](docs/language.md): everything the compiler accepts, with examples and error cases
- [How the compiler works](docs/compiler.md): pipeline, output file layout, code generation, a byte-by-byte walkthrough of `examples/hello.ai`
- [Roadmap](docs/roadmap.md): the path to a self-hosted compiler

## Layout

- `stage0/ailc.s`: bootstrap compiler in assembly
- `examples/`: sample programs: `hello` (a syscall result kept in a variable), `echo` (a buffer), `count` (arithmetic and byte stores)
- `tests/`: one `.ai` program per test with its expected output, exit status or compile error, run by `tests/run.sh`
- `docs/`: documentation
- `AGENTS.md`, `.agents/knowledge/`: guidance and notes for AI coding agents

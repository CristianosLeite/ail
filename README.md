# AIL

Proof of concept: a hardware-oriented programming language designed to cost few tokens when an AI writes it. Assembly-like in what it does, modern in how little it makes you write, with no classes or objects. Human readability is not a goal.

This is a complete program:

```
sys 1 1 "hello world\n"
```

It compiles to a 168-byte static Linux executable.

## Status

Early proof of concept. The language has a single statement (a raw syscall) plus variables that keep syscall results, and the compiler is a bootstrap version written in assembly. The plan is to grow the language until the compiler can be rewritten in AIL itself; see the [roadmap](docs/roadmap.md).

## Quick start

Requires x86-64 Linux with GNU `as` and `ld` (binutils) and `make`.

```
make                # builds build/ailc and build/hello
build/hello         # prints: hello world
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
| `123` | Unsigned 32-bit decimal argument |
| `x` | Variable argument, 64-bit |
| `"text"` | Two arguments: address and length. Escapes: `\n \t \0 \\ \"` |
| `# ...` | Comment to end of line |

One statement per line. The program starts at the first line and `exit(0)` is appended at the end.

## Documentation

- [Language reference](docs/language.md): everything the compiler accepts, with examples and error cases
- [How the compiler works](docs/compiler.md): pipeline, output file layout, code generation, a byte-by-byte walkthrough of hello world
- [Roadmap](docs/roadmap.md): the path to a self-hosted compiler

## Layout

- `stage0/ailc.s`: bootstrap compiler in assembly
- `examples/`: sample programs
- `tests/`: one `.ai` program per test with its expected output, exit status or compile error, run by `tests/run.sh`
- `docs/`: documentation
- `AGENTS.md`, `.agents/knowledge/`: guidance and notes for AI coding agents

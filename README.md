# AIL

A hardware-oriented programming language designed to cost few tokens when an AI writes it. Assembly-like in what it does, modern in how little it makes you write, with no classes or objects.

```
sys write 1 "hello world\n"
```

That is a complete program. It compiles to a 226-byte static, position-independent Linux executable.

AIL has a compiler written in AIL that compiles itself, a standard library (I/O, files, processes, collections, threads, async tasks, arrays, JSON, HTTP), packages with dependencies, and the command `ail` to build, run and test them. On ten programs it costs 13% fewer tokens than C and 19% fewer than Rust, and its CPU-bound programs run within 4% of C at `-O3` ([tokens](https://github.com/CristianosLeite/ail-bench/blob/main/docs/tokens.md), [performance](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md)).

## Install

Requires x86-64 Linux, `make`, a C compiler for the runtime, and `curl` or `gh` to fetch the released compiler the build starts from, once.

```
git clone https://github.com/CristianosLeite/ail.git
cd ail
make install PREFIX=$HOME/.local   # bin/ail, and the rest in lib/ail/
```

Without `PREFIX` it installs under `/usr/local`.

## Use

```
ail new hello   # hello/: Ailfile, src/main.aiw, a test
cd hello
ail run         # prints: hello from hello
ail test        # prints: ok   hello, and 1 test, 0 failed
```

A program looks like this:

```
use "lib/std/io.aiw"

fn fact n
	ifz n
		ret 1
	end
	call fact n-1 as r
	ret n*r
end

call fact 5 as x
call putn x
call print "\n"
```

A faulty program is refused with one line that says where and why, for example `ailc: 12: undefined label done`.

The compiler alone reads source on stdin and writes the executable on stdout:

```
build/ailc < prog.aiw > prog && chmod +x prog
```

## Documentation

- [Language reference](docs/language.md): every statement, the library, the errors, with examples
- [The command `ail`](docs/cli.md): making, building, running and testing a package, and installing AIL
- [Packages](docs/packages.md): the manifest `Ailfile`, versions, dependencies and the lock
- [How the compiler works](docs/compiler.md): the build from its seed, the pipeline, the output file, code generation
- [Roadmap](docs/roadmap.md), [TODO](docs/TODO.md) and [Backlog](docs/BACKLOG.md): what is done and what comes next

Programs to read are in [`examples/`](examples/). The measurements against C, Rust and assembly are in [ail-bench](https://github.com/CristianosLeite/ail-bench), and the VS Code extension in [ail-extensions](https://github.com/CristianosLeite/ail-extensions).

## Contributing

```
make        # build build/ailc, build/ail and the examples
make test   # run the tests and the checks of the compiler against itself
```

[AGENTS.md](AGENTS.md) describes the repository, its rules and its tests.

## License

[MIT](LICENSE).

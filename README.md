# AIL

Proof of concept: a hardware-oriented programming language designed to cost few tokens when an AI writes it. Assembly-like in what it does, modern in how little it makes you write, with no classes or objects. Human readability is not a goal.

This is a complete program:

```
sys write 1 "hello world\n"
```

It compiles to a 226-byte static, position-independent Linux executable.

## Status

Early proof of concept. The language has raw syscalls, up to 64 variables per function, kept in six registers where possible, integer arithmetic and comparisons as statements or as infix expressions, byte to 64-bit memory access, labels and jumps, `if` and `while` blocks, and functions with recursion. On ten programs it costs 13% fewer tokens than C and 19% fewer than Rust, and its CPU-bound programs run within 4% of C at `-O3` in the geometric mean ([performance](docs/performance.md)). The compiler is written in AIL, compiles itself to a byte-identical copy and is built from a released copy of itself; the compiler in assembly that built it first is gone. See the [roadmap](docs/roadmap.md) for what comes next and the [token measurements](docs/tokens.md) for how AIL compares with C, Rust and assembly.

## Quick start

Requires x86-64 Linux and `make`; `make test` also needs `python3`. The build starts from a released executable of the compiler, the seed that `seed/MANIFEST` pins: put it at `seed/ailc-<version>`, or let `make` fetch it with `curl` or `gh`; a file with another checksum is refused.

```
make                # builds build/ailc (the compiler in AIL, from the seed) and the examples
build/hello         # prints: hello world
echo hi | build/echo     # prints: hi
echo hi | build/count    # prints: 0003
build/loop          # prints the digits 0 to 9, one per line
build/fact; echo $? # prints: 120
make test           # runs the tests in tests/ and the checks of the compiler against itself
make test T=hello   # runs one test
```

A faulty program is refused with one line that says where and why, for example `ailc: 12: undefined label done`.

To compile your own program, give the compiler source on stdin and take the executable from stdout:

```
build/ailc < prog.ai > prog && chmod +x prog
```


Or put it in `examples/foo.ai` and run `make build/foo`.

## The language in one minute

| Form | Meaning |
|---|---|
| `sys n a b ...` | Raw Linux syscall `n` with up to 6 arguments; `n` is a number or a name such as `write` |
| `args as p` | Address of the argument count, arguments and environment the kernel passed |
| `sys ... as x` | Same, keeping the return value in variable `x` (at most 64 variables per function) |
| `x=a+b*c` | An expression kept in `x`: `* / %`, `+ -`, `<< >>`, `&`, `^`, `\|` and the comparisons `== != < <= > >=`, with parentheses, written without spaces; `x+=e` changes `x` in place. An expression may stand wherever a value does: `storeb out+1 48+n%10` |
| `set a as x`, `add a b as x`, `lt a b as x` | The same as statements: `x=a`, `x=a+b`, `x=a<b`; also `sub mul div mod and or xor shl shr` and `eq ne le gt ge` |
| `sdiv smod sar`, `slt sle sgt sge` | Division, remainder, right shift and ordering of signed values |
| `fadd fsub fmul fdiv fsqrt`, `itof ftoi`, `flt fle feq` | Arithmetic, conversion and comparison of doubles, kept as their 64 bits |
| `xadd p v as x`, `cas p old new as x` | Atomic add and compare-and-swap on the 64 bits at `p` |
| `buf b 4096` | Reserve 4096 zero-filled writable bytes; `b` is their address |
| `local b 64` | 64 bytes in the frame of the current function; `b` is their address until it returns |
| `alloc n as p`, `free p` | `n` zero-filled bytes from the kernel at run time (0 if refused), and their release |
| `var v w` | Global 64-bit cells, zero at start: read as a value, written by `as`, seen by every function |
| `const k 60` | A name for a number, also usable as the syscall number and as a buffer size |
| `data d "abc" 10` | Read-only bytes from strings and byte values; `d` is their address |
| `len d as x` | Length in bytes of a buffer, of data or of a string |
| `at b i n as p` | Address of byte `i` of buffer, data or local `b`; traps at run time unless `n` bytes fit |
| `load p as x`, `load4`, `load2`, `loadb` | Read the 64-bit, 32-bit or 16-bit value or the byte at address `p` |
| `store p a`, `store4`, `store2`, `storeb` | Write `a` as 64, 32 or 16 bits or as one byte at address `p` |
| `label l` | Name this point of the program |
| `jmp l`, `jz a l`, `jnz a l` | Jump to label `l`: always, if `a` is zero, if `a` is not zero |
| `jlt a b l` | Jump if `a < b`; also `jeq jne jle jgt jge` and signed `jslt jsle jsgt jsge` |
| `if a` ... `else` ... `end` | Run the lines if `a` is not zero, where `a` may be a comparison, `if n<10`; also `ifz` and `ifeq iflt ...` with two values |
| `while a` ... `end` | Run the lines as long as `a` is not zero, tested before each round |
| `use "lib/io.ai"` | Compile another file here, once per path |
| `fn f a b` ... `end` | Define function `f` with parameters `a` and `b`, its own variables and labels |
| `ret a b` | Return one to six values from the function; reaching `end` returns 0 |
| `ref f as p`, `callp p a b as x` | The address of a function, and a call through an address |
| `tail f a b` | Call `f` and return its result without growing the stack |
| `call f a b as x y` | Call `f` with as many values as it has parameters; `as` names a variable per result and is optional |
| `123`, `0x7b`, `-1` | 64-bit integer argument: decimal, hexadecimal or negative |
| `x` | Variable (64-bit) or buffer name (its address) |
| `"text"` | Two arguments: address and length. Escapes: `\n \t \0 \\ \"` |
| `# ...` | Comment to end of line |

One statement per line. The program starts at the first line and `exit(0)` is appended at the end.

## Documentation

- [Language reference](docs/language.md): everything the compiler accepts, with examples and error cases
- [How the compiler works](docs/compiler.md): how it is built from its seed, pipeline, output file layout, code generation, a byte-by-byte walkthrough of `examples/hello.ai`
- [Performance](docs/performance.md): how the examples are timed against C, Rust and assembly, and the results
- [Roadmap](docs/roadmap.md): what is done and what comes next
- [Backlog](docs/TODO.md): the limits of the compiler and the work to lift them, item by item
- [Redesign](docs/REDESIGN.md): the goals that brought expressions, `while` and the seed-built compiler

## Layout

- `compiler/ailc.ai`, `compiler/tables.ai`: the compiler, written in AIL, built by the seed and then by itself
- `seed/MANIFEST`: the released compilers a build may start from
- `examples/`: sample programs: `hello` (a syscall result kept in a variable), `echo` (a buffer), `count` (arithmetic and byte stores), `loop` (a comparison and a jump), `fact` (a recursive function), and five that compute, for the measurements: `compute` (an arithmetic recurrence), `sieve` (primes in a table of bytes), `collatz` (branches and division), `fnv` (a hash over a buffer), `isort` (an insertion sort)
- `bench/`: the examples in C, Rust and assembly, for the [token](docs/tokens.md) and [time](docs/performance.md) measurements
- `tools/`: measurements (`tokens.sh`, `perf.py`, `bench.sh`), source rewriters (`infix.py`, `fuse.py`), random programs (`randvars.py`), the seed (`seed.sh`)
- `tests/`: one `.ai` program per test with its expected output, exit status or compile error, run by `tests/run.sh`; `tests/self.sh` checks the compiler against its seed-built translation and its own output
- `docs/`: documentation
- `AGENTS.md`, `.agents/knowledge/`: guidance and notes for AI coding agents

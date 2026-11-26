# AIL language reference

This describes exactly what the compiler accepts today. The language is deliberately tiny; see the [roadmap](roadmap.md) for what comes next.

## Design rules

AIL is written by AI, so the cost that matters is tokens, not keystrokes or human readability.

- Short common words separated by spaces. No punctuation unless it carries information.
- No boilerplate: no `main`, no statement terminators, no declarations that the compiler can derive, and one short line to share a file.
- Hardware-oriented: statements map directly onto machine operations. There are no classes or objects.

## Program structure

A program is a sequence of statements, one per line. Execution starts at the first statement and runs downwards unless a [jump](#control-flow) sends it elsewhere. After the last statement the compiler appends `exit(0)`: the service `exit` of the [runtime](#rt) with status 0, which ends the whole process, as `rt exit` written in the program does. A `sys exit` ends only the thread that runs it, which is the process when there is one thread.

A [function](#functions) may stand anywhere between the statements. Execution passes around its body, which only runs when the function is called.

Blank lines are ignored. Indentation is ignored by the compiler; [Source style](#source-style) says how sources are indented.

### `use`

```
use "path"
```

Compiles the file `path` at this place, as if its lines stood here: its functions, global names and top-level statements become part of the program, and its top-level statements run where the `use` stands. A program is thus split into files by listing them, and a file of functions and data is a library.

```
use "lib/std/io.aiw"
call print "hello\n"
```

- A path is compiled **once**: a later `use` of the same path, in any file of the same [package](#packages), does nothing. Two files can therefore each name the library they need. Paths are compared as written, so write a file the same way everywhere.
- The path is taken as it stands between the quotes, with no escapes, on one line, at most 4095 bytes. A relative path starts from the directory the compiler runs in, not from the file that has the `use`; a file of a [package](#packages) starts from the directory of its package.
- `use` is a statement of the top level: it cannot stand inside a function, and a function must end in the file that starts it.
- Because functions, buffers and data may be [used before they are declared](#names), the place of a `use` matters only for the top-level statements of the file, for its `var` and `const` names, which must come before their uses, and for its top-level variables, which it shares with the rest of the top level.

All files of a program together are subject to the [size limit](#errors) of the source.

### Packages

```
build/ailc ail=/opt/ail aildb=deps/aildb < prog.aiw > prog
```

```
use "lib/std/io.aiw"            # the library of AIL
use "src/util.aiw"              # a file of this program
use "aildb:src/lib/snap.aiw"    # a file of the package aildb
```

A package is a directory of sources with a name, which a program reads files from without having them in its own directory. The compiler is told of each with an argument `name=directory`; it takes no other argument, and without one every path is read as [`use`](#use) says.

- `use "name:path"` compiles the file `path` under the directory of the package `name`. The name is what stands before a colon in the first part of the path, the part before any `/`.
- A path without a name, in a file of a package, starts from the directory of that package: a package names its own files as it does when it is compiled by itself, and a program that uses it changes nothing in it. In the source given to the compiler and in the files it names without a package, such a path starts from the directory the compiler runs in.
- A path that starts with `lib/` is in the package `ail`, the library of AIL, whichever file has the `use`, if the arguments name that package: `use "lib/std/io.aiw"` and `use "ail:lib/std/io.aiw"` are the same file, and a program has the library once, the one of its compiler. A package therefore has no directory `lib` of its own at its top. If the arguments name no package `ail`, the path is read like any other.
- A path that starts with `/` is in no package, and so are the paths without a name in that file.
- A file is compiled once for its package and its path, so `src/util.aiw` of two packages are two files, and one file named from two packages is compiled where the first `use` stands.
- An error in a file of a package has the directory of the package before the path, as the file was opened: `ailc: deps/aildb/src/lib/snap.aiw:12: ...`.
- The names of all packages of a program are one name space, as with any `use`: two packages that define the same function are a `duplicate name`. The [rule of the libraries](#the-io-library), a prefix for each file, keeps them apart.
- There are at most 256 packages. A name is not empty and has no `/`, `:` or `=`; a directory is not empty, and slashes at its end are not counted. An argument that is not of this form, or a name given twice, is the error `usage: ailc [name=directory]... < source > executable`, with status 2.

## Separators

The same rule holds everywhere outside string literals:

- Tokens (the keyword, numbers, strings, names, `as`) are separated by one or more spaces or tabs. Two tokens may not touch: `1"x"` and `"a""b"` are errors.
- A line ends with LF or CRLF. A CR that is not followed by LF is an error, also inside a comment; only a string may contain one.
- `#` starts a comment and may directly follow a token.

No other byte separates anything. A NUL or any other control character between tokens is a syntax error.

## Source style

Spaces and tabs at the start of a line mean nothing to the compiler: a block ends at its `end`, however the lines are indented. Sources are indented all the same, by one rule:

- One tab for each block the line stands in. Statements of the top level start at column one.
- The lines between `fn` (or `async fn`) and its `end` are one level deeper, and so are those of `while` and of `if` in all its forms (`ifz`, `ifeq`, `iflt`, ...), and those after `else`.
- `else` and `end` stand at the level of the line that opened their block.
- A `label` and a line that holds only a comment stand at the level of the statements around them.
- Nothing else changes: an expression stays without spaces (`n-=1`), and the lines of a string that spans lines are part of the string.

```
fn gcd a b
	while b
		if a<b
			t=a
			a=b
			b=t
		else
			a-=b
		end
	end
	ret a
end
```

`build/tools/indent file.aiw ...` (`tools/indent.aiw`) indents files that way in place and changes no byte but the spaces and tabs at the start of a line, so the compiled program stays the same; `build/tools/indent --check file.aiw ...` only prints `path:line` for each line that is not as the rule has it, and exits with 1 if there is one; `build/tools/indent -` reads a source from stdin and writes it to stdout. `build/tools/fuse` and `build/tools/infix` write what they make indented by the same rule. It does not check the program: an `end` too many closes nothing. Every source of the repository is indented that way and `make test` checks it (`tests/indent.sh`), but for the tests of the separators, listed in `tests/indent/skip`, and the fixtures that a tool must reproduce byte for byte.

[`editors/vscode/`](https://github.com/CristianosLeite/ail-extensions/tree/main/editors/vscode) of the repository ail-extensions is an extension for VS Code that colours `.aiw` files, folds their blocks and formats them with that tool; its `README.md` says how to install it.

Tabs, because they cost fewer tokens than spaces (measured in [token cost](https://github.com/CristianosLeite/ail-bench/blob/main/docs/tokens.md)); an editor shows one two columns wide, which `.editorconfig` asks for.

## Statements

### `sys`

```
sys n a b c d e f
sys n a b c d e f as name
```

Performs the raw Linux x86-64 syscall number `n` with up to six arguments. With `as name`, the syscall's return value is kept in the variable `name` (see [Variables](#variables)). `n` must be an [integer](#integers), the name of a [`const`](#const) or one of the [syscall names](#syscall-names) below, not a variable or a string. The statement ends at the end of the line.

| Position | Register |
|---|---|
| `n` | `rax` |
| 1st argument | `rdi` |
| 2nd | `rsi` |
| 3rd | `rdx` |
| 4th | `r10` |
| 5th | `r8` |
| 6th | `r9` |

Registers for arguments you leave out are not set and keep whatever they held. Without `as`, the syscall's return value is lost.

Registers for arguments you leave out are not set by the statement either, so a syscall that reads more arguments than it was given sees whatever those registers held.

#### Syscall names

In the place of the number, and only there, `sys` accepts these names for the kernel's numbers:

| | | | |
|---|---|---|---|
| `read` 0 | `write` 1 | `open` 2 | `close` 3 |
| `stat` 4 | `fstat` 5 | `lseek` 8 | `mmap` 9 |
| `mprotect` 10 | `munmap` 11 | `brk` 12 | `rt_sigaction` 13 |
| `ioctl` 16 | `pipe` 22 | `nanosleep` 35 | `getpid` 39 |
| `socket` 41 | `connect` 42 | `accept` 43 | `bind` 49 |
| `listen` 50 | `clone` 56 | `fork` 57 | `execve` 59 |
| `exit` 60 | `wait4` 61 | `kill` 62 | `rename` 82 |
| `mkdir` 83 | `rmdir` 84 | `unlink` 87 | `chmod` 90 |
| `gettimeofday` 96 | `getuid` 102 | `futex` 202 | `sched_getaffinity` 204 |
| `clock_gettime` 228 | `exit_group` 231 | `openat` 257 | `getrandom` 318 |

```
sys write 1 "hello\n"
sys exit 0
```

A name costs one token where a number costs two. The names are not constants: anywhere else `write` is an ordinary name, free for a variable or a function. A `const` of the program with the same name is used instead of the built-in number, and any other syscall is reached by its number or by a `const` of your own.

#### Results and errors

The kernel returns one value: the result, or a negative error number from -1 to -4095. `as` keeps it as it is. Read as signed it is below zero exactly when the call failed, so one line tests it:

```
sys open path 0 0 as fd
jslt fd 0 fail
```

### `args`

```
args as p
```

Keeps in a variable the address of what the program was started with, which the [runtime](#rt) noted at the start. At that address stands the number of arguments, 8 bytes; then one address for each argument, the first being the name the program was started with; then a zero; then one address for each environment string, and another zero. Every argument and environment string ends with a NUL byte.

```
args as p
load p as argc
add p 8 as q
load q as name          # address of the program's name
```

`args` may stand anywhere, in a function too, and gives the same address each time; it is the service `args` of the runtime. [`lib/std/io.aiw`](#the-io-library) offers `argc` and `argv`.

### `rt`

```
rt name a b c
rt name a b c as x y
```

Calls a service of the runtime: what a program asks of the platform it runs on, by a name that is the same on every platform, where [`sys`](#sys) is a system call of x86-64 Linux by its number. The runtime is code that the compiler puts into every executable; [runtime.md](runtime.md) describes it and each service. `name` is one of the names below and is a name only in that place: a variable, a `const` or a function of the program may be called the same. The values are [arguments](#arguments) like those of a `call`, a string being two, its address and its length. Their number is checked (`wrong operand count`), as is the number of names after `as`, which is optional and takes at most as many names as the service has results (`wrong result count`); a name that is no service is an `unknown service`.

| Service | Values | Result |
|---|---|---|
| `exit` | status | none: ends the process with every thread |
| `args` | | the address [`args`](#args) gives |
| `alloc` | size | the address [`alloc`](#alloc-and-free) gives, or 0 |
| `free` | address | none |
| `open` | address and length of a path, flags, mode | a descriptor, or an error |
| `close` | descriptor | 0, or an error |
| `read` | descriptor, address, size | the bytes read, 0 at the end, or an error |
| `write` | descriptor, address, size | the bytes written, or an error |
| `pipeerr` | | 0, or an error; a `write` to a closed pipe is the error -32 from now on, not the end of the process |
| `mkdir` | address and length of a path, mode | 0, or an error (-17 if it is there) |
| `unlink` | address and length of a path | 0, or an error: the file is removed |
| `rmdir` | address and length of a path | 0, or an error (-39 if it is not empty): the empty directory is removed |
| `rename` | address and length of a path, and of another | 0, or an error: the file has the second path, in place of a file that had it |
| `names` | descriptor of a directory, address, size | the bytes written, 0 after the last name, or an error |

An error is a negative number, larger than -4096; [runtime.md](runtime.md) has their list. The descriptors 0, 1 and 2 are the input, the output and the error output the program was started with. A path is its bytes, with no NUL behind them.

```
rt write 1 "hello\n" as n
rt exit n!=6
```

A service is called like a function: it overwrites the registers of the [`sys`](#sys) arguments and leaves every variable.

### `set` and arithmetic

```
set a as name
add a b as name
```

`set` copies one value into a variable. The arithmetic statements take two values and keep the result in a variable. All of them need `as name`; an operand is any [argument](#arguments), and a string is its address.

| Statement | Result |
|---|---|
| `set a` | `a` |
| `add a b` | `a + b` |
| `sub a b` | `a - b` |
| `mul a b` | `a * b` |
| `div a b` | `a / b`, unsigned, rounded down |
| `mod a b` | remainder of `a / b`, unsigned |
| `and a b`, `or a b`, `xor a b` | bitwise |
| `shl a b` | `a` shifted left by `b` bits |
| `shr a b` | `a` shifted right by `b` bits, zero-filled |
| `sdiv a b` | `a / b`, signed, rounded toward zero |
| `smod a b` | remainder of the signed division, with the sign of `a` |
| `sar a b` | `a` shifted right by `b` bits, filled with its sign bit |

Arithmetic is 64-bit and wraps silently: `sub 0 1` is all ones, which is `-1`. Addition, subtraction, multiplication and `shl` give the same bits for signed and unsigned numbers; only division, remainder, the shift to the right and ordering come in two forms, and the forms with `s` read both values as two's complement. A shift uses only the low 6 bits of `b`.

Nothing is checked: an overflow wraps, and dividing by zero kills the program with `SIGFPE` (exit status 136 in a shell), as does the one signed quotient that does not fit, -9223372036854775808 by -1. Test the divisor with `jz` where it can be zero. The result may go into one of the operands: `add i 1 as i`.

### Assignment

```
x=5
y=x*x+1
i+=1
h=(h^r)*0x100000001b3
```

`name=expression` computes the [expression](#expressions) and keeps it in the variable, as `set expression as name` does, but in the register of the variable where it can, so that `i+=1` is one instruction: the variable is defined if it is new, a `var` of that name is written, and any other global name is `duplicate name`. The statement is one word: no space on either side of the `=`, and nothing after the expression but a comment. A variable that is new cannot stand in its own expression.

With one of the operators `* / % + - << >> & ^ |` directly before the `=`, the variable is changed in place: `x+=e` is `x=x+(e)`, the whole right side being the second operand, so `x*=a+1` multiplies by the sum. The variable must have a value already.

The name is read before the statements are looked at, so a variable may be named like one: `end=add+1`. The comparisons have no such form, and `x==1` at the start of a line is not a statement.

### Floating point

```
itof 3 as a
fdiv a b as x
```

A floating-point number is an IEEE 754 double, and a variable holds its 64 bits like any other value: nothing marks it as a number of that kind. These statements read their values as doubles:

| Statement | Result |
|---|---|
| `itof a` | the signed integer `a` as a double |
| `ftoi a` | the double `a` as a signed integer, rounded toward zero |
| `fadd a b`, `fsub a b`, `fmul a b`, `fdiv a b` | sum, difference, product, quotient |
| `fsqrt a` | square root |
| `flt a b`, `fle a b`, `feq a b` | `1` if `a` is below, below or equal to, equal to `b`, else `0` |

A comparison with a value that is not a number is `0`, also `feq` of it with itself. For "above", swap the values. There are no floating-point literals: make a constant from integers (`itof 1` and `itof 3`, then `fdiv`), or write its bits (`0x3ff8000000000000` is 1.5). The integer statements work on the bits: `add` of two doubles is not their sum, and `lt` orders negative doubles the wrong way round.

```
itof 2 as two
fsqrt two as r
itof 1000 as k
fmul r k as r
ftoi r as n             # n = 1414
```

### Single precision

```
f4to8 a as x
f8to4 a as x
```

A value that is computed is a double, but data is often kept as IEEE 754 binary32, four bytes a number. These two statements go between the forms; there is no arithmetic on a binary32.

| Statement | Result |
|---|---|
| `f4to8 a` | the binary32 in the low 32 bits of `a`, as a double |
| `f8to4 a` | the double `a` rounded to a binary32, in the low 32 bits, with zeros above them |

`f4to8` reads only the low 32 bits, which is what [`load4`](#load-and-store) gives of four bytes. Every binary32 is a double, so it rounds nothing: zeros and infinities keep their sign, a subnormal becomes a normal double, and a value that is not a number stays none, a signalling one made quiet. `f8to4` rounds to the nearest binary32, a tie to the one whose last bit is 0; a double beyond the largest binary32 by half a last place or more becomes an infinity, and one below half the smallest becomes a zero of its sign. Its result is ready for `store4`.

```
load4 p as v            # four bytes of a file
f4to8 v as x
fmul x x as x
f8to4 x as w
store4 q w
```

### Two doubles at once

```
padd p q r
psub p q r
pmul p q r
pdiv p q r
pmadd p q r
```

`p`, `q` and `r` are addresses, and at each lie two doubles, 16 bytes. `padd` makes the two at `p` the sums of those at `q` and at `r`, the first with the first and the second with the second; `psub`, `pmul` and `pdiv` make them the differences, the products and the quotients, `q` first. `pmadd` adds the two products to what is at `p`. Each double is computed as `fadd`, `fsub`, `fmul` and `fdiv` compute one, and `pmadd` as an `fmul` and then an `fadd`, so a loop that takes its doubles two at a time gives the bits that one at a time gives:

```
i=0
while i+1<n
	padd o+i*8 a+i*8 b+i*8  # o[i] = a[i] + b[i], and the same for i+1
	i+=2
end
```

What such a loop gains is the way of a double: `fadd` takes each from a general register to a floating-point one and back, these read and write memory. The statements keep no value, so they have no `as`. Both values are read before anything is written: `p` may be `q` or `r`, or lie across them. The addresses need no alignment and are not checked, at compile time or after. A number that is to go with every pair is written twice into 16 bytes, a [`local`](#local) or a `buf`, whose address is then `q` or `r`. The instructions are those of SSE2, which every x86-64 processor has.

### A sum in its order

```
fsum a p n s as x
fdot a p q n as x
```

`fsum` adds to the double `a` the `n` doubles that lie from the address `p` on, each `s` bytes behind the one before, one after the other, and `x` is the sum. `fdot` adds to `a` the products of the `n` doubles from `p` on with the `n` from `q` on, both one behind the other, 8 bytes each. `fsum` gives the bits of this loop, and `fdot` those of the same loop with an `fmul` of the two elements before the `fadd`:

```
x=a
while n
	load p as v
	fadd x v as x
	p+=s
	n-=1
end
```

Each element is added to the sum of those before it, in that order, and a product is rounded before it is added: nothing is taken two at a time, since that would add in another order and give other last digits. What the statements gain is that the sum stays in a floating-point register for the whole run, where the `fadd` of the loop takes it from a general register and back at every element. `s` is any number of bytes, also negative, and 0 adds one double `n` times; with `n` 0 the result is `a`. The addresses are not checked.

```
fdot4 a p q n as x
```

`fdot4` is `fdot` for data kept as [binary32](#single-precision): the `n` elements from `p` on are binary32, 4 bytes each, and those from `q` on doubles, 8 bytes each. Each binary32 is made a double as `f4to8` makes it, which rounds nothing, multiplied by its double, and the rounded product added to the sum: the bits of the loop above with `load4 p as v`, `f4to8 v as v`, an `fmul` with the double at `q` and the `fadd`, `p` stepped by 4 and `q` by 8. The addresses need no alignment. It is the statement for a score against stored vectors: the query is widened once into doubles, and each vector is read where it lies.

### Atomic operations

```
xadd p v as old
cas p old new as ok
```

`xadd` adds `v` to the 64 bits at address `p` and keeps what was there before; `cas` stores `new` at `p` only if the 64 bits there equal `old`, and keeps `1` if it stored and `0` if not. Each happens as one step that no other thread or process sharing the memory can come between, where a `load`, an `add` and a `store` can lose an update. Both need `as`.

### Comparisons

```
lt a b as name
```

A comparison takes two values like an arithmetic statement and keeps `1` in the variable if it holds, `0` if not. It needs `as name`; an operand is any [argument](#arguments).

| Statement | `1` when |
|---|---|
| `eq a b` | `a` equals `b` |
| `ne a b` | `a` differs from `b` |
| `lt a b` | `a` is below `b` |
| `le a b` | `a` is below or equals `b` |
| `gt a b` | `a` is above `b` |
| `ge a b` | `a` is above or equals `b` |
| `slt a b`, `sle a b`, `sgt a b`, `sge a b` | the same four orderings with both values read as signed |

All 64 bits of both values are compared and the result is a full 64-bit `1` or `0`. Ordering is unsigned for `lt`, `le`, `gt` and `ge`, like `div` and `mod`: the result of `sub 0 1` is the largest value, so `lt 1 x` is `1` for it. `slt`, `sle`, `sgt` and `sge` order the same bits as signed numbers, where it is `-1` and below 1. `eq` and `ne` need no signed form. A comparison only produces a value; [`jz` and `jnz`](#control-flow) act on it.

```
sub 0 1 as m
gt m 1 as r             # r = 1
```

### Control flow

```
label name
jmp name
jz a name
jnz a name
jlt a b name

if a
...
else
...
end
```

`label` names the point in the program where it stands; it emits no code. `jmp` continues execution at a label. `jz` jumps if the value `a` is zero and `jnz` if it is not, otherwise execution goes on with the next line. All 64 bits of the value are tested, so a comparison result can be used directly. The value is any [argument](#arguments).

The compare-and-jump statements take two values and a label and jump if the comparison holds, without a variable for the result:

| Statement | Jumps when |
|---|---|
| `jeq a b`, `jne a b` | `a` equals `b`, differs from `b` |
| `jlt a b`, `jle a b`, `jgt a b`, `jge a b` | `a` is below, below or equal, above, above or equal, in unsigned order |
| `jslt a b`, `jsle a b`, `jsgt a b`, `jsge a b` | the same in signed order |

`jlt i 10 top` does what `lt i 10 as c` and `jnz c top` do, in one line and five tokens instead of eleven.

#### Blocks

`if a` runs the lines up to the matching `end` when `a` is not zero, and passes over them otherwise. With an `else` line in between, the lines after it run in the other case. The opening line comes in the same forms as the jumps:

| Statement | The block runs when |
|---|---|
| `if a`, `ifz a` | `a` is not zero, is zero |
| `ifeq a b`, `ifne a b` | `a` equals `b`, differs from `b` |
| `iflt a b`, `ifle a b`, `ifgt a b`, `ifge a b` | the unsigned comparison holds |
| `ifslt a b`, `ifsle a b`, `ifsgt a b`, `ifsge a b` | the signed comparison holds |

```
ifgt n 4096
sys 60 1                # too long
end
ifz n
set 1 as n
else
sub n 1 as n
end
```

Blocks nest, and `end` closes the innermost one that is open; only when none is open in a function does it end the function. A block is a jump and a label that need no name, nothing more: labels and jumps work inside and across blocks, and a block has no variables of its own. The check for [unassigned variables](#control-flow) treats it like the jumps it stands for: after `end`, a variable is assigned if both ways there assigned it.

A label may be defined before or after the jumps that use it, and a label after the last statement stands at the appended `exit(0)`. Each label is defined once. Label names follow the rules of variable names but are a separate name space: a label may share its name with a variable or a buffer, and may be called `as`. There is no limit on the number of labels or jumps.

```
set 0 as i
label top
sys 1 1 "x"
add i 1 as i
jlt i 3 top             # prints xxx
```

A jump does not touch any variable. A variable may only be read where every way to that line has assigned it: reading one on a path that may have jumped over its `as` is the error `unassigned variable`.

```
jz a skip
set 1 as x
label skip
sys 60 x                # error: the jump passes the as of x
```

The compiler follows the lines in order. At a jump it notes which variables are assigned; at a label it keeps those that are assigned on the line before, if execution can come from there, and at every jump to the label seen so far. After `jmp` or `ret` no way leads to the next line until a label, and such lines are not checked. Two rules follow for jumps that go back:

- A jump back to a label must come with every variable assigned that was assigned at the label. So assign a variable before the loop if a way into the middle of the loop exists, or simply before the first jump that could pass its `as`.
- A label that execution can only reach from jumps below it, like the body of a loop that is entered at its test, starts with the variables that were assigned before the `jmp` or `ret` above it.

The check does not know values: it treats both outcomes of `jz` and `jnz` as possible, and `sys 60` as a line that goes on. A `var` is zero from the start and is never unassigned.

Labels are local: a label defined inside a [function](#functions) exists only there, and the labels outside every function are not visible inside one. A jump therefore never enters or leaves a function, and the same label name can be reused in each function.


#### Loops

```
i=0
while i<10
    sys write 1 "x"
    i+=1
end
```

`while a` runs the lines up to the matching `end` again and again, as long as `a` is not zero when it is reached; the value is computed before each round, so the lines may run no time at all. The value is one [argument](#arguments), usually an expression. The test is compiled at both ends of the loop, so a round costs one compare and one jump, and a loop that counts down to zero (`while i` ... `i-=1`) only the subtraction and the jump.

A loop is a block: it nests with `if` blocks and other loops, `end` closes the innermost open one, and it must be closed in the function it was opened in. It has no `else`. Nothing leaves a loop but its value becoming zero, a `jmp` to a label, or a `ret`; there is no statement to end the round early, so put the rest of the round in an `if`.

A variable must have a value on every way to a line that reads it. After a loop that is what had a value before it, since the lines in it may not have run: a variable first assigned inside a loop cannot be read after it. What the compiler knows of an address is forgotten where a loop begins.

### Functions

```
fn name a b
...
ret value
end

call name x y as result
call name x y
```

A function can also return several values, and a `call` names one variable for each:

```
ret a b
call name x y as q r
```

`fn` starts a function and `end` closes it. The names after the function name are its parameters; there may be none and at most 64. A function cannot be defined inside another one. Where a function stands does not matter: top-level execution skips its body, and a `call` may come before or after the definition.

`call` passes its values to the parameters in order and runs the function. With `as`, the value the function returns is kept in a variable; without it the value is dropped. A value is any [argument](#arguments), and the number of values must equal the number of parameters; a string is two values, its address and its length, so that a function taking `p n` can be called with a literal.

Inside a function, a `call` of a short function that is defined before it costs no call: the compiler writes the body in its place, with the variables of the callee beside those of the caller and each `ret` a jump to the end of the body. Nothing a program computes changes, only its size and its time. A function is short if its code is at most 160 bytes; it must also stand before the call, have at most six parameters, no `local` and no `tail`, call no function but through `callp`, name no `buf`, `data` or `var`, and not be `async`; and the variables of both together must be 64 at most. Every other call is a call, as are all those at top level. A parameter that the function never assigns is then the caller's variable itself when the value is a variable, so a helper that only reads its parameters costs what its lines would cost written at the call ([the compiler notes](compiler.md#functions) say how, [the measurements](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#calls-compiled-in-place-2026-11-20) what it gains).

`ret` returns its values to the caller and is only allowed inside a function. It takes one to six values, and every `ret` of a function must take the same number: that is the number of results of the function. Reaching `end` returns `0` for each of them. A `call` may name fewer variables after `as` than the function has results, and the rest are dropped; naming more is the error `wrong result count`.

```
fn divmod a b
div a b as q
mod a b as r
ret q r
end
call divmod 47 5 as q r     # q = 9, r = 2
```

```
fn fact n
jz n one
sub n 1 as m
call fact m as r        # a function may call itself
mul n r as r
ret r
label one
ret 1
end
call fact 5 as x
sys 60 x                # exit(120)
```

Each function has its own variables and its own labels:

- The parameters are the function's first variables. Together with the variables it defines with `as`, a function has at most 64.
- A function sees none of the variables defined outside it, and its variables do not exist outside it. The same name can be used on both sides for different things. Values go in through the parameters and out through `ret`.
- Every call gets fresh variables: the caller's variables, at top level or in another function, are unchanged when the call returns, also when a function calls itself.
- Global names (`buf`, `data`, `var`, `const`) are visible in every function, and one declared inside a function is the same as one declared outside: its name may not be that of a top-level variable either. See [Names](#names) for what happens when a variable of a function has the name of a global.

Function names follow the rules of variable names but are a separate name space: a function may share its name with a variable, a buffer, a data name or a label, and may be called `as`. Each name is defined once. There is no limit on the number of functions or calls.

Calling convention: the first six values travel in `rax`, `rdi`, `rsi`, `rdx`, `r10` and `r8`, in order, with all 64 bits; the caller pushes any further values on the stack, in order, and removes them after the call. The results come back in the same six registers, the first in `rax`. `callp` has the address in `rcx`. The function saves those of the six variable registers that it uses when it starts and restores them when it returns.

#### Functions as values

```
ref name as p
callp p x y as result
```

`ref` keeps the address of a function in a variable, and `callp` calls the function whose address is its first value, passing the values after it. The function may be defined later. This is how a table of functions or a callback is written:

```
ref inc as f
callp f 10 as x         # the same as: call inc 10 as x
```

Nothing is known about the function at a `callp`: the number of values is not checked against its parameters, nor the names after `as` against its results, and an address that is not a function's is a fault at run time. Otherwise `callp` is a `call`: it has an optional `as` with one name per result wanted, and a string counts as two values.

#### Tasks

```
use "lib/std/task.aiw"
spawn name x y as h
join h as result
```

`spawn` submits the function `name` with up to five values as a task and keeps a handle of it; `join` waits until the task has run and keeps the first result of the function. Tasks are independent pieces of work that may run at the same time as the code that spawned them:

```
use "lib/std/task.aiw"
fn work a b
ret a*b
end
spawn work 6 7 as h
join h as x             # 42
```

The two statements are calls of the functions `spawn` and `join` of the program, which `lib/std/task.aiw` defines; without that `use` they are an `undefined function`. `spawn` needs `as` with one name. The number of its values is checked against the parameters of the function, which may be defined later; a string counts as two values. `join` takes the handle and an optional `as`.

- **The handle** is a number that stands for the task until its `join`. Every task is joined exactly once, by any function, in any order; `join` releases the task, and its handle means nothing afterwards. A task that is never joined keeps its 80 bytes. A handle is 0 when the kernel had no memory for the task, which then never runs; `join` of 0 gives 0.
- **The result** is the first value the function returns, 0 if it reaches its `end`. Further results are lost; a task with more to give writes it to memory it was passed.
- **When it runs** is not defined: at some time between its `spawn` and the return of its `join`, on another thread or inside `join` itself. A program must be right in every such order.
- **Memory**: a task shares all memory with the rest of the program, `var` cells and buffers included. What a task wrote is there for the code after its `join`. Before that, a cell that the task and other code both touch, one of them writing, is only safe through [`xadd` and `cas`](#atomic-operations). Memory whose address is passed to a task must stay valid until its `join` has returned: a `buf` always is, an `alloc` until its `free`, and a `local` if the function that owns it joins the task before it returns.
- **Errors**: a task has no failure of its own. What it reports, it reports in its result. A fault in a task (a trap of `at`, a division by zero, a bad address) ends the whole program, as anywhere else.
- **The end of the program**: reaching the last line ends the program with every task, run or not. So does `sys exit_group`; `sys exit` ends only the thread that runs it.

**The pool.** Tasks are run by worker threads that `lib/std/task.aiw` starts when they are needed and keeps for the tasks that follow; a program that never reaches a `spawn` starts none and runs no code of the library.

```
call workers 4
```

- `spawn` puts the task in a queue. If a worker is asleep it wakes one; if more tasks wait than workers sleep, and fewer workers exist than the limit, it starts one. A worker runs task after task and sleeps in the kernel when the queue is empty. Workers never end before the program does.
- The limit is the value of the last `call workers n`, or, if the program never calls it, the number of processors the process may run on (`sched_getaffinity`), found at the first `spawn`. `workers 0` starts no thread. Workers already started stay when the limit is lowered.
- `join` of a task that is still in the queue runs it on the joining thread; `join` of a task that a worker took sleeps until it is done. So at most the limit plus the joining threads run tasks at once, a task may spawn and join tasks of its own with any limit, and a program is correct with no worker at all. A task never moves between threads once it has started.
- A worker has a stack of 8 MiB with a closed page below it: a task that needs more is a fault (`SIGSEGV`), which ends the program. A task run by `join` uses the stack of the joining thread.
- If the kernel refuses a thread or its stack, the task stays in the queue for another worker or its `join`.
- How large a task should be: about ten times as many tasks as threads, each of 100 microseconds of work or more, is a good start. Between 30 microseconds and 3 milliseconds a task the gain does not depend on the size; one task for each thread loses a sixth to a quarter of it at 14 and 20 threads, since nothing evens out unequal pieces and cores; tasks of 3 microseconds lose a fifth at 8 threads and most of the gain at 20; work that is bound by memory gains little beyond 4 threads ([measured](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md#the-size-of-a-task-at-each-number-of-threads)).
- The costs: a task is 80 bytes, taken from blocks of 64 KiB that the library asks of the kernel as needed and never gives back, and used again after its `join`; `spawn` and `join` take a lock for a few instructions each, and enter the kernel only to wake or start a worker or to sleep.
- The library owns the names `spawn`, `join`, `workers` and every name that starts with `task`: its other functions, its buffer and all its variables. A program has no `var` of such a name, since `as` on the name of a `var` writes the cell in any function, the library's included. Threads share the program's `var` cells and, at top level, the variables after the sixth, which live in cells: code that tasks run belongs in functions, whose variables are their own.

#### Async functions

```
use "lib/async/task.aiw"
async fn name a b
...
ret x
end
call name 1 2 as h
```

`async fn` defines a function that runs as a task of [the async library](#the-async-library). A call of it runs none of its lines: it makes the task, with the values of the call as its parameters, puts it in the queue and returns its handle, which is the one result of the call. The lines run when the task is polled, and the value of its `ret` is the result of the task, which `await` gives:

```
use "lib/async/task.aiw"
async fn mul a b
ret a*b
end
call mul 6 7 as h
await h as x            # 42
await mul 2 3 as y      # 6: the call and the await in one
```

`await` waits for a task or an event and keeps its result; `as` is optional and takes one name. It has two forms, told apart by its first word:

- **`await h as x`**: the word is a variable of the scope or a global name, or the value is a number or an expression. It is the handle to wait for.
- **`await name a b as x`**: any other name is a function. It is called with the values, as `call` does and with the same checks, and its first result is the handle. The function is an async function, or any function that returns a handle, such as `asyncsleep` or `asyncread`: `await asyncsleep 100`. A function with the name of a variable is reached with `call` and an `await` of its handle.

What `await` does depends on where it stands:

- **In an async function** the task waits: if the result is not there yet, the function returns to the code that polls, which runs other tasks, and goes on at the `await` when the result has come. Nothing of the stack is kept over that, and nothing needs to be: the variables and locals are in the record. An `await` may stand anywhere a statement may, in loops and blocks. Started work that is awaited later runs meanwhile:

```
call fetch a as h
call fetch b as g       # both are under way
await h as x
await g as y
```

- **At top level and in a plain function** there is no task to put aside: `await` polls tasks until the one it waits for is done, and that is how a program runs its tasks. If nothing can happen any more before that, the result is -35.

The statement is a call of the function `await` of the program, which `lib/async/task.aiw` defines, with the handle and the task that asks, or 0; without that `use` it is an `undefined function await`. A handle is awaited once, and means nothing afterwards.

- An async function has at most six parameters. `ret` takes exactly one value; reaching `end` gives the result 0. `tail` is `not allowed here`. Everything else is as in any function, `spawn` and `join` included, which hold the thread while they wait, and it is called, counted and named like one: `call`, `ref` and a forward use work, and `wrong argument count` is reported the same way.
- The task is made by the function `async` of the program, which `lib/async/task.aiw` defines; without that `use` an async function is an `undefined function async`.
- **Its variables live in the record of the task** where they are in use across an `await`, so that they are there when the task goes on after a wait; a use of such a variable is a use of memory, and so is one of a parameter. A variable that no `await` falls into, computed and read between two of them, is in a register as in any function, so a loop between two waits costs what it costs elsewhere. A `local` is in the record too, so its address stays valid for the whole life of the task, and a large one makes a large record.
- The handle is 0 if there was no memory for the record; `await` of 0 gives 0.

#### Recursion and the stack

A call uses 8 bytes of stack for the return address, 8 for each register the function saves, 8 for each value after the sixth, 8 for each variable that did not get a register and the bytes of its [locals](#local). A function with two variables, like `fact` above, takes 24 bytes a call, so the usual 8 MiB stack allows some 350000 nested calls.

When the stack runs out, the program dies with `SIGSEGV` (exit status 139 in a shell): the kernel keeps an unmapped guard below the stack, and a function whose frame is a page or more enters it a page at a time, so the guard is hit and never jumped over. Nothing else is checked.

```
tail name x y
```

`tail` calls a function and returns its results, all of them, as `call name x y as r` followed by `ret r` would for one, but it releases the frame of the current function first and jumps: the callee returns directly to the caller's caller, and the stack does not grow. A function that ends each round with a `tail` to itself is a loop, however many rounds it takes:

```
fn count n acc
jz n done
sub n 1 as n
add acc 1 as acc
tail count n acc        # ten million rounds use one frame
label done
ret acc
end
```

`tail` is only allowed inside a function, takes no `as` and at most six values, since values on the stack would lie in the frame it gives up. No way leads to the line after it.

A `tail` is a return, so its target has as many results as the function it stands in: as the `ret` statements of that function take values, and if it has none, the number of results of the function is that of the target, through as many functions as only pass on. A target with another number is the error `wrong result count`, at the `tail`. Functions that only tail to each other and reach no `ret` never return; they fit any number.

**In a function that has a `local`** the frame is not given up: the callee may be reading the local, through an address among the values, in a variable or in memory, which the compiler cannot follow. There `tail` is the call followed by the return of all its results, and the frame stays until the callee has returned. The program means the same; what it loses is the loop: each round of a function that has a local and ends with a `tail` to itself uses a frame. A function that is to run without a growing stack has no `local`, and keeps such bytes in a `buf` or an `alloc`.

### `buf`

```
buf name size
```

Reserves `size` bytes of writable memory, filled with zeros when the program starts, and makes `name` their address. `size` is an [integer](#integers) or the name of a [`const`](#const) and is rounded up to a multiple of 8, so every buffer is 8-byte aligned. A size of 0 is allowed: the name is then an address with no bytes of its own, for instance a mark between two buffers.

A buffer name is a constant, not a variable: it uses none of the variables of a scope, and it can be used wherever a value is accepted, as one argument. It may be declared before or after the lines that use it. Variables and global names (buffers, data, [`var`](#var) and [`const`](#const)) share one name space. There is no limit on the number of buffers, and together they may take almost 2 GiB; the memory is reserved when the program is loaded, costs nothing until it is touched, and is never freed. Larger storage comes from [`alloc`](#alloc-and-free).

```
buf line 4096
sys 0 0 line 4096 as n     # read stdin into it
sys 1 1 line n             # write what was read
```

### `local`

```
local name size
```

Reserves `size` bytes in the frame of the function it stands in and makes `name` their address. The bytes exist while that call runs: every call has its own, also when a function calls itself, and they are gone when it returns, so their address must not be kept or returned. They are **not** zero-filled. `size` is an integer or a `const`, rounded up to a multiple of 8; 0 is allowed.

```
fn show n
local line 8
add n 48 as d
storeb line d
add line 1 as p
storeb p 10
sys 1 1 line 2
end
```

`local` is only allowed inside a function. The name counts as one of the 64 variables of the function and follows their [rules for names](#names), but it is not a variable: `as` cannot assign it. The locals of one function may take about 2 GiB together, far more than a stack holds; a call uses 8 bytes of stack for each 8 bytes of locals.

### `alloc` and `free`

```
alloc size as p
free p
```

`alloc` asks the [runtime](#rt) for `size` bytes of memory at run time and keeps their address in a variable, or 0 if there are none to be had. The bytes are zero-filled and the address is a multiple of 16. `free` gives back what one `alloc` returned; `free 0` does nothing. After `free` the address must not be used again.

```
alloc n as p
jz p fail
...
free p
```

The two statements are the services `alloc` and `free` of the runtime. On Linux each `alloc` is a memory mapping of its own (`mmap` and `munmap`, with 16 bytes in front for the length), so it costs a system call and at least a page: use it for storage whose size is only known at run time, a `buf` for what is fixed and a `local` for what a call needs. Both statements overwrite the registers of the [`sys`](#sys) arguments; variables are untouched.

### `var`

```
var name name ...
```

Declares global 64-bit cells, zero when the program starts. A `var` name is used like a variable: as an argument it passes the value of the cell, and `as name` stores a result in it. Unlike a variable it is visible in every function and does not count among the variables of a scope, so it is the way to share state between functions.

```
var count
fn tick
add count 1 as count
end
call tick
call tick
sys 60 count            # exit(2)
```

A `var` must be declared on an earlier line than its uses, at top level or inside a function, and lives for the whole program either way. Its name cannot be that of a parameter, and it has no address: `len` does not take it. There is no limit on the number of vars.

### `const`

```
const name number
```

Gives a number a name. The name is used wherever a value is accepted and passes the number; it is also accepted as the syscall number of `sys` and as the size of a `buf`, where a variable is not. A `const` costs nothing at run time and takes no register. It must be declared on an earlier line than its uses, and at top level it cannot be the target of `as`.

```
const exit 60
const size 4096
buf line size
sys exit 0
```

### `data`

```
data name item item ...
data item item ...
```

Puts read-only bytes into the program and makes `name` their address. An item is a [string](#strings), which gives its bytes, or an [integer](#integers) from 0 to 255, which gives one byte; there must be at least one item. Nothing is added: no terminator, no padding, no alignment.

```
data msg "hello" 10
len msg as n            # n = 6
sys 1 1 msg n
```

A data name is a constant like a buffer name: one value, its address, wherever a value is accepted, and it may be declared after the lines that use it. There is no limit on the number of data statements.

`data` statements on consecutive lines are laid out one after the other with nothing between them, so a table can be written a row a line. The name is optional, since only the first row needs one; a name on a later row is the address of that row. A `label` or any statement that produces code ends the run.

```
data days 31 28 31 30 31 30
data 31 31 30 31 30 31
add days 7 as p
loadb p as n            # n = 31, the eighth byte
```

The bytes stand in the code where the statement is, and execution passes around them, so `data` may be written anywhere, also inside a function. They are read-only: a store to them is rejected when the compiler can see it, and otherwise kills the program with `SIGSEGV`.

### `len`

```
len name as n
len "text" as n
```

Keeps the length in bytes of a buffer, a data name or a string in a variable: for a buffer the size as declared, before rounding; for a data name the bytes of its own statement, not of the rows after it. The operand cannot be a number, a variable, a `var` or a `const`.

### `at`

```
at name offset count as p
```

Keeps in a variable the address of the byte at `offset` in the object `name`, after checking **at run time** that `count` bytes from there lie inside it. If they do not, the program stops with an illegal instruction (`SIGILL`, exit status 132 in a shell) instead of touching memory it was not given.

```
buf table 800
at table i 8 as p       # traps unless i + 8 <= 800
load p as x
```

`name` is a buffer, a data name or a [local](#local): an object whose size the compiler knows. It may be declared later. The size is the one declared, and for a data name the bytes to the end of its run, as for the [compile-time check](#load-and-store). `offset` and `count` are any values; an offset that is negative when read as signed, or a sum that wraps, traps like one that is too large. A count of 0 at the very end is allowed.

`at` is the checked form of `add name offset as p`. It costs a comparison and two more tokens, and it only covers the bytes it was asked about: a later `load` of 8 bytes after an `at` with count 1 is not checked.

### `load` and `store`

```
load addr as name       # 64-bit value at addr
load4 addr as name      # 32-bit value at addr, zero-extended
load2 addr as name      # 16-bit value at addr, zero-extended
loadb addr as name      # byte at addr, zero-extended
store addr value        # write the 64 bits of value at addr
store4 addr value       # write the low 32 bits of value at addr
store2 addr value       # write the low 16 bits of value at addr
storeb addr value       # write the low byte of value at addr
```

`addr` is any value: a buffer or data name, a variable holding an address, a string or an integer. Loads need `as name`; stores do not take it. Values are little-endian in memory and need no alignment. A narrow store writes only its own bytes and leaves the ones after them. Nothing is checked at run time: an address outside mapped memory or in read-only memory kills the program with `SIGSEGV`.

The compiler rejects an access that it can prove wrong, with the error `invalid access`. It knows an address when it is a buffer or data name, a string, or a variable that `set`, `add` and `sub` computed from one of those and from numbers on the lines before, with no label in between:

- a load or store that does not lie inside the buffer, counting the size as declared, not as rounded: `buf b 4` followed by `store b 1` writes 8 bytes into 4;
- a load that does not lie inside the data, which for a data name reaches to the end of its run of consecutive `data` lines, or inside the string;
- any store into data or into a string.

```
buf b 16
add b 12 as p
store p 0               # error: bytes 12 to 19 of a 16-byte buffer
```

After a label, after any other statement that assigns the variable, and for a parameter or a `var`, the compiler knows nothing and checks nothing. It is a help against slips, not a guarantee.

```
buf b 8
storeb b 104            # "h"
add b 1 as p
storeb p 10             # newline
sys 1 1 b 2
```

## Arguments

### Integers

```
4096
0xff
-1
```

A decimal integer from 0 to 18446744073709551615, or `0x` followed by one to sixteen hexadecimal digits (`a` to `f` in either case; the `x` is lower case). A `-` directly before either form gives the two's complement, down to -9223372036854775808. All are 64-bit values: `-1` and `0xffffffffffffffff` are the same. There are no separators and no other sign.

A literal that does not fit 64 bits is the error `number too big`; nothing wraps silently. Arithmetic still wraps.

### Strings

```
"text"
```

In `sys` and `call` a string literal counts as **two** arguments: the address of its bytes, then its length in bytes. This matches the `buf, count` pair that syscalls such as `write` take, so the length never has to be written out:

```
sys 1 1 "hello world\n"     # write(1, addr, 12)
```

In every other statement a string is **one** value, the address of its bytes (`set "abc" as p`), except in [`len`](#len), where it is its length. Each literal has its own bytes, also when two are equal; use [`data`](#data) to name bytes that are used more than once.

Strings are not NUL-terminated; add `\0` if the callee needs it (it then counts towards the length). String data is read-only at run time.

| Escape | Byte |
|---|---|
| `\n` | 10, newline |
| `\t` | 9, tab |
| `\0` | 0 |
| `\xHH` | the byte with the hexadecimal value `HH`, two digits, `a` to `f` in either case |
| `\\` | backslash |
| `\"` | double quote |

A backslash before any other character yields that character. A string may span lines; the newline is included as-is.

### Variables

```
sys 1 1 "abc\n" as n     # n = 4, the number of bytes written
sys 60 n                 # exit(4)
```

A variable is a name for a 64-bit value, held in a machine register when one is free. A name starts with a lowercase letter and continues with lowercase letters, digits and `_`. `as` is reserved.

`as name` at the end of a statement defines the variable and stores the statement's result in it; after a `call`, several names take the several results of the function. For `sys` that is the syscall's raw return value: the result, or a negative error number. Nothing but a comment may follow it on the line. Using `as` with a name that already exists overwrites that variable. `as` is the only way to set a variable; `set 5 as x` sets one to a constant.

A variable used as an argument passes its full 64-bit value and counts as one argument. It must be defined by an earlier `as`, and it cannot be the syscall number.

Statement keywords are only special at the start of a line, so `add` or `buf` are valid variable names.

A variable belongs to the top level or to one function. State that several functions share goes into a [`var`](#var).

The top level of a program can define at most 64 variables, and so can each [function](#functions), counting its parameters. Six registers hold variables: `rbx`, `rbp`, `r12`, `r13`, `r14` and `r15`; syscalls and calls do not change them.

- At top level the first six variables get the registers, in order of definition, and each later one a memory cell of its own.
- In a function a variable needs a place only from its definition to the last line that mentions it, or to the end of a loop that it is used in, where a loop is the lines between a label and a jump back to it. A register whose variable is done is given to the next variable defined, so a function can use many short-lived variables without leaving the registers. When all six are busy, the variable lives on the stack.

Where a variable lives changes the speed and size of the code, never its meaning.

Variables hold values only. Memory is always reached through an explicit address: a [buffer](#buf), a [local](#local), or one obtained at run time:

```
alloc 4096 as p               # 4096 zero-filled bytes
sys 0 0 p 4096 as n           # read stdin into them
sys 1 1 p n                   # write what was read
```

### Names

A name used as a value is looked up in this order:

1. a variable of the current scope (the top level, or the function the line is in) that an earlier line defined with `as` or as a parameter;
2. a global name declared on an earlier line: a `buf`, `data`, `var` or `const`;
3. otherwise it is taken as the address of a `buf` or `data` declared on a later line. If the source ends without one, that is `undefined variable`. A `var` or a `const` must come before its uses.

At top level a name means one thing: a variable and a global name cannot share a name, whichever comes first. Inside a function, a parameter or a variable may have the name of a `buf`, `data` or `const`; from its definition to the `end` of the function the name means the variable, and the global is untouched. A `var` is never hidden: `as` with its name writes the cell, and a parameter with its name is an error.

```
buf b 8
fn f b                  # this b is the parameter
ret b
end
call f 9 as x           # x = 9
storeb t x              # t is declared below
buf t 8
```

### Addresses

An address is a 64-bit integer like any other value. Its number is not fixed: the kernel loads a program at a different place on each run, so the address of a buffer, of data or of a function is only the same within one run. Distances between two addresses of the same program do not change. It can be computed, compared, stored in memory, passed to a function and handed to the kernel, and nothing in the language records where it came from or how long it stays valid. That is deliberate: the language describes what the machine does, and the machine has no pointers, only numbers.

What the language offers against mistakes is therefore local and explicit:

- the compiler rejects an access it can prove wrong ([`load` and `store`](#load-and-store)) and a read of a variable that may be unassigned ([control flow](#control-flow));
- [`at`](#at) checks an offset at run time where the program asks for it;
- the lifetime of storage follows from how it was obtained: a `buf` and `data` live as long as the program, a [`local`](#local) until its function returns, and an [`alloc`](#alloc-and-free) until its `free`, after which the memory is unmapped and a use of it faults instead of reading stale bytes, unless a later `alloc` was given the same pages.

There is no ownership or borrow checking. A function receives addresses as plain values and may keep them; a syscall receives them the same way.

### Expressions

```
sys exit 2+3*4
storeb out+1 10
store b+8*(n-1) 0x10<<4
```

An argument may be an expression: values joined by operators, written **without a space**. Spaces separate the arguments of a statement, so `5-1` is one value and `5 -1` is two, the second a negative number. An expression stands wherever a statement takes a value; it does not stand where a name is required (the first value of `at`, the operand of `len`, a label, a name after `as`) or for the number of `sys`.

| Operators | Meaning | Binds |
|---|---|---|
| `*` `/` `%` | product, unsigned quotient and remainder | tightest |
| `+` `-` | sum and difference | |
| `<<` `>>` | shifts, the right one zero-filled | |
| `&` | bitwise and | |
| `^` | bitwise exclusive or | |
| `\|` | bitwise or | |
| `==` `!=` `<` `<=` `>` `>=` | comparison, unsigned, giving 1 or 0 | loosest |

Operators of one row are taken from left to right: `7-2-1` is 4. Parentheses group and may nest: `(2+3)*4`. This is the order of Rust, not of C: a shift binds tighter than `&`, and every bitwise operator tighter than a comparison, so `x&1==0` tests the low bit. The operators do what the statements of the same meaning do (`add`, `shr`, `lt`, ...): 64 bits, wrapping, a shift by the low 6 bits of its count.

A value in an expression is a number, a `const`, a variable, a `var`, or the name of a buffer or of data, which is its address. A `-` before a digit where a value is expected belongs to the number: `2+-1` is 1; there is no other unary operator, so write `0-x`. A string is not a value in an expression.

The compiler computes what it can: an expression of numbers and consts is the number, and a buffer or data name plus or minus a number is one address, checked like any [address](#addresses) the compiler knows: with `buf b 8`, `storeb b+8 0` is `invalid access`. A division by a constant zero is not computed; it fails when it runs.

A load or a store takes its address as an expression and uses it as the operand of one instruction where it has the form of one: `load p-8 as v`, `storeb s+i 1`. A statement and the expression that says the same compile to the same code: `add a b as x` and `x=a+b`, `jlt a b l` and `jnz a<b l`, `iflt a b` and `if a<b`. A comparison that is the whole value of `if`, `ifz`, `jz` or `jnz` is one compare and one jump, and so `if`, `jz` and `jnz` with an expression replace the twelve unsigned statements that compare and jump or open a block; the signed ones have no operator.

The rest is computed when the program runs, the operands of an operator from left to right. Nothing in an expression can fail except a division or a remainder by zero, which kills the program with `SIGFPE` as `div` and `mod` do.

## The io library

`lib/std/io.aiw` is a file of functions written in AIL for what almost every program needs. A program compiled from the top of the repository gets it with `use "lib/std/io.aiw"`; put that line first, since it also records the program's arguments where it stands.

| Function | Does |
|---|---|
| `print p n` | writes the `n` bytes at `p` to stdout, repeating the write until all are out; returns 1, or 0 after an error |
| `eprint p n` | the same to stderr |
| `fdwrite fd p n` | the same to the file `fd` |
| `die p n` | writes the bytes to stderr and ends the program with status 1, with every thread (`exit_group`) |
| `putn n` | prints `n` as an unsigned decimal number; returns like `print` |
| `strlen p` | the length of the NUL-terminated string at `p` |
| `argc` | the number of arguments, the program's name included |
| `argv i` | two results: the address and the length of argument `i`, or 0 and 0 if there is none |

```
use "lib/std/io.aiw"
call argv 1 as p n
ifz p
call die "usage: greet name\n"
end
call print "hello "
call print p n
call print "\n"
```

A string literal is the two values that `print` takes. The library defines no global name besides its functions, has no line that runs where the `use` stands, and asks the [runtime](#rt) for everything it does, so it is the same on every platform. All its variables and parameters have names that start with `io`: a program has no `var` of such a name, since `as` on the name of a `var` writes the cell in any function.

## The bytes library

`lib/std/bytes.aiw` is a buffer of bytes that grows as bytes are added, for text whose length is not known when the program is written. The buffer is 24 bytes that the caller owns, in a `buf` or a `local`: the address of the bytes, their number, and the room at that address. All zero is an empty buffer, so a `buf` is one as it stands and a `local` after three stores of 0. The functions take the address of those 24 bytes.

| Function | Does |
|---|---|
| `byadd b p n` | adds the `n` bytes at `p`, which are not bytes of the buffer itself |
| `byaddb b c` | adds the byte `c` |
| `byaddn b v` | adds `v` as an unsigned decimal number |
| `byneed b n` | makes room for `n` more bytes |
| `bycut b n` | keeps the first `n` bytes, not more than there are |
| `byfree b` | gives the bytes back to the kernel; the buffer is empty and may be used again |
| `bycopy d s n` | copies `n` bytes from `s` to `d`, which do not overlap; any memory, not only a buffer |

```
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
buf b 24
call byadd b "total "
call byaddn b 42
call byaddb b 10
load b as p
load b+8 as n
call print p n
```

- **Growth**: `byadd`, `byaddb`, `byaddn` and `byneed` may move the bytes: when the room is used up they take twice as much with `alloc` (at least 4096 bytes), copy, and `free` the old. An address into the bytes is therefore only good until the next of those four calls; a place that must survive them is kept as an offset from the start. After `byneed b n` the next `n` bytes added move nothing.
- **Errors**: the four return 1, or 0 when the kernel has no memory or the new length would not fit in 64 bits; the buffer is then as it was. Nothing else can fail and nothing is checked: `bycut` beyond the length and a buffer that is not 24 bytes of the caller's are faults of the program.
- **Ownership**: the caller owns the 24 bytes and ends the buffer with `byfree`; a buffer in a `local` is freed before its function returns. The bytes are read at the address in the first 8 bytes, with the length in the next 8.
- **Names**: the library owns every name that starts with `by`; a program has no `var` of such a name.

## The file library

`lib/std/file.aiw` reads a whole file into a buffer of the bytes library and writes one from memory; a program that uses it has `use "lib/std/bytes.aiw"` before it. A path is an address and a length, as a string literal and the two results of `argv` are, without a NUL byte and shorter than 4096 bytes.

| Function | Does |
|---|---|
| `fileread p n b` | adds the bytes of the file at the path to the buffer `b`; returns their number |
| `filereadfd fd b` | the same from an open descriptor, up to the end of the file; the descriptor stays open |
| `filewrite p n d dn` | makes the file at the path hold the `dn` bytes at `d` and nothing else, creating it with mode 0666 less the umask; returns 0 |
| `fileopen p n flags mode` | opens the path with the flags and mode of the service [`open`](#rt), plus the flag that closes it in a program the process starts; returns the descriptor, which the caller closes |
| `filemkdir p n mode` | makes the directory at the path, with the mode less the umask; returns 0 |
| `fileunlink p n` | removes the file at the path; returns 0 |
| `filermdir p n` | removes the empty directory at the path; returns 0 |
| `filenames p n b` | adds the names in the directory at the path to the buffer `b`, each with a NUL byte after it, without `.` and `..`, in the order of the kernel; returns their number |

```
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
use "lib/std/file.aiw"
buf b 24
call argv 1 as p n
call fileread p n b as r
ifslt r 0
call die "cannot read\n"
end
load b as q
call filewrite "copy" q r
```

- **Errors**: a result below zero is the error of the [runtime](#rt), which the library asks for everything: -2 no such file, -13 not allowed, -21 a directory, -17 there already, -39 a directory that is not empty, -12 no memory, -36 a path of 4096 bytes or more. Test it with a signed comparison (`ifslt r 0`). After a failed `fileread` the buffer holds what was read until then; after a failed `filewrite` the file may hold a part. A call interrupted by a signal is repeated.
- **Descriptors**: `fileread` and `filewrite` close what they open, on every way out. `fileopen` and `filereadfd` leave that to the caller.
- **Growth**: `fileread` and `filereadfd` grow the buffer as `byadd` does, 64 KiB of room at a time, so an address into it is not good afterwards.
- **Names**: the library owns every name that starts with `file`; a program has no `var` of such a name.

## The process library

`lib/std/proc.aiw` starts another program as a child process and waits for it; a program that uses it has `use "lib/std/io.aiw"` before it, which knows where the arguments and the environment are.

| Function | Does |
|---|---|
| `procstart argv in out err` | starts the program `argv` names, with the descriptors `in`, `out` and `err` as its 0, 1 and 2; returns the number of the child |
| `procheld argv in out err` | the same, with a child that the kernel kills when this process ends |
| `procwait pid ms` | waits until the child has ended, at most `ms` milliseconds (0: without limit), and returns how it ended |
| `procenv` | the environment of this process: the address of the addresses of its `NAME=value` strings, with a 0 after the last |
| `procvar p n` | two results, the address and length of the value of the variable named by the `n` bytes at `p`, or 0 and 0 |
| `procnow` | the time of the clock that only goes forward (`CLOCK_MONOTONIC`), in nanoseconds |
| `procpin cpu` | binds this thread, and the children it starts afterwards, to the processor `cpu`, or to the lowest it may run on if that is none of them; returns the processor, or a negative error number |

```
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
use "lib/std/file.aiw"
use "lib/std/proc.aiw"
data sh "/bin/sh" 0
data c "-c" 0
data s "ls | wc -l" 0
buf av 32
store av sh
store av+8 c
store av+16 s
call fileopen "count.txt" 0x241 420 as o
call procstart av -1 o -1 as p
sys close o
call procwait p 10000 as r
```

- **Arguments**: `argv` is the address of the addresses of the arguments, strings with a NUL byte at the end, with a 0 after the last: what the kernel takes, and what `data` lines and a `buf` build. The first is the program: a path if it has a slash, else a name that is looked for in the directories of `PATH` (`/usr/bin:/bin` without one).
- **Descriptors**: -1 for `in`, `out` or `err` leaves the child the descriptor of this process. The three may be one another's: 2 as `out` and 1 as `err` swaps the two outputs. A child whose descriptors cannot be put in place, one of them not being open for instance, ends with status 127 and starts no program. Any other descriptor stays open in this process, whose business it is to close it; one opened by `fileopen` is closed in the child by itself. A child whose output goes to a pipe that nobody reads stops when the pipe is full, so send output that is wanted to a file and read the file after `procwait`.
- **The child** has the environment of this process. It is another process (`fork`): it shares no memory with this one, and of a program with tasks only the thread that called is in it.
- **A child that is held**: `procheld` starts a child as `procstart` does and tells the kernel to kill it (`SIGKILL`) when the thread that started it ends, however it ends. A program that is itself killed, by `procwait` of its parent when its time is up for instance, then leaves no such child running. What the child starts is not held by this: a chain is held when each program in it starts its children this way. A program that changes its user or group as it starts is not held. Where the kernel refuses the request (a filter of system calls that denies `prctl`), the program is not started: the child ends with status 127.
- **Errors**: `procstart` returns a negative number when the kernel refuses a process (the error of `fork`, negated). A program that cannot be started is a child that ends with status 127.
- **The result of `procwait`** is the exit status, 0 to 255; or the number of the signal that ended the child, negated (-9, -11); or -1000 if the child still ran when the time was up, in which case it was killed (`SIGKILL`) before the return; or -1001 if there is no such child. Every child is waited for exactly once, which takes it from the kernel; after that its number means nothing. Only the child itself is killed, not what it started. The limit holds also when the kernel gives no descriptor for the child (`pidfd_open` fails at the limit of open files): the child is then asked about every millisecond.
- **Names**: the library owns every name that starts with `proc`; a program has no `var` of such a name.

## The vector library

`lib/std/vec.aiw` is an array of 64-bit values that grows as values are added. The vector is 24 bytes that the caller owns, in a `buf` or a `local`: the address of the values, their number, and the number there is room for. All zero is an empty vector, so a `buf` is one as it stands and a `local` after three stores of 0. The functions take the address of those 24 bytes. A value has an index, from 0.

| Function | Does |
|---|---|
| `vecpush v x` | adds the value `x` behind the last; returns 1 |
| `vecpop v` | takes the last value off; returns it and 1, or 0 and 0 if there is none |
| `vecget v i` | returns the value at the index `i` and 1, or 0 and 0 if there is none |
| `vecset v i x` | makes `x` the value at the index `i`; returns 1, or 0 if there is none |
| `vecreserve v n` | makes room for `n` values in all, not `n` more; returns 1 |
| `vecfree v` | gives the values back to the kernel; the vector is empty and may be used again |

```
use "lib/std/io.aiw"
use "lib/std/vec.aiw"
buf v 24
call vecpush v 30
call vecpush v 12
call vecget v 0 as a ok
call vecpop v as b ok
call putn a+b
```

- **Growth**: `vecpush` and `vecreserve` may move the values: `vecpush` takes twice the room with `alloc` when none is left (at least 512 values), copies, and `free`s the old; `vecreserve` takes exactly what it is asked for, and nothing if there is that much. An address of a value is therefore only good until the next of those two calls, an index always. After `vecreserve v n` the vector moves nothing until it holds `n` values.
- **Errors**: the two return 1, or 0 when the kernel has no memory or the room would not fit in 64 bits of bytes; the vector is then as it was, values and room. `vecpop`, `vecget` and `vecset` test the index against the number of values, and the second result says whether there was a value, since a value may be 0. A vector that is not 24 bytes of the caller's is a fault of the program.
- **Ownership**: the caller owns the 24 bytes and ends the vector with `vecfree`; a vector in a `local` is freed before its function returns. The values are read at the address in the first 8 bytes, with their number in the next 8.
- **Names**: the library owns every name that starts with `vec`; a program has no `var` of such a name.

## The queue library

`lib/std/queue.aiw` is a queue of 64-bit values with a fixed room: values leave in the order they came. The queue is 32 bytes that the caller owns, in a `buf` or a `local`: the address of the values, the number there is room for, the index of the oldest and the number it holds. The functions take the address of those 32 bytes. It needs no other library and no task: a program without `async` uses it as it stands.

| Function | Does |
|---|---|
| `queueinit q n` | gives a queue that is all zero room for `n` values; returns 1 |
| `queuepush q x` | adds the value `x` as the newest; returns 1, or 0 if the queue is full |
| `queuepop q` | takes the oldest value out; returns it and 1, or 0 and 0 if the queue is empty |
| `queuefree q` | gives the room back to the kernel; the queue is all zero and may be given room again |

```
use "lib/std/io.aiw"
use "lib/std/queue.aiw"
buf q 32
call queueinit q 8
call queuepush q 30
call queuepush q 12
call queuepop q as a ok
call queuepop q as b ok
call putn a-b
```

- **Storage**: one `alloc` in `queueinit`, a ring: the value after the last place is at the first. The room never changes and a value never moves. A queue that is all zero, as a `buf` is, has no room: it is full and empty at once. Room for 0 values is allowed and is the same.
- **Errors**: `queueinit` returns 0 when the kernel has no memory or the room would not fit in 64 bits of bytes, and the queue is then as it was. A full queue and an empty one are results, not faults: 0 from `queuepush`, 0 and 0 from `queuepop`, whose second result says whether there was a value, since a value may be 0. `queueinit` on a queue that has room loses that room.
- **Ownership**: the caller owns the 32 bytes and ends the queue with `queuefree`; the number of values is read at 24 of them.
- **Names**: the library owns every name that starts with `queue`; a program has no `var` of such a name.

## The heap library

`lib/std/heap.aiw` gives the smallest of the 64-bit values put into it, in the unsigned order. A heap is a vector of the vector library, and a program that uses it has `use "lib/std/vec.aiw"` before it: 24 bytes that the caller owns, all zero for an empty heap.

| Function | Does |
|---|---|
| `heappush h x` | adds the value `x`; returns 1 |
| `heappeek h` | returns the smallest value and 1, or 0 and 0 if there is none |
| `heappop h` | takes the smallest value out; returns it and 1, or 0 and 0 if there is none |
| `heapfree h` | gives the values back to the kernel; the heap is empty and may be used again |

```
use "lib/std/io.aiw"
use "lib/std/vec.aiw"
use "lib/std/heap.aiw"
buf h 24
call heappush h 30
call heappush h 12
call heappush h 50
call heappop h as a ok
call heappeek h as b ok
call putn a+b
```

- **Order**: the value at the index `i` of the vector is not larger than those at `2i+1` and `2i+2`, so the first is the smallest; a new value moves up from the end and, when the first is taken, the last moves down from the top, a number of steps that is the logarithm of the number of values. Of equal values any may come first.
- **Growth**: `heappush` grows the vector as `vecpush` does, so an address of a value is not good after it. The functions of the vector library may read a heap (`vecget`, the number of values at 8) but a value written with `vecset` or `vecpush` breaks the order.
- **Errors**: `heappush` returns 0 when there is no memory, and the heap is then as it was. The second result of `heappeek` and `heappop` says whether there was a value, since a value may be 0.
- **Ownership**: the caller owns the 24 bytes and ends the heap with `heapfree`.
- **Names**: the library owns every name that starts with `heap`; a program has no `var` of such a name.

## The map library

`lib/std/map.aiw` keeps a 64-bit value for each of any number of 64-bit keys. The map is 32 bytes that the caller owns, in a `buf` or a `local`: the address of a table, the number of places in it, the number of keys, and the number of places that hold a key or held one. All zero is an empty map, so a `buf` is one as it stands. The functions take the address of those 32 bytes. Every key and every value can be used, 0 too.

| Function | Does |
|---|---|
| `mapput m k v` | makes `v` the value of the key `k`, in place of the one it had; returns 1 |
| `mapget m k` | returns the value of the key `k` and 1, or 0 and 0 if it has none |
| `mapdel m k` | takes the key `k` out; returns 1, or 0 if it was not there |
| `mapfree m` | gives the table back to the kernel; the map is empty and may be used again |

```
use "lib/std/io.aiw"
use "lib/std/map.aiw"
buf m 32
call mapput m 1000003 30
call mapput m 7 12
call mapget m 1000003 as a ok
call mapget m 7 as b ok
call mapdel m 7
call putn a+b
```

- **Table**: a power of two of places, at least 64, each 24 bytes: 0 for a free place, 1 for a key and 2 for a key that was taken out, then the key and the value. A key belongs at the place its hash names (the last step of splitmix64, cut to the table) and stands at the first place from there on, round the end, that held no key when it came; it is looked for up to the first free place. `mapdel` leaves a mark, so that the keys behind are still found, and a new key takes the first marked place on its way.
- **Growth**: when three quarters of the places hold or held a key, `mapput` of a new key moves all keys to a new table: twice the places if the keys fill half of them, as many otherwise, which only clears the marks. The map is changed when the new table is whole, and the old one is then given back; no address into a table is good after a `mapput`.
- **Errors**: `mapput` returns 0 when the kernel has no memory for a new table, and the map is then as it was, every key with its value. The second result of `mapget` says whether the key was there, since a value may be 0.
- **Ownership**: the caller owns the 32 bytes and ends the map with `mapfree`; the number of keys is read at 16 of them.
- **Names**: the library owns every name that starts with `map`; a program has no `var` of such a name.

## The num library

`lib/std/num.aiw` reads numbers from decimal text. There are no float literals and no other way from text to a double; this is it.

| Function | Does |
|---|---|
| `numint p n` | the whole number in the `n` bytes at `p`, with an optional `-` before it, as a signed 64-bit value and 1; 0 and 0 for text that is no such number or one that does not fit |
| `numdouble p n` | the double nearest to the number in the `n` bytes at `p` and 1; 0 and 0 for text that is no number |

```
use "lib/std/io.aiw"
use "lib/std/num.aiw"
call numdouble "0.1" as x ok       # 0x3fb999999999999a
call numdouble "2.5e3" as y ok
fadd x y as z
ftoi z as n
call putn n                        # 2500
```

- **What `numdouble` takes**: an optional `+` or `-`, digits with at most one `.` among them, of which at least one is a digit, and an optional exponent of ten, `e` or `E` with an optional sign and at least one digit. This is every number of JSON and what C and most programs print, and a little more (`.5`, `5.`, `+7`). No blank, no `inf` or `nan`, no hexadecimal form; nothing may stand before or after the number, so a caller cuts the text first.
- **Rounding**: the result is the binary64 nearest to the exact value of the text, however many digits it has, and of two that are as near the one whose last bit is 0, as `strtod` of C gives it under round to nearest. So a double that was printed with 17 digits, or with the shortest digits that name it, is read back as the same bits.
- **Too large, too small**: a value above every double is an infinity and one below half of the smallest a zero, each with the sign of the text, and the second result is 1: these are values, not errors. `-0` is the zero with the sign.
- **How**: a number of at most 15 digits with a power of ten up to 22 is one multiplication or division of exact doubles. Any other is computed roughly in doubles and then compared, as whole numbers of any length, with the middle between that double and its neighbour, and moved until none is nearer. The whole numbers, limbs of 32 bits, are in the frame of the function (about 5 KiB); nothing is allocated and nothing is kept between calls, so tasks may call it at once. Up to 768 digits are kept; more are counted as one digit that is not 0, which rounds the same.
- **A binary32** is `f8to4` of the result, which rounds a second time. A text that names the double a binary32 widens to, as a program prints one from that double, gives that binary32.
- **Names**: the library owns every name that starts with `num`; a program has no `var` of such a name.

## The JSON library

`lib/std/json.aiw` (use `lib/std/bytes.aiw` first) reads JSON in the bytes it is written in and writes it to a bytes buffer. Reading makes no tree and allocates nothing: a value is an address, a length and a kind, and what a walk returns is again a value in the same bytes.

| Kind | Is |
|---:|---|
| 1, 2, 3 | `null`, `false`, `true` |
| 4 | a number, read with `numint` or `numdouble` of `lib/std/num.aiw` |
| 5 | a string, with its quotes |
| 6, 7 | an array, an object |
| 0 | no value |

| Function | Does |
|---|---|
| `jsonvalue p n` | checks that the `n` bytes at `p` are one value of JSON with nothing but blanks around it: its address, its length and its kind, or three zeros |
| `jsonelem q e` | the next element of an array: its address, length and kind, and the place to ask for the one after it; `q` is that place, the address after the `[` for the first, and `e` the address after the array. After the last, the kind is 0 |
| `jsonmember q e` | the next member of an object, the same way, from the address after the `{`: the address and length of its name (a string), the address, length and kind of its value, and the next place |
| `jsonget p n q m` | the value of the member of the object at `p n` whose name says the `m` bytes at `q`: address, length, kind, or three zeros |
| `jsoneq p n q m` | 1 if the string at `p n` says the `m` bytes at `q` |
| `jsonstr b p n` | adds what the string at `p n` says to the bytes buffer `b`, as UTF-8: 1, or 0 without memory |
| `jsonadds b p n` | adds the `n` bytes at `p` to `b` as a string, in quotes and with the escapes it needs: 1, or 0 without memory |
| `jsonaddi b v` | adds the signed whole number `v` in decimal |

```
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
use "lib/std/num.aiw"
use "lib/std/json.aiw"
call jsonvalue "{\"name\":\"search\",\"k\":[3,5]}" as a n kind    # kind 7
call jsonget a n "k" as v vn vk                                  # [3,5], kind 6
q=v+1
sum=0
label next
call jsonelem q v+vn as e en ek q
if ek
	call numint e en as x ok
	sum+=x
	jmp next
end
call putn sum                                                    # 8
```

- **Nothing is allocated** by the functions that read, `jsoneq` and `jsonget` with a name that is written with escapes included; `jsonstr` alone adds to a buffer of the caller.
- **Checked once**: `jsonvalue` checks everything inside the value, so the walks do not fail on a value it accepted, and a value they return needs no second check. Given other bytes they return the kind 0.
- **What is JSON here**: RFC 8259, and stricter in two things, as I-JSON (RFC 7493): a string is well-formed UTF-8, and an escape from `\uD800` to `\uDFFF` is half of a pair that must be whole, so every string can be written as UTF-8. A byte below 0x20 in a string, a number that starts with `0` and goes on, `+1`, `.5`, `NaN`, a comma before a `]` and a byte order mark are no JSON. Blanks are the space, the tab, the line feed and the carriage return.
- **Depth**: arrays and objects may be nested 128 deep; a value nested deeper is no value. `jsonvalue` calls itself once a level, about 100 bytes of stack each.
- **Names**: two members of one name are allowed, and `jsonget` returns the first. A name is compared by what it says, so `"\u0061"` is the name `a`.
- **Numbers**: the bytes of a number are what `numdouble` takes, and `numint` if it has no fraction and no exponent; a number that fits neither a double nor 64 bits is still a value, and the program decides.
- **Writing**: `jsonadds` writes a quote and a backslash with a backslash before them, a line feed, a carriage return and a tab as `\n`, `\r` and `\t`, any other byte below 0x20 as `\u00` and two digits, and every other byte as it is; the string is valid if the bytes are well-formed UTF-8, which it does not check. Braces, commas, `null` and a number the program has as text are added with `byadd`. There is no function that writes a double.
- **Names of the library**: it owns every name that starts with `json`; a program has no `var` of such a name.

## The algo library

The files of `lib/algo/` are algorithms on 64-bit words that the caller keeps: sorts, a binary search, a hash table of a fixed size and two walks over a graph. They allocate nothing and return no error, since nothing can fail in them; the caller gives every array, also the ones to work in. The algorithm programs of `examples/` are callers of them. Each file is used by itself and has its own prefix.

| Function | File | Does |
|---|---|---|
| `sortquick p q` | `sort.aiw` | sorts the words from the address `p` up to `q`, in place |
| `sortmerge a n t` | `sort.aiw` | sorts the `n` words at `a`, with `n` words at `t` to work in; equal words stay in their order |
| `sortheap a n` | `sort.aiw` | sorts the `n` words at `a` in place, as a heap |
| `sortins a n` | `sort.aiw` | sorts the `n` words at `a` in place, by insertion |
| `searchlower a n k` | `search.aiw` | returns the first index of the `n` rising words at `a` whose word is not smaller than `k`, or `n` |
| `hashplace t m k` | `hash.aiw` | returns the address of the place of the key `k` in the table `t`, or of the free place where it goes; `m` is twice the places, less two |
| `hashfill t m q n` | `hash.aiw` | puts the `n` keys at `q` into the table `t` of `m+1` places, each with its index as value |
| `hashfind t m q n r` | `hash.aiw` | writes to `r` the value of each of the `n` keys at `q`, or -1 |
| `graphbfs off nbr n seen r` | `graph.aiw` | writes to `r` the `n` vertices in the order they are reached breadth first |
| `graphdfs off nbr n seen st r` | `graph.aiw` | the same depth first, with the stack `st` |

```
use "lib/std/io.aiw"
use "lib/algo/sort.aiw"
use "lib/algo/search.aiw"
buf a 32
store a 40
store a+8 7
store a+16 19
store a+24 7
call sortheap a 4
call searchlower a 4 19 as i
call putn i
```

- **Order**: words are compared as unsigned numbers and sorted lowest first. A count of 0 or 1 leaves the words as they are.
- **Sorts**: `sortquick` takes the median of the first, the middle and the last word as its pivot and puts the words equal to it between the smaller and the larger ones in one pass; it calls itself for the smaller side only, so the calls are no deeper than the logarithm of the count. `sortmerge` merges runs of 1, 2, 4, ... words from one array into the other, from the bottom up, and what it leaves in the work array is not specified; the two arrays must not overlap. `sortheap` makes the words a heap with the largest first and takes that to the end, again and again. `sortins` moves each word down past the larger ones before it: a time of `n*n`, and of `n` for words nearly in order.
- **Search**: `searchlower` is where the key is, the first of equal words, or where it would go; `n` says that every word is smaller. In words that do not rise it returns some index up to `n`.
- **Table**: a place is 16 bytes, a key and its value, in bytes of the caller that are zero at first: a power of two of places, of which `hashfill` and `hashfind` take the number less one. The key 0 is a free place, so 0 is no key. A key goes to the place its hash names or to the next free one, round the end; a key put in again gets the new value. Nothing is taken out and the table does not grow, so it must have more places than keys: with every place taken, a key that is not there is looked for without end. The [map library](#the-map-library) is the table that grows, takes keys out and has 0 as a key, at 24 bytes a place.
- **Graph**: the neighbours of the vertex `v` are the words of `nbr` from the index in word `v` of `off` up to the index in word `v+1`, so `off` has `n+1` words. `seen` is a byte for each vertex that the caller makes zero; both walks begin again at the lowest vertex not reached, so every vertex is written once and its byte is 1 afterwards. `graphbfs` uses `r` as its queue; the stack of `graphdfs` has room for a word an edge and one more, and the neighbour written last is taken first.
- **Heaps**: `sortheap` is not the [heap library](#the-heap-library), which is a heap that grows in a vector and gives the smallest first; here the heap is the array to be sorted.
- **Names**: `sort.aiw` owns every name that starts with `sort`, `search.aiw` those with `search`, `hash.aiw` those with `hash` and `graph.aiw` those with `graph`.

## The nd library

`lib/nd/array.aiw` is arrays of numbers with a shape, on the model of NumPy. An array is 176 bytes that the caller owns, in a `buf` or a `local`: where its elements are and how they lie, not the elements themselves. All zero is no array, so a `buf` is one as it stands. The functions take the address of those 176 bytes. An element is 8 bytes, a [double](#floating-point) unless the array is said to be of integers, and has one index for each axis, from 0.

| At | Holds |
|---:|---|
| 0 | the address of the element whose indices are all 0 |
| 8 | the kind of the elements: 1 doubles, 2 integers of 64 bits with a sign; 0 is no array |
| 16 | the number of axes, 0 to 8 |
| 24, 32 | the address and the bytes of the storage the elements are in |
| 40 | 1 if the storage is the array's own |
| 48 | the length of each axis, 8 words |
| 112 | the stride of each axis, 8 words: the bytes from an element to the next along that axis, a signed number |

| Function | Does |
|---|---|
| `ndnew d r s` | makes `d` an array of zeros with `r` axes whose lengths are the words at `s`, in storage of its own; returns 1 |
| `ndvec d n`, `ndmat d n m` | the same with one axis of `n` elements, and with `n` rows of `m` |
| `ndwrap d p b r s` | makes `d` an array of the `b` bytes at `p`, which stay the caller's; returns 1 |
| `ndfree d` | gives the storage back if it is the array's; `d` is no array then and may be used again |
| `ndsize d` | returns the number of elements, 0 for what is no array |
| `ndat d x` | returns the address of the element whose indices are the words at `x`, and 1, or 0 and 0 if there is none |
| `ndget d x` | returns that element and 1, or 0 and 0 |
| `ndset d x v` | makes `v` that element; returns 1, or 0 if there is none |
| `ndslice d s a lo hi st` | makes `d` a view of `s` with, on the axis `a`, the indices from `lo` up to but not `hi`: every `st`-th from `lo` on, or with a negative `st` from `hi-1` on downwards; returns 1 |
| `ndtrans d s` | makes `d` a view of `s` with the axes in the reverse order; returns 1 |
| `ndswap d s a b` | makes `d` a view of `s` with the axes `a` and `b` exchanged; returns 1 |
| `ndreshape d s r sh` | makes `d` a view of `s` with `r` axes whose lengths are the words at `sh`; returns 1 |
| `ndcontig d` | returns 1 if the elements lie one behind the other, the last index fastest |
| `ndcopy d s` | makes `d` an array with storage of its own and the elements of `s`, one behind the other; returns 1 |
| `ndfill d v` | makes every element of `d` the value `v` |
| `ndkind d k` | reads the elements of `d` as the kind `k` from now on, 1 doubles and 2 integers, with their bits as they are; returns 1, or 0 for what is no array and for another `k` |
| `ndvalid d` | returns 1 if `d` is an array whose elements all lie in its storage, for 176 bytes a program wrote itself |

```
use "lib/std/io.aiw"
use "lib/nd/array.aiw"
buf a 176
buf x 16
call ndmat a 3 4
store x 2
store x+8 1
itof 42 as v
call ndset a x v
call ndget a x as w ok
ftoi w as n
call putn n
```

- **Storage**: the element with the indices `i`, `j`, ... is at the address at 0 plus `i` times the first stride plus `j` times the second, and so on. `ndnew` and `ndwrap` lay the elements one behind the other with the last index running fastest (the last stride is 8, each one before it the next times the length of the next axis), so the elements of such an array are also the words at the address at 0, as many as `ndsize` says. An array without axes is one element. An axis of length 0 gives an array without elements.
- **Views**: `ndslice`, `ndtrans`, `ndswap` and `ndreshape` write 176 bytes and move no element: the view has the storage of `s`, so a store through one is seen through the other, and it never owns that storage. A slice with the step -1 is the axis backwards, with a negative stride; `ndslice v a 0 1 3 1` are the rows 1 and 2 of `a`. `ndreshape` needs elements that lie one behind the other (`ndcontig`) and as many of them as the new lengths give; a view that does not lie so, a transposed one or one with a step, is copied first. `d` and `s` may be the same 176 bytes, which then keep the storage if they owned it; an array that `ndscalar` made has its element in those bytes, where the lengths go, and is refused there, while another `d` takes it. `ndcopy` is the one that moves elements: it takes storage for them, and with `d` and `s` the same it frees what `s` owned.
- **Errors**: `ndnew` and `ndwrap` return 0 for more than 8 axes, for an axis or a number of elements of 2^60 or more, `ndnew` when the kernel has no memory and `ndwrap` when the bytes are too few for the elements; the 176 bytes are then as they were, an array that was there with every element. `ndat`, `ndget` and `ndset` test each index against the length of its axis, and the second result says whether there was an element, since an element may be 0. The functions that make a view return 0 for an axis the array has not got, for `lo` above `hi` or `hi` above the length, a step of 0, lengths that give another number of elements, and for what is no array, `ndcopy` without memory; `d` is then as it was. Bytes that are no array and not all zero are a fault of the program.
- **Ownership**: the caller owns the 176 bytes and ends the array with `ndfree`; an array in a `local` is zeroed before its first use and freed before its function returns. `ndnew` asks nothing of what the 176 bytes held, so an array with storage of its own is freed before another is made in its place. A view is good as long as the storage it was made of: the array that owns it is freed last, and `ndfree` of a view frees nothing. The storage of `ndnew` is one `alloc`, freed by `ndfree`; the bytes given to `ndwrap` are never freed by the library and must be there as long as the array is used.
- **Names**: the library owns every name that starts with `nd`; a program has no `var` of such a name.

`lib/nd/elem.aiw`, used after `lib/nd/array.aiw`, is the arithmetic on elements. Every function takes the result first, an array the caller made, and computes as many elements as that has.

| Function | Does |
|---|---|
| `ndadd o a b`, `ndsub o a b`, `ndmul o a b`, `nddiv o a b` | makes each element of `o` the sum, difference, product, quotient of the elements of `a` and `b` at its indices; returns 1 |
| `ndput o a` | makes each element of `o` the element of `a` at its indices; returns 1 |
| `ndscalar d x` | makes `d` an array without axes whose one element is `x`, kept in the 176 bytes |
| `ndtoi o a` | makes each element of `o`, an array of integers, the double of `a` at its indices cut off towards 0; returns 1 |
| `ndtof o a` | makes each element of `o`, an array of doubles, the integer of `a` at its indices as a double; returns 1 |

```
use "lib/std/io.aiw"
use "lib/nd/array.aiw"
use "lib/nd/elem.aiw"
buf a 176
buf k 176
buf x 16
call ndmat a 2 3
itof 3 as v
call ndfill a v
itof 2 as v
call ndscalar k v
call ndmul a a k
call ndget a x as w ok
ftoi w as n
call putn n
```

- **Lengths**: `a` and `b` need not have the lengths of `o`. The axes of an array with fewer are matched with the last axes of `o`, and an axis of length 1 gives its one element to every index of that axis of `o`: three elements go with every row of a table of rows of three, a column of length 1 with every column, an array without axes with everything. This is the broadcasting of NumPy, but that the result is given and never made: an axis of `a` or `b` that is neither 1 nor the length in `o`, or more axes than `o` has, is refused.
- **Storage**: nothing is allocated, so one array serves as the result of one operation after another. `o` may be `a` or `b` or both, or a view of the same elements under the same indices (`ndadd a a b` adds `b` to `a`). Any other storage that `o` shares with `a` or `b` is refused: the lowest and highest address of each are compared, so this also refuses two views whose elements alternate. A result with a stride of 0 on an axis longer than 1 is refused, its elements being one.
- **Speed**: a call on arrays of doubles with one axis, apart from the result, costs about 20 ns before its loop, and any other call about 60. Arrays that are all taken backwards (a slice with the step -1 of each, or one element) are computed as fast as forwards. Arrays whose elements lie one behind the other, each with as many as `o` or with one, are one loop over the words, in which an array of one element is a number read once and doubles are computed [two at a time](#two-doubles-at-once), with the same bits as one at a time; everything else is a loop along the last axis for each combination of the other indices, at the cost of a call for each.
- **Integers**: an array is one of doubles when it is made, and of integers after `ndkind d 2`, which is for a new array, all zero in both kinds, or for bits the program wrote as integers. The three arrays of an operation are of one kind, or it is refused; `ndtoi` and `ndtof` are the two that go from one kind to the other, as [`ftoi` and `itof`](#floating-point) do for one value, so a double that is no number or too large becomes the lowest integer. Integers wrap at 64 bits in sums, differences and products, as everywhere in the language. Their quotient has a sign and is cut off towards 0 (-7 by 2 is -3, where NumPy's `//` gives -4); a divisor with a 0 among its elements is refused before anything is written, where a program's own `sdiv` would end it with `SIGFPE`, and the lowest integer by -1, which does not fit, stays the lowest integer. A view has the kind of its array when it is made.
- **Errors**: 0 for lengths that do not go together, storage shared as above, arrays of two kinds, an integer divisor of 0, and what is no array; no element was written then. An array without elements as the result is no error and writes nothing. The elements are doubles and a division by zero is an infinity, or no number for 0 by 0, as [`fdiv`](#floating-point) gives.

`lib/nd/reduce.aiw`, used after the two, makes one number of many.

| Function | Does |
|---|---|
| `ndsum d` | returns the sum of all elements and 1, or 0 and 0 for what is no array |
| `ndmean d` | returns their mean and 1, or 0 and 0 |
| `ndsumpw d` | returns the sum, added in pairs, and 1, or 0 and 0 |
| `ndsumax o d a` | makes each element of `o` the sum of the elements of `d` along its axis `a`; returns 1 |
| `ndmeanax o d a` | makes each element of `o` their mean; returns 1 |
| `nddot a b` | returns the sum of the products of the elements of `a` and `b`, two arrays of one axis and the same length, and 1, or 0 and 0 |
| `ndmatmul o a b` | makes `o` the product of the matrices `a` and `b`; returns 1 |
| `ndmatmulp o a b t` | the same in `t` tasks, of `lib/nd/par.aiw`; returns 1 |
| `ndruns n t` | how `ndmatmulp` cuts `n` rows for `t` tasks: the rows of a run and the number of runs, the row blocks |

```
use "lib/std/io.aiw"
use "lib/nd/array.aiw"
use "lib/nd/elem.aiw"
use "lib/nd/reduce.aiw"
buf a 176
buf c 176
call ndmat a 3 4
itof 2 as v
call ndfill a v
call ndvec c 4
call ndsumax c a 0
call ndsum c as w ok
ftoi w as n
call putn n
```

- **Along an axis**: the result is an array of the caller with the lengths of `d` without the axis `a`: for a table, `ndsumax c t 0` gives the sums of the columns in a `c` as long as a row, and `ndsumax r t 1` those of the rows. An array of one axis gives a result without axes ([`ndscalar`](#the-nd-library) makes one). Each of those lengths must be the one of `d`: a result with an axis of length 1 where `d` has more is refused, not given every element as in `ndadd`. The result may be a view, and may not share storage with `d`.
- **Order**: a sum starts from 0 and adds one element after the other in the order of the indices, the last fastest, and along an axis from the index 0 up, as a loop in C does. NumPy adds in pairs, so the last digits of a long sum can differ from its: a million times 0.1 is 100000.0000013 added so and 100000 in pairs, which `ndsumpw` does, halves of halves down to runs of 128 elements at most. Within such a run `ndsumpw` promises no order: doubles that lie one behind the other are added two at a time into sixteen sums, which are then added in halves. A mean is the sum divided by the number of elements.
- **No element**: the sum of no element is 0 and the mean is 0 divided by 0, no number, also for each element of a result along an axis of length 0.
- **Special values**: what is no number stays so through a sum, an infinity stays one, and infinities of both signs together are no number, as `fadd` has it; a sum along an axis keeps that to the elements it concerns.
- **Products**: `ndmatmul` takes three arrays of two axes: `n` rows of `m` elements times `m` rows of `l` give a result of `n` rows of `l`, each element the sum over `k` of the element `i`, `k` of `a` times the element `k`, `j` of `b`, added from 0 in the order of `k`, as `nddot` adds in the order of the index. A column or a row is a matrix with one of them (`ndreshape`, or a slice of one index). Any of the three may be a view; the result may not share storage with `a` or `b`, so a matrix is not multiplied in place, and each of its elements must be at an address of its own: strides of 0, strides that are no multiple of 8, by which elements would share some of their bytes, or strides by which some steps along one axis are some along the other (8 and 8, or 24 and 16 for three rows of four), are refused, since the elements are summed where they lie and, in tasks, by several threads. A product without elements writes nothing and is done at once, whatever the number of its rows, and one over no `k` (`m` is 0) is zeros. Other lengths, another number of axes and such a result are refused with 0 and nothing written; `nddot` returns 0 and 0 for lengths that differ and for arrays that have not one axis.
- **Speed**: `ndsum`, `ndmean` and `nddot` add doubles with [`fsum` and `fdot`](#a-sum-in-its-order), in the order they promise and in the time of a loop in C; `ndsumpw` does so for doubles that do not lie one behind the other, and takes two thirds of the time of `ndsum` for those that do ([measurements](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#the-sum-in-pairs-two-doubles-at-a-time-2026-11-21)). The sums along an axis and the product of matrices compute doubles that lie one behind the other [two at a time](#two-doubles-at-once), since each element of their result is computed alone; the bits are those of one at a time. `ndsum`, `ndmean` and `nddot` add every element to the one sum before it and go one at a time.
- **Integers**: `ndsum`, `ndsumpw`, `ndsumax`, `nddot` and `ndmatmul` of integers compute in integers, wrapping at 64 bits, and their result is of integers; arrays of two kinds are refused. A mean is always a double: of integers it is the sum of the elements as doubles divided by their number, and the result of `ndmeanax` is an array of doubles whatever `d` is of.
- **Tasks**: `lib/nd/par.aiw`, used after `lib/std/task.aiw` and the three files, has `ndmatmulp o a b t`, the product of matrices in `t` [tasks](#tasks): the rows of the result are cut into runs and each task computes its own, which no other touches, so the result is the bits of `ndmatmul` and what is refused is the same. A run is the rows divided by `t`, rounded up, and the last run what is left, so fewer tasks than `t` are made where the rows do not go round: 16 rows for 14 tasks are 8 runs of 2. `ndruns n t` gives the rows of a run and the number of runs, the row blocks, which is what `ndmatmulp` uses; it is the plan and no count of tasks, since one block alone is computed by the caller and so is a block whose `spawn` fails. At most 64 tasks are made and no more than there are rows; with 0 or 1 the rows are computed by the caller. The threads are those of the pool (`call workers n`), and the calling thread computes too while it waits; the three arrays must be there until the function returns, when every task has ended. On 20 processors a product of side 1000 takes 43 ms in 20 tasks against 238 ms in one, and one of side 30 gains nothing from more than four ([measurements](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#numerical-arrays-2026-11-21)). A program that has run tasks ends with `sys exit_group` or at its last line, since `sys exit` ends only its own thread. With the pool started, tasks pay from some ten microseconds of work, a few of them; a first call, which starts the threads, from some hundred; as many tasks as threads is the number to start from ([measurements](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#array-kernels-after-the-first-round-2026-11-21)).
- **Errors**: `ndsumax` and `ndmeanax` return 0 for an axis `d` has not got, a result with other lengths, storage shared with `d`, and what is no array, and write nothing then.

## The async library

`lib/async/task.aiw` runs tasks that give the thread back when they have to wait: one thread polls them, one at a time, and a task that waits costs its record and nothing else. It is the runtime of [async functions](#async-functions), which the compiler turns into the poll functions that this section writes by hand; a program gets it with `use "lib/async/task.aiw"`. It has no line that runs at its use, so a program that never makes a task runs no code of it.

| Function | Does |
|---|---|
| `async z p` | makes a task of `z` bytes, its record of 64 included, that the function `p` polls, and puts it in the queue; with `p` 0 an event, which nothing polls. Returns the handle, 0 without memory |
| `await h s` | two results: the result of the task `h` and 1, or 0 and 0 if `h` is not done, after which the task `s` is woken when it is. With `s` 0, for code that is no task, it polls tasks until `h` is done |
| `asyncwake h` | puts the task in the queue, to be polled again |
| `asyncfinish h v` | ends the task or event `h` with the result `v` and wakes the task that awaits it; returns 1, or 0 if it was done already |
| `asyncdetach h` | says that nobody will await `h`: its record is released when it is done |
| `asynccancel h` | cancels the event or task `h`; returns 1, or 0 if it was done |
| `asyncstop` | cancels everything, polls until nothing can happen and gives back what the library holds; returns the number of tasks not done |
| `asyncrun` | polls tasks until nothing can happen any more; returns the number of tasks that are not done |
| `asyncstep` | polls one task; returns 1, or 0 if nothing can happen |
| `asyncyield` | makes a task that is done at its first poll, with the result 0; a task that awaits it lets the tasks in the queue run first |

```
use "lib/async/task.aiw"
fn poll t
load t+64 as e          # the first value: an event to wait for
call await e t as v r
ifz r
ret 0                   # not yet: polled again when e is done
end
store t+16 v+1          # the result
ret 1
end
call async 64 0 as e    # an event
ref poll as p
call async 72 p as h    # a task with one value
store h+64 e
call asyncfinish e 41
call await h 0 as x     # 42
```

- **A task** is a record and its handle the address of it: the poll function at 0, a cell at 8 that belongs to the poll function (where it goes on), the result at 16, the state at 24, cells of the library up to 64, and from 64 the values of the task, as many as the size given to `async` has room for. The values are not zero: the code that makes the task stores them, which it can do before anything is polled, since `async` polls nothing.
- **The poll function** is called with the handle. It returns 0 when the task has to wait, having arranged for a wake (an `await`, or an `asyncwake` by whoever knows), and 1 when the task is done, having stored its result at 16. It is called again from its first line every time; what must survive is in the values of the task.
- **Wakes**: a task that is woken is polled once, however often it was woken before the poll; a wake of a task that is done, or of an event, does nothing. A task woken while it is being polled is polled again afterwards, so nothing that happens during a poll is lost, and a task that wakes itself and returns 0 lets the others run.
- **`await`** gives the result once, to one asker, and releases the task; its handle means nothing afterwards. A task that is neither awaited nor detached keeps its record; after `asyncdetach` the handle means nothing either. One task awaits a task at a time. `await` of 0 gives 0 and 1.
- **Outside a task** (`s` 0) `await` runs the queue until `h` is done. If nothing can happen any more before that, the result is -35 and 1, and `h` stays as it was; the same if it is called so from inside a poll, where it would poll tasks within a task.
- **Errors**: a task has no failure of its own; what it reports, it reports in its result, by convention a negative number as the kernel's are.
- **Order**: tasks are polled in the order in which they were made or woken. Nothing runs at the same time as anything else, so tasks share memory without `xadd` and `cas`; the functions of this library are for one thread, the one that polls.
- **The costs**: a record is the next power of two from 128 bytes that holds the task. Records up to 4096 bytes are cut from blocks of 64 KiB that are never given back, and all up to 16384 bytes are used again by the next task of their size; larger ones are an `alloc` and a `free` each.
- **Cancelling**: `asynccancel h` returns 1, or 0 if `h` was done. Its handle is still awaited or detached, as before.
  - An **event** ends at once with the result -125 (`ECANCELED`), taken from where it waited: the timer is no longer due, the read no longer waits. The one exception is [work that a thread is doing](#work-that-holds-a-thread), whose event ends when the work has returned.
  - A **task** is not ended; it is told. At the `await` it waits in, or the next one that would wait, what it awaits is cancelled in its turn, and when that has ended the `await` gives the task -125 in the place of a result. For an event that is at once. A task that it awaits is told the same way and takes the time it takes to return, and [work that a thread is doing](#work-that-holds-a-thread) the time it takes to finish; the cancelled task stays where it is until then, since they may be using memory it gave them. Cancelling thus goes down a chain of tasks to what the last one waits for, and comes back up as each returns. An `await` of something that is done already gives its result as always, to a cancelled task too: it may be a descriptor that only this task can close. That is its chance to give back what it holds, close its descriptors and return a result, which whoever awaits it gets. A task that was told and reaches another `await` that would wait is ended there with the result -125, once what it asked for has been cancelled and has ended: the lines behind that `await` never run. So a task that ignores results is still stopped, and a task that awaits nothing more runs to its `ret`.
  - Only what a task waits for is cancelled with it. Work it started and has not awaited goes on.
- **Stopping**: `asyncstop` cancels every event that waits for time, for a descriptor or for work of the pool; from then on tells every task at its `await`, as if it were cancelled; polls until nothing can happen; and gives back the `epoll` object, the table of the descriptors and the `eventfd`. The descriptors of the program stay open, and are the program's to close. It returns the number of tasks that are not done even so, which wait for an event that only the program ends. Afterwards the library is as it was before its first use. It is called by code that is no task.
- **Names**: the library owns `async`, `await` and every name that starts with `async`, in all its files; a program has no `var` of such a name.

### Timers

`lib/async/time.aiw`, used after `lib/async/task.aiw`, makes events of time.

| Function | Does |
|---|---|
| `asyncsleep ms` | an event that is done, with the result 0, when `ms` milliseconds have passed |
| `asynctimeout h ms` | a task to await in the place of `h`: its result is that of `h` if `h` is done within `ms` milliseconds, else -62 (`ETIME`), after `h` was cancelled |
| `asyncclock` | the clock that only goes forward (`CLOCK_MONOTONIC`), in nanoseconds |

```
call asyncread fd b 512 as h
call asynctimeout h 2000 as g
call await g 0 as n     # the bytes read, or -62 after two seconds
```

- When no task can be polled, the thread sleeps until the earliest timer is due; with no timer and nothing else to wait for, nothing can happen and `asyncrun` returns. A timer is never early; it is late by what the tasks polled before it take.
- Tasks that always have something to do do not keep timers and files from being seen: every 61st poll looks at both without sleeping.
- A time too long for the clock to count, 292 years or more, is the longest there is: such a timer is never due, and ends only by `asynccancel`.
- `asynctimeout` of 0, the handle of a task that could not be made, is 0, and no timer.
- After `asynctimeout` the handle `h` belongs to the limit: it is not awaited or cancelled any more, and cancelling the limit cancels it. A task that runs out of time is told, like any cancelled task, and the limit has its result -62 when the task has returned: until then the task may be using memory of whoever awaits the limit. Whether the result or the time came first is decided when the limit is polled; if both have come by then, the result counts.
- The timers that run are 16 bytes each in a heap, besides their events.

### Files and sockets

`lib/async/io.aiw`, used after the other two, makes events of the work of the kernel on a descriptor.

| Function | Does |
|---|---|
| `asyncread fd p n` | an event whose result is that of `read`: the number of bytes now at `p`, at most `n`, 0 at the end; or a negative error number |
| `asyncwrite fd p n` | the same for `write`: how many of the `n` bytes were taken, which may be fewer |
| `asyncwriteall fd p n` | an event that is done when all `n` bytes are written, with the result `n`, or after an error, with the error |
| `asyncaccept fd` | an event whose result is the descriptor of the next connection to the listening socket `fd` |
| `asyncconnect ip port` | an event whose result is a socket connected to that port of the IPv4 address `ip`, a number (`0x7f000001` is 127.0.0.1), or the error, after which there is no socket |
| `asynclisten ip port` | a socket that listens there (`ip` 0: on every address; `port` 0: on a port the kernel chooses), with `SO_REUSEADDR`; the descriptor or a negative error number, at once |
| `asyncport fd` | the port of a socket |
| `asyncclose fd` | closes the descriptor, after ending the events that wait for it with the result -125; returns what `close` returns |

```
use "lib/async/task.aiw"
use "lib/async/time.aiw"
use "lib/async/io.aiw"
buf b 512
call asynclisten 0 8080 as l
call asyncaccept l as h
call await h 0 as c         # a connection
call asyncread c b 512 as h
call await h 0 as n
call asyncwriteall c b n as h
call await h 0
call asyncclose c
```

- **An operation asks the kernel first** and is done at once if the kernel does the work at once. Only when the kernel says "not now" (`EAGAIN`) does the event wait, and the kernel is asked again when `epoll` reports the descriptor ready. So a read gives what is there, which may be less than `n`, and `asyncwrite` what the kernel had room for; a loop, or `asyncwriteall`, sends the rest.
- **Order**: events that wait to read from (or accept on) a descriptor are served in the order they were made, and the same for those that write; a new one waits behind them.
- **A descriptor the library is given** is made non-blocking (`O_NONBLOCK`, which every holder of the open file sees) and registered with `epoll` once, for both directions and changes only (`EPOLLET`). A plain file is not something `epoll` watches: its operations are done at once. Close such a descriptor with `asyncclose`, which takes it out of `epoll` and forgets it; a number that the kernel gives out again is then a new file, also when it is a copy (`dup`) of the one closed.
- **Cancelling** an event that waits (`asynccancel`, or the limit of `asynctimeout`) takes it out of its list; bytes that come later are there for the next read. A connect that is cancelled closes its socket. The bytes of a read or write must stay valid until the event is done or cancelled.
- **Errors** are the kernel's, negated: -104 for a connection that was reset, -111 for a port where nobody listens, -9 for a descriptor that is none, -32 (`EPIPE`) for a write where nobody reads any more.
- **No `SIGPIPE`**: the kernel sends that signal to a process that writes to a socket or a pipe whose other end is closed, and it ends a program that has not arranged otherwise. A write of this library gives the result -32 instead: a socket is written with `sendto` and `MSG_NOSIGNAL`; for a pipe the signal is blocked for the thread around the write and taken back if the write made it. What the program does with the signal elsewhere is not changed.
- **The costs**: an event is a record of 128 bytes, used again; a descriptor is another, and 8 bytes in a table that is as long as the highest descriptor seen. An operation that the kernel does at once is one system call; one that waits is two, and its share of an `epoll_wait` that reports up to 64 descriptors.

### Work that holds a thread

One thread polls every task, so a task that computes for a second, or makes a system call that waits, keeps all the others waiting for that long. `lib/async/pool.aiw` gives such work to the threads of [`spawn` and `join`](#tasks); a program uses `lib/std/task.aiw` and the three files above before it.

| Function | Does |
|---|---|
| `asyncblock p a b c d` | an event that is done when a worker of the pool has called the function at the address `p` with the four values; its result is the first result of the function |

```
fn hash p n c d
...
end
async fn serve c
...
ref hash as f
await asyncblock f b n 0 0 as x     # other tasks run meanwhile
...
end
```

- The function runs on another thread, at the same time as the tasks: what it shares with them it touches only through [`xadd` and `cas`](#atomic-operations), and it calls no function of the async library. Memory it is passed stays valid until the event is done.
- `spawn`, `join` and `workers` are what they were, and a program may use both: the pool is one, and its limit holds for both kinds of work. With no worker at all, because the limit is 0 or the kernel refused the first thread, `asyncblock` runs the work itself before it returns, on the polling thread: the program is slower then, and still right. A `join` in a task holds the polling thread until its task is done; `asyncblock` is the form that does not.
- A worker that has finished puts its work in a list and, only if the polling thread sleeps, writes to an `eventfd` that ends the sleep. The polling thread takes the list when it next looks at the outside world.
- **Cancelling** the event (`asynccancel`, a limit of `asynctimeout`, a cancelled task that awaits it, `asyncstop`): work that no worker has begun is not run, and the event ends at once with -125. Work that a worker is doing cannot be stopped, and it may be using memory of the task that waits for it, a `local` for one. So its event does not end then: it ends with -125 when the function has returned, and until then the task that awaits it stays where it is, a limit on it does not give its -62, and `asyncstop` does not return. The rule above holds without exception: memory passed to the work is needed until the event is done, and no longer.
- **The costs**: two records of 128 bytes and one task of the pool; in the kernel, what `spawn` costs, and a write and a wake when the polling thread sleeps.

### Channels and the first of several

`lib/async/chan.aiw`, used after `lib/async/task.aiw`, carries values between tasks and waits for several things at once.

| Function | Does |
|---|---|
| `asyncchan n` | a channel that holds up to `n` values, at least one; 0 without memory |
| `asyncsend c v` | an event that is done, with the result 0, when the channel has taken the value `v`: at once if there is room or a receive waits, else when there is room |
| `asyncrecv c` | an event whose result is the oldest value of the channel: at once if it holds one, else when one is sent |
| `asyncshut c` | no more values: sends and waiting receives end with -32 (`EPIPE`); what the channel holds is still received |
| `asyncchanfree c` | shuts the channel and releases it |
| `asyncfirst a b` | a task that is done when the first of the two handles is: its result is 0 for `a`, 1 for `b` |
| `asyncany p n` | the same for the `n` handles at `p`, 8 bytes each: the index of the first that is done |

```
async fn produce c
i=0
while i<100
await asyncsend c i      # waits while the channel is full
i+=1
end
call asyncshut c
end
async fn consume c
while 1
await asyncrecv c as v
if v==-32
ret 0
end
...
end
end
call asyncchan 8 as c
call produce c as p
await consume c
await p
call asyncchanfree c
```

- **A channel is bounded**: a task that sends faster than another receives waits, which is what keeps a fast producer from filling memory. Values are received in the order of their sends, and sends and receives that wait are served in the order they were made.
- A channel carries any 64-bit value. -32 is also what a shut channel gives, so a program whose values may be that number tells the end another way.
- A send or receive that waits is cancelled like any event, by `asynccancel`, a limit or `asyncstop`; a value is never lost by that: it stays with the sender or in the channel.
- **The first of several** does not take a result. It says which handle is done; the program awaits that one, which gives the result at once, and keeps the others, to await later or to cancel:

```
call asyncrecv c as r
call asyncsleep 1000 as s
await asyncfirst r s as i
if i
call asynccancel r       # a second without a value
end
await r as v             # the value, or -125
call asynccancel s
await s
```

- While the first of several is awaited no other task awaits one of its handles. A handle of 0 counts as done. If several are done, the lowest index is the result. Cancelling it leaves the handles as they are.
- **The costs**: a channel is 72 bytes and 8 for each value it can hold; a send or receive is an event of 128 bytes, also when it is done at once.

## The HTTP library

`lib/net/http.aiw` is HTTP/1.1 over the sockets of the async library: what a message is made of, and a client. A program uses `lib/std/bytes.aiw` and the three files of the async library ([tasks](#the-async-library), timers, files and sockets) before it; it brings `lib/async/chan.aiw` itself. [The server](#the-http-server) is a file of its own.

| Function | Does |
|---|---|
| `httpcall q b` | an async function: sends the request of the 128 bytes at `q` and reads the response into the bytes buffer `b`; its result is the status, or a negative error |
| `httpfield p n q m` | the value of the header line of the name `q m` in the head `p n`, whatever the case of the name and without the blanks around it: address and length, or 0 and 0 |
| `httphead p n` | the length of the head at the start of the bytes, with the empty line that ends it; 0 if that line is not there |
| `httpstatus p n` | the status of the response with this head, or 0 |
| `httpurl p n` | reads `http://` an IPv4 address or `localhost`, a port or not, a path or not: the address as a number, the port (80), the address and length of the path, and 1; or zeros and 0 |
| `httpip p n` | reads an IPv4 address written with dots, or `localhost`: the number and 1, or 0 and 0 |
| `httpbody fd b ms max eof`, `httpmore fd b ms` | async functions that read the body after a head, and more bytes, into a bytes buffer; the server uses them too |
| `httplimit h ms` | the handle to await in the place of `h` for it to take `ms` milliseconds at most; 0 if `h` is 0, which a caller looks at before it awaits |
| `httpframe p n` | what the head says of the body, in one walk over its lines: 1 and the number of `Content-Length`, 2 and 0 for `Transfer-Encoding: chunked`, 0 and 0 with neither, or -71 and 0 for a head that is not to be read: a header line without a colon, a name of no bytes or with a blank or a byte that is no visible ASCII character (`Content-Length : 5`), a transfer coding that is not `chunked` alone or stands twice, a length that is no number, two lengths that differ, or a length and a transfer coding |

The request is 128 bytes that the caller owns, all zero to start with:

| At | Is |
|---:|---|
| 0, 8 | the IPv4 address of the server, a number, and the port |
| 16 | the method, address and length; `GET` if the length is 0 |
| 32 | the target, address and length; `/` if the length is 0 |
| 48 | the body, address and length |
| 64 | the content type of the body, address and length; no line is sent if the length is 0 |
| 80 | the name for the line `Host`, address and length; the address and the port if the length is 0 |
| 96 | the milliseconds that the connect, the write and each read may take; 0 for no limit |
| 104 | the most bytes a response may have; 0 for 64 MiB |
| 112 | written by `httpcall`: the length of the head of the response |

```
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
use "lib/async/task.aiw"
use "lib/async/time.aiw"
use "lib/async/io.aiw"
use "lib/net/http.aiw"
buf q 128
buf b 24
call httpurl "http://127.0.0.1:11434/api/tags" as ip port p n ok
store q ip
store q+8 port
store q+32 p
store q+40 n
store q+96 5000
await httpcall q b as status        # 200, or below 0
load b as x
load b+8 as len
load q+112 as h
call print x+h len-h                # the body
```

- **The response**: after a status of 200 to 599 the buffer holds the head, the status line and the header lines with the empty line, and after it the whole body as the server meant it: as many bytes as `Content-Length` says, the chunks of `Transfer-Encoding: chunked` put together, or everything up to the end of the connection. Two lines `Content-Length` that do not say the same number, a `Transfer-Encoding` other than `chunked` alone or on two lines, a `Content-Length` together with a `Transfer-Encoding`, a header line without a colon or with a blank before it (all of which `httpframe` finds in one walk over the head), and a status above 599, are -71: no other rule is taken in their place. A response `1xx` before the real one is passed over. A `HEAD`, a 204 and a 304 have no body.
- **Errors** are a negative result, after which the buffer is not to be read: the error of the kernel for the socket (-111 nobody listens, -104 reset), -62 for a step above the limit, -71 (`EPROTO`) for an answer that is no HTTP or ends before it is whole, -90 (`EMSGSIZE`) for a head above 64 KiB, a response above the limit or a chunk whose size no body may have, -12 without memory. A limit of time that cannot be made cancels the step it was for, whose error is then -125.
- **What it is not**: one connection a request (`Connection: close`), no TLS, no names (the address is a number), no redirects, no compression, no cookies. It is the client of a program that asks a service it knows, on the same machine or network.
- **Cancelling** `httpcall` (`asynccancel`, or a limit of the program around it) ends it with -125 and leaves no connection open: the connect is kept by the task and asked for what it has, also when it was done and not yet taken.
- **Several at once**: `httpcall` is a task, so requests that are started and awaited later run together, each with its own request bytes and buffer.
- **Names**: the library owns every name that starts with `http`; a program has no `var` of such a name.

### The HTTP server

`lib/net/httpd.aiw`, used after `lib/net/http.aiw`, answers requests with an async function of the program.

| Function | Does |
|---|---|
| `httpdserve l f x` | an async function: accepts the connections of the listening socket `l` and, for each, reads one request, calls the handler at the address `f` with `x` and the request, and writes the response; its result is the error that ended the accepting |

The handler is an async function of two values, the `x` of the program and the request, 136 bytes that are good until the handler is done:

| At | Is |
|---:|---|
| 0 | the method, address and length, as it was sent |
| 16 | the target, address and length (`/search?q=1`) |
| 32 | the head of the request, address and length, for `httpfield` |
| 48 | the body, address and length, a body in chunks put together |
| 64 | the status of the response: 200 unless the handler stores another |
| 72 | the content type of the response, address and length: `text/plain` unless the handler stores another, bytes that stay good after it is done |
| 88 | a bytes buffer, empty, to which the handler adds the body of the response |
| 112 | the descriptor of the connection |

```
use "lib/std/bytes.aiw"
use "lib/async/task.aiw"
use "lib/async/time.aiw"
use "lib/async/io.aiw"
use "lib/net/http.aiw"
use "lib/net/httpd.aiw"
async fn handle x q
	load q+16 as p              # the target
	load q+24 as n
	call byadd q+88 "you asked for "
	call byadd q+88 p n
	call byaddb q+88 10
	ret 0
end
call asynclisten 0x7f000001 8080 as l
ref handle as f
await httpdserve l f 0          # until l is closed
```

- **One task a connection**, so a handler that waits, for a file, a timer or a request of its own, keeps no other connection waiting. What it returns is not looked at, but for -125, the result of a task that was cancelled while it waited: the connection is then closed without a response.
- **The server answers itself**, and calls no handler: 400 for what is no request of HTTP/1 or has a head that `httpframe` does not read (a header line without a colon or with a blank before it, two lengths that differ, a transfer coding other than `chunked`, a length and a transfer coding), 417 for an expectation other than `100-continue` (which it answers with `100 Continue` before it reads the body), 431 for a head above 64 KiB, 413 for a body above 16 MiB. A connection that ends, or sends nothing for 30 seconds, gets no answer.
- **The response** has the status line, `Content-Type`, `Content-Length` and `Connection: close`, and the connection is closed after it: one request a connection. The answer to a `HEAD` has the length and not the body; a response of the status 204 or 304 is sent without the body, whatever the handler added, and a 204 without a length.
- **Without memory**: `httpdserve` ends with -12 when an accept or the task of a connection cannot be made, having closed the connection it had accepted; a handler whose task cannot be made is answered with 500. A response is written whole or not at all.
- **Stopping**: `asyncclose l` ends `httpdserve` with -125. Connections that are open then are served to their end by their own tasks; `asyncrun` waits for them.
- **What it is not**: no TLS, no connection that is kept, no routing: the handler looks at the method and the target.
- **Names**: the server owns every name that starts with `httpd`.

## Comments

`#` starts a comment that runs to the end of the line, either on its own line or after a statement. A `#` inside a string is part of the string. A comment may hold any byte except a CR that is not followed by LF, and it may end the source without a line end.

## Errors

The compiler stops at the first fault it finds, prints one line on stderr and exits with a non-zero status:

```
ailc: 12: undefined label done
ailc: lib/std/io.aiw:7: wrong operand count
ailc: source too big
```

After `ailc: ` comes the place: the line number, with the path of the file in front if the line is in a file that a `use` named, as the path was written there. Then the message, and for some messages the name it is about. The lines of each file count from 1. Messages that are not about a place have none.

A fault that can only be known when the whole source has been read is still reported where it was written: an undefined label, function or name at the line that uses it, a wrong count at the call, an invalid access at the load or store. Such faults are found after all the others, so a source with two faults may report the later line first.

Status 1 means the source is at fault; status 2 means the environment is.

| Message | Status | Cause |
|---|---|---|
| `unknown statement` | 1 | a line that does not start with a statement keyword |
| `not allowed here` | 1 | `ret`, `tail` or `local` outside a function; `fn`, `async fn` or `use` inside one; `tail` in an async function; `end` with no block and no function open; `else` without an open block, in a `while`, or a second `else` in one |
| `missing end` | 1 | the source, or a file named by `use`, ends inside a function or a block |
| `missing as` | 1 | a statement that produces a value without `as`: `set`, `len`, the arithmetic statements, the comparisons, the loads, `at`, `alloc`, `ref`, `args` |
| `unexpected as` | 1 | `as` on a store, a jump, an `if` form, `ret`, `tail` or `free` |
| `missing label` | 1 | a jump whose values are not followed by a label name |
| `wrong operand count` | 1 | a statement with more or fewer values than it takes; `ret` without a value or with more than six; `tail` with more than six, where a string counts as two; `ref` with a value; `callp` without the address; an async function with more than six parameters; `await` of a handle with a second value; `spawn` with more than five values; more than seven values after `sys`; an `rt` with another number of values than its service takes |
| `unterminated string` | 1 | a string, or the path of a `use`, with no closing quote |
| `expected a name` | 1 | something else where a name must stand: after `fn`, `label`, `call`, `tail`, `ref`, `buf`, `var`, `const`, `local` or `as`; or the name `as` in one of those places |
| `syntax error` | 1 | anything else that is not a statement of the language; see below |
| `undefined variable` *name* | 1 | a name used as a value that is no variable of its scope at that line and that no `buf` or `data` declares anywhere in the source; a `var` or `const` used before its declaration |
| `unassigned variable` *name* | 1 | a variable read on a way that may not have assigned it. Without a name: a jump back to a label that takes more variables as assigned than the jump has; see [Control flow](#control-flow) |
| `too many variables` | 1 | a 65th variable name at top level or in one function, parameters and locals included |
| `duplicate name` *name* | 1 | `buf`, `data`, `var` or `const` with a name already in use (inside a function, also by a top-level variable), `as` at top level with the name of a buffer, of data or of a `const`, `as` with the name of a local, a `local` with a name the function already uses, a parameter with the name of a `var`, a parameter named twice, a second `label` with the same name in one scope, or a second `fn` with the same name |
| `undefined label` *name* | 1 | a jump to a label that is not defined at top level or in the same function as the jump |
| `unknown service` *name* | 1 | an [`rt`](#rt) whose name is no service of the runtime |
| `undefined function` *name* | 1 | a `call`, `tail`, `ref` or `spawn` of a function that the program never defines; a `spawn` or `join` in a program without `lib/std/task.aiw`, with the name `spawn` or `join` |
| `wrong argument count` *name* | 1 | a `call`, `tail` or `spawn` whose number of values differs from the number of parameters of the function named; a `join` without exactly one value |
| `wrong result count` | 1 | two `ret` statements of one function with different numbers of values; a `ret` of an async function with more than one; with the name of the function, a `call` with more names after `as` than it has results, or a `tail` to a function whose number of results is not that of the function the `tail` stands in |
| `invalid access` *name* | 1 | a load or store through a known address that leaves the buffer or data named, or a store into data; without a name, the same through a string; see [`load` and `store`](#load-and-store) |
| `number too big` | 1 | an integer above 18446744073709551615, below -9223372036854775808 or with more than sixteen hexadecimal digits |
| `buffers too big` | 1 | a buffer larger than 2 GiB or the locals of a function exceeding it; without a place, buffers that together with the code exceed it |
| `cannot read file` *path* | 1 | the path of a `use` cannot be opened or read; the path is the one that was opened, with the directory of its [package](#packages) |
| `unknown package` *name* | 1 | a `use` of `name:path` when no argument of the compiler names that package |
| `source too big` | 1 | the source and the files it names with `use` are together larger than 8 MiB (8388608 bytes); no place |
| `program too big` | 1 | the compiled code does not fit; with the source limit this cannot happen, and the message exists so that a mistake in that reckoning is an error and not a damaged program; no place |
| `usage: ailc [name=directory]... < source > executable` | 2 | an argument of the compiler that names no [package](#packages), or a name given twice; no place |
| `read error` | 2 | reading stdin failed; no place |
| `write error` | 2 | writing the executable to stdout failed, a pipe closed by its reader included; no place |

What remains a plain `syntax error`:

- a keyword not followed by a space or tab
- `sys` not followed by an integer, the name of a `const` or a syscall name
- `len` of a number, a `var` or a `const`; `at` whose first value is not the name of a buffer, data or local
- a size that is neither an integer nor a `const` after `buf` or `local`; a `const` without an integer
- `data` without an item or with an item that is not a string or an integer from 0 to 255
- `use` without a path in quotes, with an empty path or one of more than 4095 bytes
- a statement that defines something followed by anything but a comment: `buf`, `var`, `const`, `data`, `label`, `local`, `use`, `fn`, `else`, `end`
- `while` with nothing after it
- more than one name after `as` on a statement that is not `call` or `callp`, more than six on those, or anything but a comment after the names
- two tokens with no space or tab between them
- a byte other than space or tab used as a separator, or a CR not followed by LF, in a comment too
- `\x` in a string without two hexadecimal digits after it
- an argument that is not an integer, a string, a variable name, a global name or an [expression](#expressions)
- an expression with a parenthesis that is not closed or not opened, an operator without a value on each side, two values without an operator between them, a byte that is no operator, or a string in it
- an expression where a name is required, or for the number of `sys`
- an assignment with a space beside its `=`, with nothing after it, or with a second value
- `-` or `0x` without a digit after it

The output has no debugging information: a fault at run time is reported by the kernel as a signal, with no line. The exit status says which: 139 for an invalid memory access, 136 for a division by zero, 132 for the trap of [`at`](#at).

## Examples

Print the digits 0 to 9, one per line:

```
buf out 2
add out 1 as p
storeb p 10
set 0 as i
label top
add i 48 as d
storeb out d
sys 1 1 out 2
add i 1 as i
jlt i 10 top
```

Copy up to 4096 bytes of stdin to stdout, in upper case only for the first byte:

```
buf b 4096
sys 0 0 b 4096 as n
loadb b as c
sub c 32 as c
storeb b c
sys 1 1 b n
```

Write a string given by address and length, from a function that returns the number of bytes written:

```
fn put p n
sys 1 1 p n as r
ret r
end
call put "ail\n" as n   # a string is two values: address and length
sys 60 n                # exit(4)
```

Print to stdout:

```
sys 1 1 "hello world\n"
```

Print to stderr and exit with status 3:

```
sys 1 2 "failed\n"
sys 60 3
```

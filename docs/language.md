# AIL language reference

This describes exactly what the compilers accept today, stage0 and stage1 alike. The language is deliberately tiny; see the [roadmap](roadmap.md) for what comes next.

## Design rules

AIL is written by AI, so the cost that matters is tokens, not keystrokes or human readability.

- Short common words separated by spaces. No punctuation unless it carries information.
- No boilerplate: no `main`, no imports, no statement terminators, no declarations that the compiler can derive.
- Hardware-oriented: statements map directly onto machine operations. There are no classes or objects.

## Program structure

A program is a sequence of statements, one per line. Execution starts at the first statement and runs downwards unless a [jump](#control-flow) sends it elsewhere. After the last statement the compiler appends `exit(0)`.

A [function](#functions) may stand anywhere between the statements. Execution passes around its body, which only runs when the function is called.

Blank lines are ignored. Indentation is ignored.

## Separators

The same rule holds everywhere outside string literals:

- Tokens (the keyword, numbers, strings, names, `as`) are separated by one or more spaces or tabs. Two tokens may not touch: `1"x"` and `"a""b"` are errors.
- A line ends with LF or CRLF. A CR that is not followed by LF is an error, also inside a comment; only a string may contain one.
- `#` starts a comment and may directly follow a token.

No other byte separates anything. A NUL or any other control character between tokens is a syntax error.

## Statements

### `sys`

```
sys n a b c d e f
sys n a b c d e f as name
```

Performs the raw Linux x86-64 syscall number `n` with up to six arguments. With `as name`, the syscall's return value is kept in the variable `name` (see [Variables](#variables)). `n` must be an [integer](#integers) or the name of a [`const`](#const), not a variable or a string. The statement ends at the end of the line.

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

Syscall numbers are the kernel's own; the common ones are `0` read, `1` write, `60` exit. A `const` gives one a name: `const write 1` allows `sys write 1 "hi\n"`.

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

Arithmetic is 64-bit and wraps silently: `sub 0 1` is all ones. A shift uses only the low 6 bits of `b`. Dividing by zero kills the program with `SIGFPE`. The result may go into one of the operands: `add i 1 as i`.

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

All 64 bits of both values are compared and the result is a full 64-bit `1` or `0`. Ordering is unsigned, like `div` and `mod`: the result of `sub 0 1` is the largest value, not a negative one, so `lt 1 x` is `1` for it. A comparison only produces a value; [`jz` and `jnz`](#control-flow) act on it.

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
```

`label` names the point in the program where it stands; it emits no code. `jmp` continues execution at a label. `jz` jumps if the value `a` is zero and `jnz` if it is not, otherwise execution goes on with the next line. All 64 bits of the value are tested, so a comparison result can be used directly. The value is any [argument](#arguments).

A label may be defined before or after the jumps that use it, and a label after the last statement stands at the appended `exit(0)`. Each label is defined once. Label names follow the rules of variable names but are a separate name space: a label may share its name with a variable or a buffer, and may be called `as`. There is no limit on the number of labels or jumps.

```
set 0 as i
label top
sys 1 1 "x"
add i 1 as i
lt i 3 as c
jnz c top               # prints xxx
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

### Functions

```
fn name a b
...
ret value
end

call name x y as result
call name x y
```

`fn` starts a function and `end` closes it. The names after the function name are its parameters; there may be none and at most 64. A function cannot be defined inside another one. Where a function stands does not matter: top-level execution skips its body, and a `call` may come before or after the definition.

`call` passes its values to the parameters in order and runs the function. With `as`, the value the function returns is kept in a variable; without it the value is dropped. A value is any [argument](#arguments), and the number of values must equal the number of parameters; a string is two values, its address and its length, so that a function taking `p n` can be called with a literal.

`ret value` returns that one value to the caller and is only allowed inside a function. Reaching `end` returns `0`.

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

Calling convention: the first six values travel in `rax`, `rdi`, `rsi`, `rdx`, `r10` and `r8`, in order, with all 64 bits; the caller pushes any further values on the stack, in order, and removes them after the call. The result comes back in `rax`. The function saves the six variable registers on the stack when it starts and restores them when it returns, so a call uses 56 bytes of stack, plus 8 for each value after the sixth and 8 for each variable of the function that did not get a register, and recursion is limited only by the stack size.

### `buf`

```
buf name size
```

Reserves `size` bytes of writable memory, filled with zeros when the program starts, and makes `name` their address. `size` is an [integer](#integers) or the name of a [`const`](#const) and is rounded up to a multiple of 8, so every buffer is 8-byte aligned. A size of 0 is allowed: the name is then an address with no bytes of its own, for instance a mark between two buffers.

A buffer name is a constant, not a variable: it uses none of the variables of a scope, and it can be used wherever a value is accepted, as one argument. It may be declared before or after the lines that use it. Variables and global names (buffers, data, [`var`](#var) and [`const`](#const)) share one name space. There is no limit on the number of buffers; the memory is reserved when the program is loaded and never freed.

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

`alloc` asks the kernel for `size` bytes of memory at run time and keeps their address in a variable, or 0 if the kernel refuses. The bytes are zero-filled and the address is a multiple of 16. `free` gives back what one `alloc` returned; `free 0` does nothing. After `free` the address must not be used again.

```
alloc n as p
jz p fail
...
free p
```

Each `alloc` is a memory mapping of its own (`mmap` and `munmap`, with 16 bytes in front for the length), so it costs a system call and at least a page: use it for storage whose size is only known at run time, a `buf` for what is fixed and a `local` for what a call needs. Both statements overwrite the registers of the [`sys`](#sys) arguments; variables are untouched.

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

`as name` at the end of a statement defines the variable and stores the statement's result in it. For `sys` that is the syscall's raw return value: the result, or a negative error number. Nothing but a comment may follow it on the line. Using `as` with a name that already exists overwrites that variable. `as` is the only way to set a variable; `set 5 as x` sets one to a constant.

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

An address is a 64-bit integer like any other value. It can be computed, compared, stored in memory, passed to a function and handed to the kernel, and nothing in the language records where it came from or how long it stays valid. That is deliberate: the language describes what the machine does, and the machine has no pointers, only numbers.

What the language offers against mistakes is therefore local and explicit:

- the compiler rejects an access it can prove wrong ([`load` and `store`](#load-and-store)) and a read of a variable that may be unassigned ([control flow](#control-flow));
- [`at`](#at) checks an offset at run time where the program asks for it;
- the lifetime of storage follows from how it was obtained: a `buf` and `data` live as long as the program, a [`local`](#local) until its function returns, and an [`alloc`](#alloc-and-free) until its `free`, after which the memory is unmapped and a use of it faults instead of reading stale bytes, unless a later `alloc` was given the same pages.

There is no ownership or borrow checking. A function receives addresses as plain values and may keep them; a syscall receives them the same way.

## Comments

`#` starts a comment that runs to the end of the line, either on its own line or after a statement. A `#` inside a string is part of the string. A comment may hold any byte except a CR that is not followed by LF, and it may end the source without a line end.

## Errors

The compiler prints one line on stderr and exits with a non-zero status. No line number is reported.

| Message | Status | Cause |
|---|---|---|
| `ailc: syntax error` | 1 | see below |
| `ailc: undefined variable` | 1 | a name used as a value that is no variable of its scope at that line and that no `buf` or `data` declares anywhere in the source; a `var` or `const` used before its declaration. It is reported after the whole source has been read, so any other error comes first |
| `ailc: unassigned variable` | 1 | a variable read, or a jump back to a label, on a way that may not have assigned it; see [Control flow](#control-flow) |
| `ailc: too many variables` | 1 | a 65th variable name at top level or in one function, parameters included |
| `ailc: duplicate name` | 1 | `buf`, `data`, `var` or `const` with a name already in use (inside a function, also by a top-level variable), `as` at top level with the name of a buffer, of data or of a `const`, `as` with the name of a local, a `local` with a name the function already uses, a parameter with the name of a `var`, a parameter named twice, a second `label` with the same name in one scope, or a second `fn` with the same name |
| `ailc: undefined label` | 1 | a jump to a label that is not defined at top level or in the same function as the jump |
| `ailc: undefined function` | 1 | a `call` of a function that the program never defines |
| `ailc: wrong argument count` | 1 | a `call` whose number of values differs from the number of parameters |
| `ailc: invalid access` | 1 | a load or store through a known address that leaves its buffer, data or string, or a store into data or a string; see [`load` and `store`](#load-and-store). Reported after the whole source has been read |
| `ailc: number too big` | 1 | an integer above 18446744073709551615, below -9223372036854775808 or with more than sixteen hexadecimal digits |
| `ailc: buffers too big` | 1 | a buffer larger than about 3.7 GiB, or buffers that together exceed that; the locals of a function exceeding about 2 GiB |
| `ailc: source too big` | 1 | source larger than 65536 bytes |
| `ailc: read error` | 2 | reading stdin failed |
| `ailc: write error` | 2 | writing the executable to stdout failed, a pipe closed by its reader included |

Status 1 means the source is at fault; status 2 means the environment is.

Causes of a syntax error:

- a line that does not start with a statement keyword
- a keyword not followed by a space or tab
- `sys` not followed by an integer or the name of a `const`
- the wrong number of operands: `set`, `len` and the loads take one, the stores, the arithmetic statements and the comparisons take two
- `set`, `len`, an arithmetic statement, a comparison or a load without `as`, or a store with `as`
- `len` of a number, a `var` or a `const`
- `local` outside a function, without a name and a size (an integer or a `const`), or followed by anything but a comment
- `at` without a name of a buffer, data or local first, then exactly two values and `as`
- `alloc` without exactly one value and `as`, `free` without exactly one value or with `as`
- `var` without a name, or with something that is not a name or is `as`
- `const` without a name and an integer, with the name `as`, or followed by anything but a comment
- `data` without an item, with an item that is not a string or an integer from 0 to 255, with the name `as`, or followed by anything but a comment
- `buf` without a name and a size (an integer or a `const`), with the name `as`, or followed by anything but a comment
- `label` without a name, or followed by anything but a comment
- `jmp` with a value, `jz` or `jnz` without exactly one, any of them without a label name or with `as`, or followed by anything but a comment
- `fn` without a name, inside another function, or with a parameter that is not a name or is `as`; a function without its `end`
- `end` outside a function, or followed by anything but a comment
- `ret` outside a function, without exactly one value, or with `as`
- `call` without a function name
- two tokens with no space or tab between them
- a byte other than space or tab used as a separator, or a CR not followed by LF, in a comment too
- `\x` in a string without two hexadecimal digits after it
- an argument that is not an integer, a string, a variable name or a global name
- `-` or `0x` without a digit after it
- `as` without a name, with the name `as`, or followed by anything but a comment
- more than seven values after `sys` (the syscall number plus six arguments; a string counts as two)
- a string with no closing quote

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
lt i 10 as c
jnz c top
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

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

Performs the raw Linux x86-64 syscall number `n` with up to six arguments. With `as name`, the syscall's return value is kept in the variable `name` (see [Variables](#variables)). `n` must be a decimal integer, not a string. The statement ends at the end of the line.

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

Syscall numbers are the kernel's own; the common ones are `0` read, `1` write, `60` exit.

### `set` and arithmetic

```
set a as name
add a b as name
```

`set` copies one value into a variable. The arithmetic statements take two values and keep the result in a variable. All of them need `as name`; an operand is an integer, a variable or a buffer name, never a string.

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

A comparison takes two values like an arithmetic statement and keeps `1` in the variable if it holds, `0` if not. It needs `as name`; an operand is an integer, a variable or a buffer name, never a string.

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

`label` names the point in the program where it stands; it emits no code. `jmp` continues execution at a label. `jz` jumps if the value `a` is zero and `jnz` if it is not, otherwise execution goes on with the next line. All 64 bits of the value are tested, so a comparison result can be used directly. The value is an integer, a variable or a buffer name, never a string.

A label may be defined before or after the jumps that use it, and a label after the last statement stands at the appended `exit(0)`. Each label is defined once. Label names follow the rules of variable names but are a separate name space: a label may share its name with a variable or a buffer, and may be called `as`. There is no limit on the number of labels or jumps.

```
set 0 as i
label top
sys 1 1 "x"
add i 1 as i
lt i 3 as c
jnz c top               # prints xxx
```

A jump does not touch any variable. Whether a variable is defined depends on the order of the lines, not on the path taken: a variable read on a path that jumped over its `as` holds an unspecified value.

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

`fn` starts a function and `end` closes it. The names after the function name are its parameters; there may be none and at most six. A function cannot be defined inside another one. Where a function stands does not matter: top-level execution skips its body, and a `call` may come before or after the definition.

`call` passes its values to the parameters in order and runs the function. With `as`, the value the function returns is kept in a variable; without it the value is dropped. A value is an integer, a variable or a buffer name, never a string, and the number of values must equal the number of parameters.

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

- The parameters are the function's first variables. Together with the variables it defines with `as`, a function has at most six.
- A function sees none of the variables defined outside it, and its variables do not exist outside it. The same name can be used on both sides for different things. Values go in through the parameters and out through `ret`.
- Every call gets fresh variables: the caller's variables, at top level or in another function, are unchanged when the call returns, also when a function calls itself.
- Buffers are global. A function can use any buffer declared on an earlier line, and a `buf` written inside a function is the same as one written outside: its name may not be that of a top-level variable either.

Function names follow the rules of variable names but are a separate name space: a function may share its name with a variable, a buffer or a label, and may be called `as`. Each name is defined once. There is no limit on the number of functions or calls.

Calling convention: the values travel in `rax`, `rdi`, `rsi`, `rdx`, `r10` and `r8`, in order, with all 64 bits, and the result comes back in `rax`. The function saves the six variable registers on the stack when it starts and restores them when it returns, so a call uses 56 bytes of stack and recursion is limited only by the stack size.

### `buf`

```
buf name size
```

Reserves `size` bytes of writable memory, filled with zeros when the program starts, and makes `name` their address. `size` is a decimal integer of at least 1 and is rounded up to a multiple of 8, so every buffer is 8-byte aligned.

A buffer name is a constant, not a variable: it uses none of the six variable registers, and it can be used wherever a value is accepted, as one argument. It must be declared on an earlier line, and it cannot be the target of `as` or the name of a parameter. Variables and buffers share one name space. A program can declare at most 16 buffers; the memory is reserved when the program is loaded and never freed.

```
buf line 4096
sys 0 0 line 4096 as n     # read stdin into it
sys 1 1 line n             # write what was read
```

### `load` and `store`

```
load addr as name       # 64-bit value at addr
loadb addr as name      # byte at addr, zero-extended
store addr value        # write the 64 bits of value at addr
storeb addr value       # write the low byte of value at addr
```

`addr` is any value: a buffer name, a variable holding an address, or an integer. Loads need `as name`; stores do not take it. 64-bit values are little-endian in memory and need no alignment. A string is not accepted as an operand. Nothing is checked at run time: an address outside mapped memory or in read-only memory kills the program with `SIGSEGV`.

```
buf b 8
storeb b 104            # "h"
add b 1 as p
storeb p 10             # newline
sys 1 1 b 2
```

## Arguments

### Integers

Unsigned decimal, 0 to 4294967295. No sign, no hex, no separators. Larger values wrap silently.

### Strings

```
"text"
```

A string literal counts as **two** arguments: the address of its bytes, then its length in bytes. This matches the `buf, count` pair that syscalls such as `write` take, so the length never has to be written out:

```
sys 1 1 "hello world\n"     # write(1, addr, 12)
```

Strings are not NUL-terminated; add `\0` if the callee needs it (it then counts towards the length). String data is read-only at run time.

| Escape | Byte |
|---|---|
| `\n` | 10, newline |
| `\t` | 9, tab |
| `\0` | 0 |
| `\\` | backslash |
| `\"` | double quote |

A backslash before any other character yields that character. A string may span lines; the newline is included as-is.

### Variables

```
sys 1 1 "abc\n" as n     # n = 4, the number of bytes written
sys 60 n                 # exit(4)
```

A variable is a name for a 64-bit value held in a machine register. A name starts with a lowercase letter and continues with lowercase letters, digits and `_`. `as` is reserved.

`as name` at the end of a statement defines the variable and stores the statement's result in it. For `sys` that is the syscall's raw return value: the result, or a negative error number. Nothing but a comment may follow it on the line. Using `as` with a name that already exists overwrites that variable. `as` is the only way to set a variable; `set 5 as x` sets one to a constant.

A variable used as an argument passes its full 64-bit value and counts as one argument. It must be defined by an earlier `as`, and it cannot be the syscall number.

Statement keywords are only special at the start of a line, so `add` or `buf` are valid variable names.

The top level of a program can define at most 6 variables, and so can each [function](#functions), counting its parameters. They live in `rbx`, `rbp`, `r12`, `r13`, `r14` and `r15`, in order of definition, and are never freed within their scope. Syscalls and calls do not change these registers.

Variables hold values only. Memory is always reached through an explicit address: a [buffer](#buf), or one obtained at run time, for example from `mmap`:

```
sys 9 0 4096 3 34 0 0 as p    # mmap one anonymous read-write page
sys 0 0 p 4096 as n           # read stdin into it
sys 1 1 p n                   # write what was read
```

## Comments

`#` starts a comment that runs to the end of the line, either on its own line or after a statement. A `#` inside a string is part of the string. A comment may hold any byte except a CR that is not followed by LF, and it may end the source without a line end.

## Errors

The compiler prints one line on stderr and exits with a non-zero status. No line number is reported.

| Message | Status | Cause |
|---|---|---|
| `ailc: syntax error` | 1 | see below |
| `ailc: undefined variable` | 1 | a name used as an argument before any `as`, parameter or `buf` defined it in this scope |
| `ailc: too many variables` | 1 | a seventh variable name at top level or in one function, parameters included |
| `ailc: duplicate name` | 1 | `buf` with a name already in use (inside a function, also by a top-level variable), `as` or a parameter with the name of a buffer, a parameter named twice, a second `label` with the same name in one scope, or a second `fn` with the same name |
| `ailc: undefined label` | 1 | a jump to a label that is not defined at top level or in the same function as the jump |
| `ailc: undefined function` | 1 | a `call` of a function that the program never defines |
| `ailc: wrong argument count` | 1 | a `call` whose number of values differs from the number of parameters |
| `ailc: too many buffers` | 1 | a seventeenth buffer, or buffers that together exceed about 3.7 GiB |
| `ailc: source too big` | 1 | source larger than 65536 bytes |
| `ailc: read error` | 2 | reading stdin failed |
| `ailc: write error` | 2 | writing the executable to stdout failed, a pipe closed by its reader included |

Status 1 means the source is at fault; status 2 means the environment is.

Causes of a syntax error:

- a line that does not start with a statement keyword
- a keyword not followed by a space or tab
- `sys` not followed by a decimal syscall number
- the wrong number of operands: `set`, `load` and `loadb` take one, `store`, `storeb`, the arithmetic statements and the comparisons take two
- `set`, an arithmetic statement, a comparison or a load without `as`, or a store with `as`
- `buf` without a name and a decimal size of at least 1, with the name `as`, or followed by anything but a comment
- `label` without a name, or followed by anything but a comment
- `jmp` with a value, `jz` or `jnz` without exactly one, any of them without a label name or with `as`, or followed by anything but a comment
- `fn` without a name, inside another function, or with a parameter that is not a name or is `as`; a function without its `end`
- `end` outside a function, or followed by anything but a comment
- `ret` outside a function, without exactly one value, or with `as`
- `call` without a function name, or with more than six values
- two tokens with no space or tab between them
- a byte other than space or tab used as a separator, or a CR not followed by LF, in a comment too
- a string anywhere but in a `sys` statement
- an argument that is not a decimal integer, a string, a variable name or a buffer name
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
buf b 4
store b 174877025       # "ail\n"
call put b 4 as n
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

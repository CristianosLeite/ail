# AIL language reference (stage0)

This describes exactly what the stage0 compiler accepts today. The language is deliberately tiny; see the [roadmap](roadmap.md) for what comes next.

## Design rules

AIL is written by AI, so the cost that matters is tokens, not keystrokes or human readability.

- Short common words separated by spaces. No punctuation unless it carries information.
- No boilerplate: no `main`, no imports, no statement terminators, no declarations that the compiler can derive.
- Hardware-oriented: statements map directly onto machine operations. There are no classes or objects.

## Program structure

A program is a sequence of statements, one per line. Execution starts at the first statement and runs downwards. After the last statement the compiler appends `exit(0)`.

Blank lines are ignored. Indentation is ignored.

## Separators

The same rule holds everywhere outside string literals:

- Tokens (the keyword, numbers, strings, names, `as`) are separated by one or more spaces or tabs. Two tokens may not touch: `1"x"` and `"a""b"` are errors.
- A line ends with LF or CRLF. A CR that is not followed by LF is an error.
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

All 64 bits of both values are compared and the result is a full 64-bit `1` or `0`. Ordering is unsigned, like `div` and `mod`: the result of `sub 0 1` is the largest value, not a negative one, so `lt 1 x` is `1` for it. A comparison only produces a value; it does not jump.

```
sub 0 1 as m
gt m 1 as r             # r = 1
```

### `buf`

```
buf name size
```

Reserves `size` bytes of writable memory, filled with zeros when the program starts, and makes `name` their address. `size` is a decimal integer of at least 1 and is rounded up to a multiple of 8, so every buffer is 8-byte aligned.

A buffer name is a constant, not a variable: it uses none of the six variable registers, and it can be used wherever a value is accepted, as one argument. It must be declared on an earlier line, and it cannot be the target of `as`. Variables and buffers share one name space. A program can declare at most 16 buffers; the memory is reserved when the program is loaded and never freed.

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

A program can define at most 6 variables. They live in `rbx`, `rbp`, `r12`, `r13`, `r14` and `r15`, in order of definition, and are never freed. Syscalls do not change these registers.

Variables hold values only. Memory is always reached through an explicit address: a [buffer](#buf), or one obtained at run time, for example from `mmap`:

```
sys 9 0 4096 3 34 0 0 as p    # mmap one anonymous read-write page
sys 0 0 p 4096 as n           # read stdin into it
sys 1 1 p n                   # write what was read
```

## Comments

`#` starts a comment that runs to the end of the line, either on its own line or after a statement. A `#` inside a string is part of the string.

## Errors

The compiler prints one line on stderr and exits with a non-zero status. No line number is reported.

| Message | Status | Cause |
|---|---|---|
| `ailc: syntax error` | 1 | see below |
| `ailc: undefined variable` | 1 | a name used as an argument before any `as` or `buf` defined it |
| `ailc: too many variables` | 1 | a seventh variable name |
| `ailc: duplicate name` | 1 | `buf` with a name already in use, or `as` with the name of a buffer |
| `ailc: too many buffers` | 1 | a seventeenth buffer, or buffers that together exceed about 3.7 GiB |
| `ailc: source too big` | 1 | source larger than 65536 bytes |
| `ailc: read error` | 2 | reading stdin failed |
| `ailc: write error` | 2 | writing the executable to stdout failed |

Status 1 means the source is at fault; status 2 means the environment is.

Causes of a syntax error:

- a line that does not start with a statement keyword
- a keyword not followed by a space or tab
- `sys` not followed by a decimal syscall number
- the wrong number of operands: `set`, `load` and `loadb` take one, `store`, `storeb`, the arithmetic statements and the comparisons take two
- `set`, an arithmetic statement, a comparison or a load without `as`, or a store with `as`
- `buf` without a name and a decimal size of at least 1, with the name `as`, or followed by anything but a comment
- two tokens with no space or tab between them
- a byte other than space or tab used as a separator, or a CR not followed by LF
- a string anywhere but in a `sys` statement
- an argument that is not a decimal integer, a string, a variable name or a buffer name
- `as` without a name, with the name `as`, or followed by anything but a comment
- more than seven values after `sys` (the syscall number plus six arguments; a string counts as two)
- a string with no closing quote

## Examples

Copy up to 4096 bytes of stdin to stdout, in upper case only for the first byte:

```
buf b 4096
sys 0 0 b 4096 as n
loadb b as c
sub c 32 as c
storeb b c
sys 1 1 b n
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

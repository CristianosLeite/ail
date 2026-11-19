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

- Tokens (the keyword, numbers, strings, variable names, `as`) are separated by one or more spaces or tabs. Two tokens may not touch: `1"x"` and `"a""b"` are errors.
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

`as name` at the end of a `sys` statement defines the variable and stores the syscall's raw return value in it: the result, or a negative error number. Nothing but a comment may follow it on the line. Using `as` with a name that already exists overwrites that variable. There is no other way to set a variable yet.

A variable used as an argument passes its full 64-bit value and counts as one argument. It must be defined by an earlier `as`, and it cannot be the syscall number.

A program can define at most 6 variables. They live in `rbx`, `rbp`, `r12`, `r13`, `r14` and `r15`, in order of definition, and are never freed. Syscalls do not change these registers.

Variables hold values only. A buffer is still an address you obtain explicitly, for example from `mmap`:

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
| `ailc: undefined variable` | 1 | a name used as an argument before any `as` defined it |
| `ailc: too many variables` | 1 | a seventh variable name |
| `ailc: source too big` | 1 | source larger than 65536 bytes |
| `ailc: read error` | 2 | reading stdin failed |
| `ailc: write error` | 2 | writing the executable to stdout failed |

Status 1 means the source is at fault; status 2 means the environment is.

Causes of a syntax error:

- a line that does not start with `sys`
- `sys` not followed by a space or tab and then a decimal syscall number
- two tokens with no space or tab between them
- a byte other than space or tab used as a separator, or a CR not followed by LF
- an argument that is not a decimal integer, a string or a variable name
- `as` without a name, with the name `as`, or followed by anything but a comment
- more than seven values after `sys` (the syscall number plus six arguments; a string counts as two)
- a string with no closing quote

## Examples

Print to stdout:

```
sys 1 1 "hello world\n"
```

Print to stderr and exit with status 3:

```
sys 1 2 "failed\n"
sys 60 3
```

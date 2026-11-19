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

## Statements

### `sys`

```
sys n a b c d e f
```

Performs the raw Linux x86-64 syscall number `n` with up to six arguments. The keyword is followed by at least one space or tab, and `n` must be a decimal integer, not a string. Arguments are separated by spaces or tabs and the statement ends at the end of the line.

| Position | Register |
|---|---|
| `n` | `rax` |
| 1st argument | `rdi` |
| 2nd | `rsi` |
| 3rd | `rdx` |
| 4th | `r10` |
| 5th | `r8` |
| 6th | `r9` |

Registers for arguments you leave out are not set and keep whatever they held. The syscall's return value is left in `rax` and cannot be used yet.

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

## Comments

`#` starts a comment that runs to the end of the line, either on its own line or after a statement. A `#` inside a string is part of the string.

## Errors

The compiler prints one line on stderr and exits with a non-zero status. No line number is reported.

| Message | Status | Cause |
|---|---|---|
| `ailc: syntax error` | 1 | see below |
| `ailc: source too big` | 1 | source larger than 65536 bytes |
| `ailc: read error` | 2 | reading stdin failed |
| `ailc: write error` | 2 | writing the executable to stdout failed |

Status 1 means the source is at fault; status 2 means the environment is.

Causes of a syntax error:

- a line that does not start with `sys`
- `sys` not followed by a space or tab and then a decimal syscall number
- an argument that is neither a decimal integer nor a string
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

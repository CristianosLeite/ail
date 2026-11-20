# How the stage1 compiler works

`stage1/ailc.ai` is the AIL compiler written in AIL: about 1170 lines, 17 KiB. It is a translation of [stage0](compiler.md), routine by routine, and behaves exactly like it: the same language, the same executable byte for byte, the same messages and exit statuses. Everything [compiler.md](compiler.md) says about the pipeline, the output file, the code generation and the limits holds for stage1; this page only describes what differs in how it is written.

```
build/ailc  < stage1/ailc.ai > build/ailc1     # stage1 built by stage0
build/ailc1 < stage1/ailc.ai > build/ailc2     # stage1 built by itself
cmp build/ailc1 build/ailc2                    # the same file: a fixed point
```

`make` builds `build/ailc1`, and `make test` builds `build/ailc2` and checks the fixed point.

## Shape of the program

Stage0 is a state machine whose routines jump to each other. Labels are local to a function in AIL, so those routines are the top level of the program, under the same labels as in stage0: `next`, `tokend`, `arg`, `num`, `str`, `ident`, `capture`, `bufdef`, `labdef`, `jtarget`, `fndef`, `fnend` and `fin`. The top level uses the six variables `c d r f p q` and nothing else.

What stage0 reaches with `call` is a function:

| Function | Job |
|---|---|
| `err`, `ebig`, `eund`, `evar`, `edup`, `ebuf`, `elab`, `efn`, `eargc`, `erd`, `ewr` | print one message and exit; a function cannot jump out, so every error is a call that does not return |
| `ok`, `no`, `nodup` | syntax error unless a value is not zero, or is zero; duplicate name unless a lookup found nothing |
| `g`, `s` | read and write a cell of the cold state |
| `pk`, `adv` | the byte at the input cursor, or 256 at the end of the input; advance the cursor |
| `low`, `dig`, `blank` | character classes |
| `crlf`, `blanks`, `blank1`, `eol`, `name`, `rname`, `isas` | as in stage0; `rname` is a name that must start with a letter |
| `eqn`, `same`, `look` | compare bytes; compare a table entry with the name read last; search a table |
| `vbase`, `lvar`, `ltop`, `lbuf`, `llab`, `lfn` | the lookups of stage0; they return an index, or 99999 for a name that is not defined |
| `putn`, `getn` | write the name read last into a table entry, or read it back |
| `defvar`, `kw` | find or add a variable; find the statement row of a keyword |
| `vreg`, `areg` | x86 register number of a variable, or of an argument position |
| `eb`, `e4`, `z`, `cp`, `p4` | append a byte, four bytes, a gap, or a copy; patch four bytes |
| `mrr`, `mov`, `eop`, `resolve` | `emit_mov_rr`, `emit_mov`, `emit_op` and `resolve` of stage0 |

Because `pk` returns 256 at the end of the input, the pairs "at the end?" and "which byte?" of stage0 are one comparison each.

## State

A function sees no top-level variable, so the fixed registers of stage0 are 8-byte buffers, whose names are addresses usable from anywhere:

| Buffer | Stage0 | Holds |
|---|---|---|
| `ip`, `ie` | `rsi`, `r15` | input cursor and end |
| `op` | `rdi` | output cursor |
| `ai` | `ebx` | index of the next argument of the statement |
| `nv` | `ebp` | number of variables in the current scope |
| `cur` | `curop` | statement row, at its operand count |
| `ns`, `nl` | `r8`, `r9` | start and length of the name read last |

The other buffers are `in` and `out`, the tables `labs`, `fixs`, `funs` and `calls`, `ro` for the read-only tables and `st` for everything else: the counters and saved scope of stage0 at fixed offsets (listed at the top of the source), the variable table and the buffer table. That makes sixteen buffers, the limit. The tables hold the same number of entries as in stage0, but an entry carries all the fields of its name (a label entry is name, length and address), where stage0 has parallel arrays.

## Read-only tables

A string is only accepted by `sys`, so the program cannot contain constant data. The tables that stage0 keeps in `.rodata` are written into `ro` when the compiler starts, four bytes a line, by `call e4 <number>` with the bytes as one little-endian decimal, and `call z <n>` over runs of zeros:

| Offset in `ro` | Table |
|---|---|
| 0 | the 176-byte ELF header template |
| 176 | the statements: per row the name length, the name, the operand count, the flags, the code length and the code, then a zero byte |
| 490 | the code of `ret`, inside its row |
| 531, 541, 555, 562, 568 | `fnpush`, `regtab`, `argnum`, `varnum`, `exit0` |

The statement table has the rows of `optab` in stage0 plus four with the flag 64 for the statements parsed on their own: the operand count of such a row says which (1 `fn`, 2 `buf`, 3 `end`, 4 `label`), so `next` finds every keyword with the one search `kw`.

To change a row, change the numbers: the line of the byte at offset `n` is found by counting four bytes per `call e4` and the given count per `call z` from `store op ro`.

## Writing bytes with 64-bit stores

AIL stores a byte or 64 bits. `e4` appends four bytes with a 64-bit `store` and advances the cursor by four: the four bytes after them are cleared, which is harmless ahead of the cursor, where nothing has been written. A displacement is patched behind the cursor, so `p4` loads the eight bytes, replaces the low four and stores them back.

## What the translation had to match

- A number is accumulated modulo 2^32, as `imul eax, eax, 10` does: `num` masks after every digit. The size of a `buf` is accumulated in 64 bits against the limit, as in stage0.
- A negative syscall result is tested unsigned: a `read` result above the buffer size is an error, and a `write` result is good when `result - 1` is below the bytes left.
- The order of the checks in a routine decides which message a source with two faults gets, so it follows stage0 line by line.

## Tests

`tests/stage1.sh` gives every test source and every example to both compilers and requires the same stdout, stderr and exit status, then compares `build/ailc1` with `build/ailc2`. `tests/run.sh` and `tests/io.sh` take the compiler from the environment variable `AILC`, and `make test` runs them once with each compiler, naming it in both runs so that an `AILC` in the environment of `make` cannot replace stage0. All three scripts kill a compiler that runs for more than 10 seconds and fail the test.

## Friction found

Writing stage1 did not need any change to the language, but these cost the most and are the candidates for the next extensions:

- **No constant data.** The tables are 131 lines of decimal numbers that no one can read. A string usable as a value outside `sys` would replace them.
- **Sixteen buffers.** Every global scalar wants a buffer of its own, because a buffer name is the only global name; the limit forced most of them into `st`, behind the accessors `g` and `s`.
- **No 32-bit store**, hence `e4` and `p4`.
- **Six variables** were enough everywhere, at the price of some reloading in `eop` and at the top level.

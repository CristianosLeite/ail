# How the stage1 compiler works

`stage1/ailc.ai` is the AIL compiler written in AIL: about 2150 lines, 33 KiB. It is a translation of [stage0](compiler.md), routine by routine, and behaves exactly like it: the same language, the same executable byte for byte, the same messages and exit statuses. Everything [compiler.md](compiler.md) says about the pipeline, the output file, the code generation and the limits holds for stage1; this page only describes what differs in how it is written.

```
build/ailc  < stage1/ailc.ai > build/ailc1     # stage1 built by stage0
build/ailc1 < stage1/ailc.ai > build/ailc2     # stage1 built by itself
cmp build/ailc1 build/ailc2                    # the same file: a fixed point
```

`make` builds `build/ailc1`, and `make test` builds `build/ailc2` and checks the fixed point.

## Shape of the program

Stage0 is a state machine whose routines jump to each other. Labels are local to a function in AIL, so those routines are the top level of the program, under the same labels as in stage0: `next`, `tokend`, `arg`, `num`, `str`, `ident`, `capture`, `bufdef`, `localdef`, `vardef`, `constdef`, `datadef`, `labdef`, `jtarget`, `fndef`, `fnend` and `fin`. The top level uses the six variables `c d r f p q`, which are the ones that get registers there.

What stage0 reaches with `call` is a function:

| Function | Job |
|---|---|
| `err`, `ebig`, `eund`, `evar`, `edup`, `enum`, `eunasg`, `eacc`, `ebuf`, `elab`, `efn`, `eargc`, `erd`, `ewr` | print one message and exit; a function cannot jump out, so every error is a call that does not return |
| `ok`, `no`, `nodup` | syntax error unless a value is not zero, or is zero; duplicate name unless a lookup found nothing |
| `pk`, `adv` | the byte at the input cursor, or 256 at the end of the input; advance the cursor |
| `low`, `dig`, `blank` | character classes |
| `crlf`, `blanks`, `blank1`, `eol`, `tokchk`, `name`, `rname`, `isas` | as in stage0; `rname` is a name that must start with a letter |
| `hexd`, `sbytes` | `hexdig` and `strbytes` of stage0 |
| `eqn`, `same`, `look` | compare bytes; compare a table entry with the name read last; search a table |
| `vbase`, `lvar`, `ltop`, `lbuf`, `llab`, `lfn` | the lookups of stage0; they return an index, or 99999 for a name that is not defined |
| `gent`, `newglob`, `cname`, `rdname`, `rdnum` | the entry of a global name; `newglob`, `constname`, `rdname` and `rdnum` of stage0 |
| `ldvar` | the `mov` that reads the cell of a `var` |
| `putn`, `getn` | write the name read last into a table entry, or read it back |
| `defvar`, `kw` | find or add a variable; find the statement row of a keyword |
| `areg`, `aidx`, `anext` | x86 register number of an argument position; `argidx` and `argnext` of stage0 |
| `vplace`, `vmov`, `emem`, `frame`, `popskip`, `alloc` | `varplace`, `emit_varmov`, `emit_mem`, `emit_frame`, `popskip` and `alloc` of stage0; `vplace` returns one number: a register below 16, else 16 plus a distance from `rsp`, else the address of a cell, else for a local 0x40000001 plus a distance from `rsp` |
| `eb`, `e4`, `z`, `cp` | append a byte, four bytes, a gap, or a copy; a displacement is patched with `store4` |
| `mrr`, `mov`, `eop`, `resolve` | `emit_mov_rr`, `emit_mov`, `emit_op` and `resolve` of stage0 |
| `atfirst`, `addref` | as in stage0; the state `atname` is at top level |
| `opdp`, `opda`, `prop`, `clrvk`, `memchk`, `cp4` | `opdptr`, `opdaddr`, `propagate`, `clrvk` and `memchk` of stage0; `cp4` copies an entry |
| `godead`, `labasg` | as in stage0; a bit of `asg` is tested with a shift and set with `or`, where stage0 uses `bt` and `bts` |

Because `pk` returns 256 at the end of the input, the pairs "at the end?" and "which byte?" of stage0 are one comparison each.

## State

A function sees no top-level variable, so the fixed registers of stage0 are global `var`s:

| Var | Stage0 | Holds |
|---|---|---|
| `ip`, `ie` | `rsi`, `r15` | input cursor and end |
| `op` | `rdi` | output cursor |
| `ai` | `ebx` | index of the next argument of the statement |
| `nv` | `ebp` | number of variables in the current scope |
| `cur` | `curop` | statement row, at its operand count |
| `ns`, `nl` | `r8`, `r9` | start and length of the name read last |

The counters and the saved scope of stage0 are `var`s too, under its names (`nbufs`, `bsssz`, `nlabels`, `infn`, ...). The buffers are `in` and `out`, `sig` for the `sigaction` structure, and the tables `vars`, `globs` (global names), `labs`, `fixs`, `funs`, `calls`, `refs` and `chks`, the knowledge tables `opd` and `vk`, `runend`, and the tables of the variable allocation (`topcell`, `vfirst`, `vlast`, `fnloc`, `locfree`, `loops`). The state saved before the first pass over a function is in the vars `sip` to `sdr`. The tables hold the same number of entries as in stage0, but an entry carries all the fields of its name (a label entry is name, length and address), where stage0 has parallel arrays.

## Read-only tables

The tables that stage0 keeps in `.rodata` are `data` statements at the end of the source, after the code that uses them, under the names stage0 uses: `hdr`, `optab`, `fnpush`, `pushlen`, `probe`, `regtab`, `argnum`, `varnum` and `exit0`, plus `retc` for the code of `ret`, which stage0 takes from inside its row. A table is a run of `data` lines, one row a line, with the name on the first.

The statement table has the rows of `optab` in stage0, each written as its name length, its name as a string, the operand count, the two flag bytes, the code length and the code. It has eight more rows whose flags are 255 for the statements parsed on their own (128 alone is `IS_MEM`): the operand count of such a row says which (1 `fn`, 2 `buf`, 3 `end`, 4 `label`, 5 `data`, 6 `var`, 7 `const`, 8 `local`), so `next` finds every keyword with the one search `kw`.

## What the translation had to match

- Stage0 finds a decimal overflow in the carry flag after `mul` and `add`. AIL has no flags, so `rdnum` compares before it multiplies: the value may not be above 0x1999999999999999 (2^64 / 10, rounded down), nor equal to it with a digit above 5.
- A negative syscall result is tested unsigned: a `read` result above the buffer size is an error, and a `write` result is good when `result - 1` is below the bytes left.
- The order of the checks in a routine decides which message a source with two faults gets, so it follows stage0 line by line.

## Tests

`tests/stage1.sh` gives every test source and every example to both compilers and requires the same stdout, stderr and exit status, then compares `build/ailc1` with `build/ailc2`. `tests/run.sh` and `tests/io.sh` take the compiler from the environment variable `AILC`, and `make test` runs them once with each compiler, naming it in both runs so that an `AILC` in the environment of `make` cannot replace stage0. All three scripts kill a compiler that runs for more than 10 seconds and fail the test.

## Friction found

Writing stage1 did not need any change to the language, but these cost the most and are the candidates for the next extensions:

- **No constant data.** The tables were 131 lines of decimal numbers that no one could read, written into a buffer at start. `data` replaced them, and with them the offsets into that buffer.
- **Sixteen buffers.** Every global scalar wanted a buffer of its own, because a buffer name was the only global name; the limit forced most of them into one buffer behind two accessors. `var` replaced both, and the limit is gone.
- **No 32-bit store.** Appending four bytes cleared the four after them, and patching a displacement meant loading eight bytes, replacing half and storing them back. `store4` does both directly.
- **Six variables** were enough everywhere, at the price of some reloading in `eop` and at the top level. A scope has 64 now, and `alloc` is the first function of stage1 that uses more than six.

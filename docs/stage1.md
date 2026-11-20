# How the stage1 compiler works

`stage1/ailc.ai` is the AIL compiler written in AIL, with its tables in `stage1/tables.ai`: about 2500 lines and 40 KiB together. It is a translation of [stage0](compiler.md), routine by routine, and behaves exactly like it: the same language, the same executable byte for byte, the same messages and exit statuses. Everything [compiler.md](compiler.md) says about the pipeline, the output file, the code generation and the limits holds for stage1; this page only describes what differs in how it is written.

```
build/ailc  < stage1/ailc.ai > build/ailc1     # stage1 built by stage0, from the top of the repository
build/ailc1 < stage1/ailc.ai > build/ailc2     # stage1 built by itself
cmp build/ailc1 build/ailc2                    # the same file: a fixed point
```

`make` builds `build/ailc1`, and `make test` builds `build/ailc2` and checks the fixed point.

## Seeds

That fixed point is what makes stage1 able to stand without stage0: a released copy of `build/ailc1` compiles the source it came from to itself. Such a copy is a seed. `seed/MANIFEST` lists the seeds, one a line: the version, the commit whose `stage1/ailc.ai` and `stage1/tables.ai` it was built from, the SHA-256 of the file and the address of the release that keeps it (`seed-<version>`, file `ailc-<version>`). The last line is the seed the build is pinned to; earlier lines stay, so that an older revision can be built with its own seed. A local copy is `seed/ailc-<version>`, which git ignores.

Seed 1 is stage1 as stage0 built it on 2026-11-20, 30796 bytes, the same file when built again by itself. The build does not use it yet.

## Shape of the program

Stage0 is a state machine whose routines jump to each other. Labels are local to a function in AIL, so those routines are the top level of the program, under the same labels as in stage0: `next`, `tokend`, `arg`, `num`, `str`, `ident`, `capture`, `usedef`, `uend`, `bufdef`, `localdef`, `vardef`, `constdef`, `datadef`, `labdef`, `blkend`, `elsedef`, `jtarget`, `fndef`, `fnend` and `fin`. The top level uses the six variables `c d r f p q`, which are the ones that get registers there.

What stage0 reaches with `call` is a function:

| Function | Job |
|---|---|
| `err`, `estmt`, `eplace`, ..., `erd`, `ewr` | one function per message, as the stubs of stage0: set the name or drop the place if the message wants that, and call `die`; a function cannot jump out, so every error is a call that does not return |
| `die`, `ew` | print the line of an error as stage0 does, from `epos`, `curunit` and the name in `ename`, and exit |
| `ok`, `no`, `nodup` | syntax error unless a value is not zero, or is zero; duplicate name unless a lookup found nothing |
| `pk`, `adv` | the byte at the input cursor, or 256 at the end of the input; advance the cursor |
| `ochk` | `outchk` of stage0 |
| `low`, `dig`, `blank` | character classes |
| `crlf`, `blanks`, `blank1`, `eol`, `tokchk`, `name`, `rname`, `isas` | as in stage0; `rname` is a name that must start with a letter |
| `hexd`, `sbytes` | `hexdig` and `strbytes` of stage0 |
| `eqn`, `same`, `look` | compare bytes; compare a table entry with the name read last; search a table |
| `vbase`, `lvar`, `ltop`, `lbuf`, `llab`, `lfn` | the lookups of stage0; they return an index, or -1 for a name that is not defined |
| `hhash`, `hfind`, `hadd`, `hundo`, `hval`, `globdone` | the hash of names as in stage0, with nodes of 64 bytes; `hfind` returns the node or 0, and `hval` its index or -1 |
| `gent`, `newglob`, `cname`, `sname`, `rdname`, `rdnum` | the entry of a global name; `newglob`, `constname`, `sysname`, `rdname` and `rdnum` of stage0 |
| `ldvar` | the `mov` that reads the cell of a `var` |
| `putn`, `getn` | write the name read last into a table entry, or read it back |
| `defvar`, `kw` | find or add a variable; find the statement row of a keyword |
| `areg`, `aidx`, `anext` | x86 register number of an argument position; `argidx` and `argnext` of stage0 |
| `vplace`, `vmov`, `emem`, `frame`, `popskip`, `alloc` | `varplace`, `emit_varmov`, `emit_mem`, `emit_frame`, `popskip` and `alloc` of stage0; `vplace` returns two results, the kind and the value, as `varplace` does in `edx` and `ecx` |
| `eb`, `e4`, `z`, `cp` | append a byte, four bytes, a gap, or a copy; a displacement is patched with `store4` |
| `mrr`, `mov`, `elea`, `eop`, `resolve` | `emit_mov_rr`, `emit_mov`, `emit_lea`, `emit_op` and `resolve` of stage0 |
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

The counters and the saved scope of stage0 are `var`s too, under its names (`nbufs`, `bsssz`, `nlabels`, `infn`, ...). The buffers are `in` and `out`, `sig` for the `sigaction` structure, and the tables `vars`, `globs` (global names), `labs`, `fixs`, `funs`, `calls`, `refs` and `chks`, the knowledge tables `opd` and `vk`, `runend`, and the tables of the variable allocation (`topcell`, `vfirst`, `vlast`, `fnloc`, `locfree`, `loops`). The state saved before the first pass over a function is in the vars `sip` to `sdr`. The buffers have the sizes of stage0 for a source of 8 MiB, written out as numbers, with the input size as the const `inmax`. The tables hold the same number of entries as in stage0, but an entry carries all the fields of its name (a label entry is name, length and address), where stage0 has parallel arrays.

## Read-only tables

The tables that stage0 keeps in `.rodata` are `data` statements in a file of their own, `stage1/tables.ai`, which the last line of `stage1/ailc.ai` names with `use "stage1/tables.ai"`. The path is relative to the directory the compiler runs in, so stage1 is compiled from the top of the repository, as the Makefile does. The tables stand after the code that uses them, under the names stage0 uses: `hdr`, `optab`, `sysnames`, `fnpush`, `zeroes`, `zerolen`, `pushlen`, `probe`, `regtab`, `argnum`, `varnum` and `exit0`, plus `retc` for the code of `ret`, which stage0 takes from inside its row. A table is a run of `data` lines, one row a line, with the name on the first.

The file is not written by hand. `tools/tables.sh` assembles `stage0/ailc.s`, takes the bytes of its `.rodata` between the symbols of the tables and prints them as `data` lines, the rows of the two tables that have names with the name as a string. The tables therefore have one definition, the assembly, where a row can be written as instructions; `make tables` writes the file again, and `tests/tables.sh` fails in `make test` when it differs from what the generator prints.

The statement table has each row as its name length, its name as a string, the operand count, the two flag bytes, the code length and the code. Its last ten rows have the flags 255 and no code: they are the statements parsed on their own, and the operand count of such a row says which (1 `fn`, 2 `buf`, 3 `end`, 4 `label`, 5 `data`, 6 `var`, 7 `const`, 8 `local`, 9 `use`, 10 `else`), so `next` finds every keyword with the one search `kw`. Stage0 has the same ten rows and never reaches them, because it checks those keywords before it searches the table.

## Control flow

The states of the top level are labels, as in stage0, and jump to each other. Inside a state and inside the functions, a test with its consequence is written as a block (`ifz d` ... `end`) and a comparison with its jump as one statement (`jeq c 10 n1`). `tools/fuse.py` made that change mechanically from the version with `eq`/`jnz` pairs: it fuses a pair only when the result of the comparison is not read on any path afterwards, turns a forward jump to a label that nothing else uses into a block when the region is short and nests, and leaves the state labels alone. It removed 138 lines and about 9% of the tokens.

## What the translation had to match

- Stage0 finds a decimal overflow in the carry flag after `mul` and `add`. AIL has no flags, so `rdnum` compares before it multiplies: the value may not be above 0x1999999999999999 (2^64 / 10, rounded down), nor equal to it with a digit above 5.
- A negative syscall result is tested unsigned: a `read` result above the buffer size is an error, and a `write` result is good when `result - 1` is below the bytes left.
- The order of the checks in a routine decides which message a source with two faults gets, so it follows stage0 line by line.

## Tests

`tests/fuzz.sh` and `tests/bytes.sh` extend the comparison to random sources and to bytes computed without a compiler. `tests/stage1.sh` gives every test source and every example to both compilers and requires the same stdout, stderr and exit status, then compares `build/ailc1` with `build/ailc2`. `tests/run.sh` and `tests/io.sh` take the compiler from the environment variable `AILC`, and `make test` runs them once with each compiler, naming it in both runs so that an `AILC` in the environment of `make` cannot replace stage0. All three scripts kill a compiler that runs for more than 10 seconds and fail the test.

## Friction found

Writing stage1 did not need any change to the language, but these cost the most and are the candidates for the next extensions:

- **No constant data.** The tables were 131 lines of decimal numbers that no one could read, written into a buffer at start. `data` replaced them, and with them the offsets into that buffer.
- **Sixteen buffers.** Every global scalar wanted a buffer of its own, because a buffer name was the only global name; the limit forced most of them into one buffer behind two accessors. `var` replaced both, and the limit is gone.
- **No 32-bit store.** Appending four bytes cleared the four after them, and patching a displacement meant loading eight bytes, replacing half and storing them back. `store4` does both directly.
- **Six variables** were enough everywhere, at the price of some reloading in `eop` and at the top level. A scope has 64 now, and `alloc` is the first function of stage1 that uses more than six.

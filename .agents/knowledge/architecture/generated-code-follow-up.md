---
title: Generated code after the algorithm measurements
last-verified: 2026-11-21
sources: [conversation 2026-11-20, commits 14c5275 9f3c3c6 25a5d37 f534077 2ba9ed2 91d8f7b, docs/TODO.md "Performance follow-up", docs/performance.md, compiler/expr.aw, compiler/emit.aw, tools/par.aw]
status: current
---
# Generated code after the algorithm measurements

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aw`,
> `tools/par.aw`, `tools/tokens.aw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aw`, `tools/lib/fmt.aw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aw` there.

**Summary.** Three changes to the compiler brought the kernels of the six algorithm programs
from 1.753 to 1.257 times the time of C (geometric mean of 48 kernel times): a scaled index
in the memory operand, registers given to the variables that loops mention most, and a
`while` on two comparisons as two jumps. A fourth, calls of short functions compiled in
place, and a probe in words brought `hashtab` from 1.61 to 1.24. A kernel's time on a
thousand elements moves by a fifth with the place of its code, so builds are compared over
several places.

## Facts
- AIL against C after each step: 1.753, 1.639 (scaled index), 1.325 (registers by weight),
  1.257 (two jumps). By program at the end: `bsearch` 0.97, `mergesort` 1.06, `heapsort` 1.14,
  `quicksort` 1.21, `graph` 1.34, `hashtab` 1.61. The five CPU-bound programs stay at 1.04:
  they are top-level code, which none of the three touches.
- **Scaled index** (`xaddr`, `xms`, `emodm` in `compiler/expr.aw`): a number added or
  subtracted last and then an index added last are both taken into the operand; the index is a
  variable with a register, alone or times 2, 4, 8 or shifted left by 1 to 3. `i*3`, `i*16`
  and a variable that lives in memory are computed as before.
- **Registers by weight** (`vment` in `compiler/names.aw`, `alloc` in `compiler/emit.aw`,
  buffers `vms`, `vwt`, `vdone`): pass 1 notes every mention; a mention weighs 8 to the
  number of loops around it, at most 8 loops; variables are placed heaviest first, each in
  the first register or slot where no placed variable overlaps its range. Above fifty
  million pairs of a mention and a loop the loops are not looked at.
- **Two jumps** (`xjcond`, `xsc`; `blktop`; `wclose`): only a `while` whose value is exactly
  two comparisons joined by `&` with no `/` or `%`. The head's first jump is kept in the 4
  bytes at 16 of the `blks` entry as a distance from the other `rel32`.
- `hashtab` with `place` written in line by hand: faster in 11 of 12 kernel times, up to 47%,
  for 102 bytes more code. Before registers by weight the same rewriting was up to 30% slower.
- `build/tools/par --grid --runs 3`: tasks of 30 microseconds to 3 milliseconds gain alike at
  every number of threads (10 to 11 times at 20); one task a thread loses a sixth to a
  quarter at 14 and 20 threads; 3 microseconds a task loses most of the gain at 20 threads;
  work bound by memory gains 2.3 to 2.5 times at 4 threads and 3 at 20. The pool was left.

- **Calls in place** (`inlchk`, `inlopen`, `inlclose` in `compiler/emit.aw`; `finl`, `vlo`,
  `vhi`, `vinl`, `valias`, `ilpos`): a `call` in a function, of a function before it with at
  most `inlsz` (160) bytes of code, at most six parameters, no `local`, `tail` or task, no
  call but `callp` and no global name but a `const`, is its body read again from the source.
  A parameter that is only read, given a variable by itself, is that variable. Variable
  numbers are used again after a body; a function with such a call is not itself compiled in
  place.
- **Code placement:** `heapsort` on 1000 words takes 15.5 to 23.8 ms as its unchanged code is
  moved by 0 to 38 bytes, with a period of 32; `bsearch` at 1000 moves between 38 and 69 ms.
  Rows of a million elements move by 2 to 5%. The loss of `bsearch` noted with registers by
  weight was of this kind.
- Over eight placements: calls in place give `hashtab` 5 to 36% less time, `bsearch` nothing,
  and `heapsort` with `sift` forced in place 7% more at a million (eight variables for six
  registers), which is why the limit stays under the 165 bytes of `sift`.
- `hashtab` probes with an index in words (`t+h*8`, step 2, twice the mask, hash shifted by
  31): 5 to 12% less on a million random keys, 8 tokens more. The random misses at 1000 keys
  are 21% slower with any change to that loop, the old one respelled included.

- Since 2026-11-21 a stack slot has the shortest displacement (none for `[rsp]`, one byte
  below 128; `frame` an `imm8`), and a slot just stored is not loaded again at the same
  output position (`slotp`, `slotr`, `slotpos` in `emem`, forgotten where `xflg` is). A
  function that needs a slot itself is no longer fit for a call in place (`fnslots` at `e1`),
  which keeps `sortsift` out whatever its size: with the short displacements it would have
  come under `inlsz`. The compiler went from 49042 to 48210 bytes, the algorithm programs
  lost a seventh of theirs. Kernel times over C, before and after, one build each:
  `heapsort` 1.195 and 1.128, `mergesort` 1.040 and 0.995, `hashtab` 1.171 and 1.160,
  `quicksort`, `graph` and `isort` unchanged, `bsearch` 0.941 and 1.109: its inner loop
  (`searchlower` in place) has no slot and is the same instructions, moved across the end
  of a 64-byte line (0x16ee to 0x171b), which is the open item on placement.

- `collatz` (2026-11-21): `if x%2` is `test r12b, 1` (a mask or a remainder by a power of two
  as a condition is tested, not computed, in `xjcond`) and `x=x*3+1` one `lea` (`xmuli`:
  times 3, 5, 9, with the number of the next `+` or `-` as displacement, `xgskip`). Over
  eight placements AIL / C is 1.055 to 1.209, median 1.106, where it was 1.075 to 1.219,
  median 1.121: the change is 2%, the place of the code 14%. Folding the `if`/`else` into
  one round as gcc does needs a view across statements and was decided against (user,
  2026-11-21: bounded parts, then measure); the item is closed at that.

- Since 2026-11-21 the first line of a loop starts at a multiple of 64 in the file (`pad`,
  `lalign`; `nops` in `compiler/tables.aw`): behind the head of a `while`, and in pass 2
  before a label a jump of pass 1 went back to (`lback`). Over eight placements the most is
  0.3 to 2.6% above the least where it was 3.7 to 37.9% (`bsearch` 0.802 to 1.106 became
  0.881 to 0.888, `heapsort` median 1.129 became 1.044). 16 and 32 were not enough for
  `collatz`; padding function entries too changed nothing and was left out. `collatz` and
  `quicksort` are steady at a slightly worse median (1.124 for 1.104). `fnpad` keeps the
  padding out of `inlsz`. Not padded: labels at top level and in bodies compiled in place.
- `build/tools/perf --places <name>` makes that table: eight builds by `build/ailc` with 1
  to 29 bytes of `data` in front. It replaces the script by hand.

- Since 2026-11-21 a function that calls, or names a `buf`, `data` or `var`, is fit for a
  call in place: `finl` (48 bytes) notes what its body adds to `calls`, `refs` and `chks`,
  and `inlchk` takes them from room the tables have for bodies behind the room of the
  source's lines (`ilroom`, 1048576 entries of `calls`; `tests/bytes.sh` computes the file
  of 600000 calls of a body with four calls: 262144 in place). The first form compared with
  the capacity of the whole table, so lines read after a body could pass its end: found by
  the review of PR #10, as was a body's label taking the padding of a later label of the
  function (`lback`), and a `use` path ending in a backslash, which `fuse` and the check
  of the grammar took for an open string. The
  compiler compiles itself 6% faster (the same source built by the compiler before and
  after), `heapsort` 2% and `ndmatmul` 1%; the other programs do not move. It is 63207
  bytes for 51175, and reads more bodies, so the gain is in the code, not in bytes.

- Since 2026-11-21 bodies are compiled in bodies, four deep (`ildp`, `ilstk`, `ilpush`,
  `ilpop`). The rules that keep every reading of a body deciding alike or more carefully:
  in a body only functions before the body's own (`ilfn`); `finl` holds `vhi`; one `calls`
  entry more per call in place (`ilcnt`). No benchmark program changed a byte; the tools
  did: `tokens` 18.8 to 18.2 ms, `infix` on `compiler/expr.aw` 5.6 to 5.4, `randvars dump`
  of 300 programs 27.0 to 24.9, and `perf` 50086 bytes for 37862. The compiler compiles
  itself in the same time and is 66343 bytes for 63207.
- Calls in place that are left out, by decision (user, 2026-11-21: bounded parts): calls
  at the top level, which has one pass, no weights and no place that is used again, so a
  body's variables would take registers from the program's or live in cells; functions
  with more variables at once than registers (`fnslots`), which would need live ranges
  split; functions that declare a `buf` or `data`, with a `local`, a `tail`, more than six
  parameters, or tasks.

## Why
- **Only bodies without calls and global names in place:** `calls`, `refs` and `chks` are
  sized from the source limit for a body read once; `labs`, `fixs`, `blks` and the hash are
  cut back after each body, so those cannot overflow.
- **Mentions of a body count at the call:** `alloc` orders by source position, and the body
  stands elsewhere in the source; one position after the values and before the next line
  keeps every range right without a second order.
- **Weight instead of order of definition:** the first six variables of a function are its
  parameters, which a loop reads once a round, while what it reads and writes most is defined
  inside it. This one change was worth more than the other two together.
- **No mention may be dropped:** a statement and the expression that says the same must give
  the same bytes (`tools/randvars.aw` compares them). A first version dropped mentions that
  were out of source order, which made the two spellings weigh differently.
- **Only `&` of two comparisons, only in `while`:** `&` is bitwise, so two jumps are the same
  as the value only when both sides are 1 or 0; a comparison neither traps nor assigns, so
  leaving the second out cannot be seen; and the layout was measured on loops only.
- **Tests before the loop and at its end**, not both at the head: never slower in the eight
  inputs of `mergesort`, and the shape a `while` on one comparison already has.
- **The pool unchanged:** within the sizes of task that are worth having its cost cannot be
  measured; the losses come from tasks too small or too few.

## How to apply
- To compare two compilers or two forms of a kernel, run `build/tools/perf --places <name>`
  with each (eight builds behind 1, 5, ... 29 bytes of `data`) and compare the medians; since
  loops are aligned one build each is within a few percent, before that it was not.
- After touching the code for calls in place, compare the output of random programs with
  calls against a compiler from before the change, besides `make test` and `randvars`; no
  tool in the repository generates calls.
- After a change to `alloc` or to how mentions are noted, run `make test` and
  `build/tools/randvars build/ailc 2000 1`, `... 2000 2 top`, `... 2000 3 async`.
- A new or changed form of a memory operand needs its case in `tests/insn.cases`; take the
  bytes from `tests/insn.sh hex`. A displacement to a `buf` in a case changes when the code
  before it changes length.
- To try a lowering before writing it: write the loop with labels and jumps in a copy of the
  example, compile it over `build/<name>`, run `build/tools/perf <name>`, and put the
  original back. `perf` checks the output against C before it times.
- Do not run anything heavy while `perf` or `par` measures; compare runs taken one after the
  other, since the C times move by a few percent between runs.

## Open items
- None. The loss of `bsearch` at a thousand elements noted here on 2026-11-20 (22 to 24%
  with registers by weight) was the place of its loop: with loops aligned it is 0.881 to
  0.888 of C at eight places.

## Related
- [Algorithm benchmarks and collections](algorithms-and-collections.md)
- [Expression syntax](expression-syntax.md)
- [Tools in AIL](tools-in-ail.md)

---
title: Generated code after the algorithm measurements
last-verified: 2026-11-20
sources: [conversation 2026-11-20, commits 14c5275 9f3c3c6 25a5d37 f534077 2ba9ed2 91d8f7b, docs/TODO.md "Performance follow-up", docs/performance.md, compiler/expr.aw, compiler/emit.aw, tools/par.aw]
status: current
---
# Generated code after the algorithm measurements

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
- To compare two compilers or two forms of a kernel, build each with 1, 5, 9, ... 29 bytes of
  `data` before the first function, run all in turn pinned to one CPU, and compare the
  medians over the eight; one build each is not a comparison at a thousand elements.
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
- 2026-11-20: inline small functions at their calls (item 5 of the follow-up in
  `docs/TODO.md`).
- 2026-11-20: `bsearch` at a thousand elements is 22 to 24% slower with registers by weight
  than with scaled indexes alone (0.92 of C); cause unknown.
- 2026-11-20: a stack slot is addressed with a 4-byte displacement, and a value just stored
  to a slot is loaded again by the next line.

## Related
- [Algorithm benchmarks and collections](algorithms-and-collections.md)
- [Expression syntax](expression-syntax.md)
- [Tools in AIL](tools-in-ail.md)

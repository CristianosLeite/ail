---
title: Review fixes of 2026-11-20
last-verified: 2026-11-20
sources: [PR #4, PR #5, REVIEW.md of 2026-11-20, conversation 2026-11-20, compiler/ailc.aw, compiler/emit.aw, compiler/names.aw]
status: current
---
# Review fixes of 2026-11-20

**Summary.** Decisions in the compiler that came out of the reviews of the async work: `tail`
in a function with a `local`, the result count of a function that returns through `tail`, the
names of a `while` value read at the end of its loop, and the limit of locals. The runtime and
tool fixes of the same reviews are on the pages of those subjects.

## Facts
- **`tail` with a `local`:** in a function that has a `local`, `tail` is a call followed by
  the return, so the frame stays until the callee has returned. Such a function tailing to
  itself grows the stack.
- **Results of `tail`:** a function with a `tail` and no `ret` has the result count of its
  target. Its count in `funs` is 0 until `fin`, where `tailres` passes known counts back along
  the tails (`tails`, `tailq`). A `tail` whose target has another count than the function it
  stands in is `wrong result count`, named after the target; this covers a `ret` beside a
  `tail`. Functions that only tail to each other and reach no `ret` never return and fit any
  count.
- `tailres` is linear: every tail is in the list of its target and a function passes its count
  on once. A chain of 150000 functions in the worst order compiles in a third of a second
  (`tests/tail_results_far`).
- **`while` value:** the value is read a second time at `end`. The `blks` entry keeps `nv` of
  the head, and while `wend` is set `lvar` looks at that many variables only, so a variable
  defined in the loop does not hide the global name the head named.
- **Locals:** at most 0x7ffff000 bytes in one function (`buffers too big` above).
- For each of these the output of the compiler for every source that existed before was the
  same bytes; no source of the repository broke the new `tail` rule.

## Why
- **Call plus return instead of forbidding `tail` with a `local`:** the callee may hold the
  address of the local through a value, a variable or memory, which the compiler cannot
  follow; the program means the same and only the loop is lost.
- **Backward propagation, not "first tail":** a loop written with `tail` has a tail to itself
  before the one that leaves it, so the first target says nothing; and passes over all tails
  until nothing changes are quadratic for a chain in the wrong order, which an 8 MiB source
  can hold.
- **A reachable `end` imposes no count** on a function with a `tail`, as it imposes none
  beside a `ret` with several values.
- **A limit by variable number for `while`:** variables are numbered in order of definition in
  both passes, so "those there at the head" needs four bytes in the entry and no second table.

## How to apply
- A statement that returns from a function must record what `fin` needs to check its count;
  `calls` entries of a tail carry the function index with bit 31 set.
- Anything read twice from the source must resolve names as at the first reading.
- After a compiler change compare its output with the compiler before on every `.aw` of the
  repository, then `make fuzz N=20000` and `randvars` in its three modes.
- A reproduction from a review becomes a test that fails on the code before the fix.

## Related
- [Async runtime](async-runtime.md)
- [Tools in AIL](tools-in-ail.md)
- [Language extensions](language-extensions.md)

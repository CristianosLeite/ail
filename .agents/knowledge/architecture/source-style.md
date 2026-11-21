---
title: Source style and the formatter
last-verified: 2026-11-21
sources: [conversation 2026-11-20, docs/language.md, tools/indent.aw, tests/indent.sh, editors/vscode/, docs/tokens.md]
status: current
---
# Source style and the formatter

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aw`,
> `tools/par.aw`, `tools/tokens.aw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aw`, `tools/lib/fmt.aw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aw` there.

**Summary.** Sources are indented with one tab for each block, set and checked by
`build/tools/indent`; the VS Code extension in `editors/vscode/` formats through the same tool.
Indentation costs 2% in tokens and nothing in the compiled program.

## Facts
- Tabs, not spaces, because of the count on the ten examples without comments: 970 tokens
  unindented, 990 with a tab a level, 1024 with two or with four spaces. All compile to the
  same bytes.
- The formatter changes only the spaces and tabs at the start of a line. That is what makes it
  safe to run on everything: after each group of sources was indented (examples, compiler,
  library, tools and bench, tests) every executable was compared with the one before, and for
  the tests also the compiler's message and status. `build/ailc` did not change by a byte.
- A word opens or closes a block only when a blank, a comment or the end of the line follows
  it, which is the compiler's rule for an assignment seen the other way round: `if=1` sets a
  variable. A line that starts inside a string that spans lines is not touched.
- The tool does not validate: an `end` too many closes nothing and the rest is indented as far
  as it goes. A formatter that refused a wrong program would be of no use in an editor.
- A comment-only line gets the depth of its block (the user's choice). The 23 comments of
  `compiler/ailc.aw` that were aligned with spaces under the comment of a `buf` line went to
  column one.
- Scope chosen by the user: every source, tests included. Not indented: the tests of the
  separators (`tests/indent/skip`) and the fixtures under `tests/infix/`, `tests/fuse/`,
  `tests/randvars/`, `tests/tokens/` and `tests/indent/`, which tools must reproduce byte for
  byte. `tests/indent.sh` runs `--check` on the rest in `make test`.
- `fuse` and `infix` write their results indented since 2026-11-21: the walk of `indent` is
  `dtindent` in `tools/lib/dent.aw`, and both pass their output through it. Copying the
  blanks of the source would not do, since a jump that becomes a block puts untouched lines a
  level deeper. `fuse` matched nothing in an indented function before (its patterns began at
  column one) and now reads a line without its blanks. The expected files are the old ones
  run through `indent` (whitespace only), so the Python oracle still holds.
- A `use` path has no escapes: `indent` took `use "a\\"` for an open string and left the rest
  of the file alone. `dtindent` and `extension.js` now end the string at a `use` line.
- The published token figures are those of the indented sources: corpus 990 (was 970), 11%
  below C and 17% below Rust, `collatz` two tokens above its C program; echo server 259.
- The extension is plain JavaScript without a build step or dependency (the user's choice). It
  repeats the line rules of the tool in `extension.js` for folding; they were compared with the
  tool on every source of the repository with node, which `make test` does not need.
- The grammar is checked since 2026-11-21 by `editors/vscode/check.sh` (`test/check.js`), run
  by hand: VS Code's own runtime (`ELECTRON_RUN_AS_NODE=1 /usr/share/code/code`; the machine
  has no `node`) with its bundled `vscode-textmate` and `vscode-oniguruma` colours all 1232
  sources, and every statement of `compiler/tables.aw` must be a keyword, an assigned name a
  variable, comments and strings what they are, the folds the blocks of the formatter. The
  first run found 579 lines wrong: `sys` before a number (572) and `call`, `tail`, `jmp`
  without a name were not coloured, the string of a `use` without its quote ran over the next
  lines, and an `else` of no block folded. All fixed; it reports 0.
- The copy installed in `~/.vscode/extensions/ail.ail-0.1.0` on 2026-11-20 was from a vsix
  older than the grammar; it is now a symlink to `editors/vscode`, as the README says. The
  user looked at it in the editor on 2026-11-21 and found it working: colours, folding and
  formatting of `.aw` files (the extension the sources have had since they stopped being
  `.ai`; no file of `editors/vscode/` names `.ai`).

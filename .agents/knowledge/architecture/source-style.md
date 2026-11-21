---
title: Source style and the formatter
last-verified: 2026-11-20
sources: [conversation 2026-11-20, docs/language.md, tools/indent.aw, tests/indent.sh, editors/vscode/, docs/tokens.md]
status: current
---
# Source style and the formatter

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
- `fuse` and `infix` still write their lines at column one, since their expected files are what
  the Python scripts wrote; `indent` runs after them. Preserving indentation in them is open.
- The published token figures are those of the indented sources: corpus 990 (was 970), 11%
  below C and 17% below Rust, `collatz` two tokens above its C program; echo server 259.
- The extension is plain JavaScript without a build step or dependency (the user's choice). It
  repeats the line rules of the tool in `extension.js` for folding; they were compared with the
  tool on every source of the repository with node, which `make test` does not need. It was not
  loaded into VS Code when written, so the grammar is unverified in the editor.

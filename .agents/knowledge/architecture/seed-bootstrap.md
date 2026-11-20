---
title: Seed bootstrap
last-verified: 2026-11-20
sources: [conversation 2026-11-20, REDESIGN.md, seed/MANIFEST, docs/stage1.md]
status: current
---
# Seed bootstrap

**Summary.** The compiler written in AIL is to become the only compiler, built from a released
copy of itself (a seed) instead of from `stage0/ailc.s`. `seed/MANIFEST` pins the seed by
version, source revision and SHA-256; the file itself is a GitHub release asset.

## Facts
- Seed 1 is `build/ailc1` of commit 489efbf (2026-11-20): 30796 bytes, SHA-256 `a3784aec...`,
  the same file whether stage0 or stage1 builds it. Release `seed-1`, asset `ailc-1`.
- The manifest keeps one line per seed, the last one pinned; a local copy is `seed/ailc-<n>`,
  ignored by git.
- The repository had no remote, tag or CI before this; the remote was created for the release.
- The build is `ailc0` (seed, by `tools/seed.sh`) → `ailc1` → `ailc` → `ailc2`, and the fixed
  point is `ailc` = `ailc2`. Stage0 is `build/stage0` and only the tests use it.

- `stage1/tables.ai` is its own source since 2026-11-20 (`tools/tables.sh` and `make tables` are
  gone). `tests/tables.sh` checks its form and `tests/insn.sh` its bytes against hex that GNU
  `as` wrote; 90 cases, one or more for every row and table.

## Why
- **A GitHub release, not a binary in the repository (chosen by the user on 2026-11-20):** the
  alternative offered was to commit the seed under `seed/`, which builds offline from a clean
  checkout but puts every seed in the history.
- **The repository is private (chosen by the user):** a release asset of a private repository
  cannot be fetched with plain `curl`; it needs `gh release download` or a token, or the local
  copy.
- **Three generations, not two:** once the compiler writes other code than the seed did, the
  compiler built by the seed and the one built by itself differ in bytes, though not in what
  they do. Comparing the seed's output with anything would then fail for no fault.
- **The revision in the manifest is the commit of the source, not of the manifest:** the
  manifest can only be written after the seed exists, so it is always one commit later.

- **Expected bytes from an assembler, kept as hex:** the generator made a slip in a row
  impossible; without stage0 nothing would notice one except a program that happens to run the
  row. The hex is written once by `as` and compared without it, so `make test` gains no
  dependency. Six mutations of the table each failed the instruction test, eight the form test.

## How to apply
- A new or changed row of `stage1/tables.ai` gets a case in `tests/insn.cases`: write the
  instructions, take the hex from `tests/insn.sh hex`, run `tests/insn.sh asm`.
- `as` picks the short form of a jump, a displacement or an immediate where the compiler writes
  the long one: `{disp32}` forces the first two, and a four-byte immediate that fits one byte
  has to be given as `.byte` and `.long`.
- A seed is released only from a build that has reached its fixed point, and publishing one is
  asked of the user each time: it is the one step that leaves the machine.
- The compiler source may use only what the pinned seed understands. New syntax goes into the
  compiler first, written in the old syntax; then a seed is released and pinned; only then may
  the source use it.
- Never rewrite a line of the manifest: an older revision is built with the seed of its time.

## Related
- [Stage1 self-hosting](stage1-self-hosting.md)
- [Open items](../status/open-items.md)

---
title: Seed bootstrap
last-verified: 2026-11-21
sources: [conversation 2026-11-20, docs/REDESIGN.md, seed/MANIFEST, docs/compiler.md]
status: current
---
# Seed bootstrap

**Summary.** The compiler written in AIL is the only compiler, built from a released
copy of itself (a seed) instead of from `stage0/ailc.s`. `seed/MANIFEST` pins the seed by
version, source revision and SHA-256; the file itself is a GitHub release asset.

## Facts
- Seed 1 is `build/ailc1` of commit 489efbf (2026-11-20): 30796 bytes, SHA-256 `a3784aec...`,
  the same file whether stage0 or stage1 builds it. Release `seed-1`, asset `ailc-1`.
- Seed 2 is `build/ailc` of commit c910430 (2026-11-20): 41784 bytes, SHA-256 `c2cb658c...`, the
  fixed point of the build from seed 1, released as `seed-2` (asset `ailc-2`) after the user
  confirmed the push of `backlog` and the release. It is the first seed that understands
  expressions, `x=e` and `while`; with it pinned, a clean fetch gives three generations that are
  one file.
- Seed 3 is `build/ailc` of commit 9cc44dd (2026-11-20), the merge of the rename to `.aw`: 42322
  bytes, SHA-256 `346a9f77...`, the fixed point of the build from seed 2, released as `seed-3`
  (asset `ailc-3`) when the user asked for a new seed. It adds `spawn`, `join`, async functions
  and `await` to what a seed understands, and is the first built from `compiler/` and `.aw`, the extension until 2026-11-21.
- Seed 4 is `build/ailc` of commit 8314e2d (2026-11-21), the merge that moved the benchmarks
  and the editor extensions to repositories of their own: 67495 bytes, SHA-256 `0361ccfb...`,
  the fixed point of the build from seed 3, released as `seed-4` (asset `ailc-4`) when the user
  asked for a new seed. It adds `padd`, `psub`, `pmul`, `pdiv`, `pmadd`, `fsum` and `fdot` to
  what a seed understands and writes the code of the current compiler (seed 3 built an
  `ailc1` of other bytes than `ailc`). It was built in a clean worktree of that commit, where
  `make test` passed (2614 checks) and `ailc`, `ailc2` and `ailc` compiled by itself once
  more were one file.
- The manifest keeps one line per seed, the last one pinned; a local copy is `seed/ailc-<n>`,
  ignored by git.
- The repository had no remote, tag or CI before this; the remote was created for the release.
- The build is `ailc0` (seed, by `tools/seed.sh`) → `ailc1` → `ailc` → `ailc2`, and the fixed
  point is `ailc` = `ailc2`.
- Stage0 was removed on 2026-11-20, after a clean worktree without it, with an empty `build/`
  and no local seed, fetched the seed, built and passed `make test` (1635 checks). Its last
  revision is the parent of the commit that removes it; `docs/compiler.md` and `AGENTS.md` now
  describe the compiler in AIL under its own names, and `docs/stage1.md` was merged into the
  former.
- The directory of the compiler was renamed from `stage1/` to `compiler/` on 2026-11-20, after
  seed 2. The pages of this base name the files by the new path; the revisions that the seeds
  of `seed/MANIFEST` were built from have them under `stage1/`.

- `compiler/tables.aiw` is its own source since 2026-11-20 (`tools/tables.sh` and `make tables` are
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
- A new or changed row of `compiler/tables.aiw` gets a case in `tests/insn.cases`: write the
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

---
title: Source extension
last-verified: 2026-11-21
sources: [conversation 2026-11-21, github-linguist/linguist CONTRIBUTING.md and languages.yml of 2026-11-21, GitHub code search of 2026-11-21]
status: current
---
# Source extension

**Summary.** Sources are `.aiw` since 2026-11-21. They were `.ai` until 2026-11-20 and `.aw` for
a day; `.aw` is PHP's in GitHub Linguist, so GitHub counted and coloured the sources as PHP.
Linguist does not know AIL and will not take it until other people's repositories use it.

## Facts
- `languages.yml` of Linguist lists `.aw` under PHP. With it GitHub reported this repository as
  94% PHP and ail-bench as 55% PHP, and coloured every source as PHP.
- `.aiw` is in no entry of `languages.yml`; the code search of GitHub found 37 files with it, in
  unrelated repositories, none of them a language.
- The other names looked at: `.ail` (free in Linguist, 6624 files, the first hundred results
  nearly all of another language for AI, `sunholo-data/ailang`), `.ailang` (free, 1572 files,
  again another language of that name), `.als` (Alloy in Linguist), `.awx` (23 files, Ansible
  AWX), `.ailc` (none, but the name of the compiler), `.ai` (62976 files; dropped on 2026-11-20).
  The figures of who uses a name are from the first hundred results of a search.
- Linguist takes an extension with at least 2000 files indexed in the last year, forks left
  out, spread over unrelated users and repositories, and filters out the owner of the language;
  its `CONTRIBUTING.md` says that pull requests for very new or hobby languages are closed.
- The rename touched no byte of the compiler: `build/ailc` built from the `.aiw` sources is the
  file of seed 4, which stayed pinned. The executable holds no extension; a path is only what
  a `use` line says.
- The three repositories were renamed together (this one, ail-bench, ail-extensions), each with
  its `ail.pin` moved to the revision of the rename here.

## Why
- **A free name instead of a `.gitattributes` line:** `linguist-language` can only name a
  language Linguist knows, so the sources could have been called Assembly or left out of the
  statistics, never AIL; and a later pull request to Linguist for `.aw` would have needed a
  heuristic against PHP and two samples of each language.
- **Not `.ail`, which is the name of the language:** another language holds it in practice, and
  whichever reaches the threshold of Linguist first gets it.
- **No new seed:** a seed built after the rename would have been the same file as seed 4 under
  another number (chosen by the user).

## How to apply
- Sentences about the time before the rename keep `.aw` (the seeds of `seed/MANIFEST`, what the
  user saw in the editor); every path is named as it is now.
- Until Linguist knows `.aiw`, GitHub shows the sources as plain text and leaves them out of
  the language statistics.
- A pull request to Linguist, when the usage is there: an entry in `languages.yml`,
  `script/add-grammar` with the repository ail-extensions (scope `source.ail`, MIT), samples
  from `examples/`, `lib/` and `compiler/`, and `script/update-ids`.

## Related
- [Seed bootstrap](seed-bootstrap.md)
- [Source style and the formatter](source-style.md)

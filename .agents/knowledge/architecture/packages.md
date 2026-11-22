---
title: Packages, the manifest and the ail command
last-verified: 2026-11-22
sources: [conversation 2026-11-22, compiler/pkg.aiw, compiler/ailc.aiw, tests/pkg.sh, docs/TODO.md]
status: current
---
# Packages, the manifest and the ail command

**Summary.** AIL and the projects built on it get one way to say a name, a
version and dependencies, and one command for the work on a project. The
first part is in the compiler: a `use` can name a file of another package.
The rest is the open section of `docs/TODO.md`.

## Decisions
- **One mechanism of versions for AIL and everything derived from it**, as
  `Cargo.toml` is for Rust (user, 2026-11-22). Before it AIL had no
  version, only the numbers of its seeds, and ail-bench, ail-extensions
  and aildb each named a revision of AIL in a file `ail.pin`.
- **The manifest is lines of a key and its values** (user, 2026-11-22), as
  `ail.pin` and `seed/MANIFEST` are written: read by AIL and by a shell
  with no parser. Rejected: TOML, which needs one.
- **AIL has a semantic version apart from the number of the seed** (user,
  2026-11-22). The seed number counts released compilers the source is
  built from; the version is what a manifest asks for.
- **The manifest has the version and the dependencies, and a command
  does the rest** (user, 2026-11-22): new project, add and remove a
  dependency, build, run, test; "as simple as npm and cargo".
- **A file of a dependency is named `use "name:path"`** (user,
  2026-11-22). Rejected: the first part of the path as the name
  (`use "aildb/src/..."`), which a directory of the program would hide or
  be hidden by; a directory `deps/` in the path, which puts the layout on
  disk into the language.
- **A dependency is a git repository and a version, the tag
  `v<version>`, and a lock file has the revision** (user, 2026-11-22). A
  path in place of the address is for work in progress. Rejected: the
  revision alone, as `ail.pin` had it, which says no version; a registry,
  a service to keep.
- **One installed toolchain** (user, 2026-11-22): `make install` and a
  file a release put the command, the compiler and the library in one
  place, and the command refuses a manifest that asks for a newer AIL.
  Rejected for now: AIL fetched for each project, a manager of several
  versions.

## How the compiler does it (agent, 2026-11-22; for the user to review)
- The compiler learns the packages from its arguments, `name=directory`,
  the first it ever took; without one it does what it did, so every test
  and every repository that links `lib` goes on unchanged. It reads no
  manifest: the command reads that and names the directories. Rejected:
  the compiler reading `ail.pkg`, which puts the format and the place of
  the fetched packages into the compiler.
- A path without a name is relative to the package of the file that has
  the `use`, not to the directory the compiler runs in. This is what lets
  a package be used unchanged: its own `use "src/lib/text.aiw"` lines mean
  the same when it is compiled by itself.
- `lib/` is the package `ail` in every package. A program has the library
  once, the one of the compiler that builds it, as a program of Rust has
  one `std`; two packages that each brought a copy would define every
  function twice. The price: no package has a top-level `lib/`.
- "Compiled once" compares the package and the path as written, in a
  table beside `uses` (`upkg`); the paths are not brought to one form, as
  before.
- A path that starts with `/` is in no package, so a source in a
  temporary directory can be compiled against packages.
- The source of the compiler uses nothing new, so the pinned seed builds
  it and no seed was cut.

## Not checked
- More than 256 packages and a path of package and file above 4095 bytes
  are refused in the code and have no test.

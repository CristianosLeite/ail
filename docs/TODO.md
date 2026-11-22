# TODO

This file records current limits and the work needed to lift them. Favor
changes that reduce the token cost of real AIL programs. Keep the compiler's
fixed point and use in its source only what the pinned seed understands.
See the [roadmap](roadmap.md) for project history.

An item is a checkbox under the section of its subject. When it is
completed it is moved to [BACKLOG.md](BACKLOG.md), which has every item
that was done, under the same section.

## Packages and the `ail` command

AIL and what is built on it (ail-bench, ail-extensions, aildb) are to
share one way to say what a project is called, which version it is and
what it needs, as `Cargo.toml` is for Rust, and one command that makes a
project, adds and removes its dependencies, builds, runs and tests it, as
simple as cargo and npm (user, 2026-11-22). Decided with it: a manifest of
lines of a key and its values; a semantic version of AIL apart from the
number of the seed; a dependency is a git repository and a version, the
tag `v<version>`, with a lock file that has the revision; one installed
toolchain, the command, the compiler and the library.

- [ ] The command `ail`: `new`, `init`, `build`, `run`, `clean`,
  `version`, `help`.
- [ ] `ail test`, the convention of `tests/run.sh`, and `ail fmt`.
- [ ] Dependencies: `ail add`, `remove`, `update`, the fetch into `deps/`,
  the lock, the dependencies of a dependency.
- [ ] `make install` and `make dist`, and the documents of the command.
- [ ] The repositories ail-bench and ail-extensions moved to `ail.pkg`
  (aildb has the step in its own TODO).
- [ ] Left for later: several installed toolchains, a registry of
  packages.

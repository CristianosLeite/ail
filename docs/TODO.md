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

- [ ] The repository ail-bench moved to `Ailfile`. ail-extensions is a
  package since its pull request 2 (2026-11-22), and aildb since the
  packages.
- [ ] Left for later: several installed toolchains, a registry of
  packages.

## Text formats and the network

`lib/std/num.aiw`, `lib/std/json.aiw`, `lib/net/http.aiw` and
`lib/net/httpd.aiw` are written, and the version 0.1.1 of AIL is the
first that has them ([BACKLOG.md](BACKLOG.md)).

- [ ] A double written as the shortest decimal that names it, for the
  writer of JSON.
- [ ] Left for later: a connection that is kept, TLS and names for the
  client; the server measured under many connections.

## Runtime

[RUNTIME.md](RUNTIME.md) moves what a program asks of its platform behind
a runtime, so that AIL runs on more than x86-64 Linux, at the speed of C
with the calls of the runtime counted. Decided with it (user,
2026-11-26): the runtime is one position-independent image that the
compiler copies into each executable and calls by entry, with no linker
and no object file; it is written in C first, built by `cc` in `make`,
and then in AIL; one pull request when all of it is done, and the
version 0.2.0 after it.

- [ ] Seed 7, which understands `rt`.
- [ ] The compiler through the runtime, with its fixed point.
- [ ] Services for files and directories, the clock, threads with
  waiting and waking, readiness and sockets, and processes, each with
  the library that needs it; no `sys` left in `lib/`, `cli/` and `tools/`.
- [ ] An image as a form of output, for a runtime written in AIL.
- [ ] The services in AIL one group at a time, tested against both.
- [ ] The C runtime removed, and seed 8.
- [ ] A second platform: the compiler split into shared and target
  files, a second backend and its runtime, the test suite there.
- [ ] Workloads for startup, I/O and allocation in ail-bench against C
  at `-O3`, measured before the runtime, with the C one and the AIL one.
- [ ] The gaps to C closed, each change measured first.
- [ ] Version 0.2.0.

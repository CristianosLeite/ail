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
2026-11-26): the runtime is part of each executable, put there by the
compiler, with no linker and no object file; it is written in C first,
built by `cc` in `make`, and then in AIL; one pull request when all of
it is done, and the version 0.2.0 after it. The first two phases are
done for x86-64 Linux ([BACKLOG.md](BACKLOG.md)): the runtime is AIL
source that the compiler compiles with every program
([runtime.md](runtime.md)), and the seeds 7 and 8 wait to be published.

- [ ] The command `ail` and the tools without `sys`. `cli/tool.aiw`
  starts a test in a group of processes of its own, with a watcher that
  kills the group when the command is gone, takes a lock on the
  directory of a package, goes into directories and back by a
  descriptor, and asks where its own executable is; `cli/ail.aiw`
  becomes the program it runs. Each wants a service that says what is
  meant and not how Linux does it: a program started in a group that
  ends with it, a lock of a directory, the directory of the process and
  of the executable, a program in place of the process.
- [ ] A second platform, and a third (user, 2026-11-26). First Windows
  on x86-64, run under Wine: the same instructions, another form of
  executable, another convention for calls, and no system calls, so
  that every service is the runtime's. Then Linux on aarch64, a second
  set of instructions, run under an emulator that is to be installed.
  For each: the compiler with a target, its runtime in `rt/`, a small
  program, then the test suite. Windows is done as far as Wine shows
  ([BACKLOG.md](BACKLOG.md)): its compiler, its fixed point, every
  service, 579 tests. Left there: what the tests of faults are to
  expect, the command `ail`, a run on Windows itself. Linux on aarch64
  is to do, and needs `qemu-user` and the assembler for aarch64
  installed first.
- [ ] The gaps to C closed, each change measured first. Known: every
  executable has all of the runtime, 11.7 KiB, where it could have the
  functions it reaches; a service compiled in place moves its values
  through the variables of its function; a division by a constant is a
  division where C multiplies (`allocs` lost 13% to that before its
  sizes were a mask).
- [ ] Version 0.2.0.

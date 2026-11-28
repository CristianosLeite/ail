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
([runtime.md](runtime.md)), and the version 0.2.0 is that state, with
the runtime of Windows as far as Wine shows it. The seed 8 is
published; the seed 7, which had the runtime in C, is not.

- [ ] What else a linker of Microsoft writes into an executable and
  the compiler for Windows does not: a time of linking, a sum of the
  file and a resource with its version. Microsoft Defender takes a
  program of the tests for malware now and then
  ([runtime.md](runtime.md)), and what the documents of Microsoft
  offer a developer is to submit the file that was taken and to sign
  what is released; nothing is to be tuned until a scan passes.
- [ ] A second platform, and a third (user, 2026-11-26). First Windows
  on x86-64, run under Wine: the same instructions, another form of
  executable, another convention for calls, and no system calls, so
  that every service is the runtime's. Then Linux on aarch64, a second
  set of instructions, run under an emulator that is to be installed.
  For each: the compiler with a target, its runtime in `rt/`, a small
  program, then the test suite. Windows is done as far as Wine shows
  ([BACKLOG.md](BACKLOG.md)): its compiler, its fixed point, every
  service, 579 tests, and on Windows 11 itself, where `tests/win.sh`
  passed with 607 tests on 2026-11-27 ([BACKLOG.md](BACKLOG.md)). Left
  there: what the tests of faults are to expect, the six services of
  2026-11-27 and the five of 2026-11-28 under Wine, and the command
  `ail`, which builds and tests a package for Windows from Linux
  since 2026-11-28 (`--target`, [cli.md](cli.md)) and which the
  compiler for Windows compiles now that it has no `sys`
  ([BACKLOG.md](BACKLOG.md)) but which still names paths with `/`,
  `/dev/null`, `sh` and flags of `open` that only Linux has. Linux on aarch64
  is to do. Its tools need no installation by root: `apt-get download
  qemu-user binutils-aarch64-linux-gnu` and `dpkg -x` into a directory
  give `qemu-aarch64` and `aarch64-linux-gnu-as`, which ran a program
  written by hand (2026-11-26). The work is a second code generator:
  the rows of the statement table, the encoders of `compiler/emit.aiw`
  and the instruction selection of `compiler/expr.aiw` are x86-64
  throughout, jumps and calls are four bytes of distance where aarch64
  has fields of an instruction word, and its system calls are others
  (no `open`, `fork` or `poll`). It starts with the split of the
  compiler into shared and target files, the x86-64 output unchanged
  by a byte, and a first backend may compile every statement by its
  row, as lines with a string are compiled now, before it selects
  instructions.
- [ ] The gaps to C closed, each change measured first. Known: every
  executable has all of the runtime, 17.8 KiB, where it could have the
  functions it reaches; a service compiled in place moves its values
  through the variables of its function; a division by a constant is a
  division where C multiplies (`allocs` lost 13% to that before its
  sizes were a mask).

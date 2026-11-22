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
- **The manifest is `Ailfile` and the lock `Ailfile.lock`** (user, 2026-11-22), names
  without an extension, as `Makefile` and `Gemfile` with `Gemfile.lock` are. They were
  `ail.pkg` and `ail.lock`, the agent's proposal, until the same day: `.pkg` is the
  installer package of macOS, which opens such a file in its Installer, and the
  package of other systems, so a tool that goes by the extension takes the manifest
  for something else. Rejected: `package.ail` with `ail.lock`, whose two names are not
  alike, and other short extensions, each of which is somebody's already.
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
  the compiler reading `Ailfile`, which puts the format and the place of
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

## The manifest and the lock (agent, 2026-11-22; for the user to review)
- The files are `Ailfile` and `Ailfile.lock`. The keys are `name`, `version`,
  `ail`, `bin`, `testbin` and `dep`; `docs/packages.md` has their rules.
- **A version is three numbers and nothing more.** No pre-release and no
  build part, which no project of AIL has needed. Each number is below
  2^21, so that a version is one 63-bit number and is compared as one.
- **A dependency names one exact version**, the tag `v<version>`, and the
  lock keeps the revision of that tag. Rejected: ranges (`^1.2`), which
  need a solver and make a build depend on what was published since.
- **The line `ail` is a lower bound within one first number.** AIL below
  1.0.0 may change in a way a program notices from one second number to
  the next; the rule does not say so, and a package that needs an exact
  AIL has no way to ask for it yet.
- **AIL is 0.1.0** as its first version: a proposal, since the number and
  the tag of a release are the user's.
- A manifest is changed as text (`mfdrop` and lines added), not written
  again from what was read, so the comments of its author stay.

## The command (agent, 2026-11-22; for the user to review)
- **The command is written in AIL**, `cli/`, with the libraries of
  `lib/std`, as the tools are; it is built by `make` and needs no seed of
  its own.
- **It finds AIL from its own place** (`/proc/self/exe`): `../lib/ail` in
  an installation, `..` in a checkout, and `AIL_HOME` before both. So a
  checkout works with no step of installation, which is how the tests
  run it.
- **Every build compiles every source.** No list of the files a source
  reads is kept, since the compiler takes milliseconds; a build that is
  wrong because a file was not seen to change cannot happen.
- **`build` prints nothing when it is done**, as the compiler does; what
  it has to say is an error.
- **`run` puts the program in the place of the command** (`execve`), so
  its status, its signals and its input and output are its own, and it
  starts in the directory the user is in, not at the top of the package.
- **`new` runs `git init` and does not mind if it fails**: a package is
  not required to be a repository.
- The statuses: 1 a source did not compile, 2 usage, 3 the manifest,
  4 files and AIL not found.
- **A test of a package is what a test of this repository is**:
  `tests/<name>.aiw` with `.out`, `.code` or `.err`, the 10 seconds, the
  directory of its own. `ail test` is `tests/run.sh` written in AIL, so
  that aildb and the others drop their copy of that script. The
  directory is named in `AIL_TMP`, where aildb had `AILDB_TMP`.
- **What a failed test printed is kept** in `build/tests/`, and stderr
  names the two files that differ; the command does not print a
  difference itself, which `diff` does.
- **`ail fmt` starts the formatter**, `tools/indent.aiw` as it is built,
  and does not have it compiled in: one program does the indenting.

## Dependencies (agent, 2026-11-22; for the user to review)
- **`ail add URL` takes the name from the manifest of the package**, not
  from the command line: the approved plan had `ail add NAME URL`, and
  the name would have had to repeat what the package calls itself. The
  clone is made first, as `deps/.new`, and given its name when the
  manifest is read.
- **A build asks nothing of a network** when `deps/` has each package at
  the revision of the lock: that is read from `.git/HEAD` of the clone,
  with no process started. A plan to check on each build that a tag
  still names the locked revision was dropped for this.
- **A missing line of the lock is written by the build**, from the tag,
  as cargo writes `Cargo.lock`: a manifest changed by hand needs no
  other command.
- **Only the lock of the package that is built counts.** The lock of a
  dependency was written for its own build.
- **One version of a package in a build, and no solver.** Two requirers
  of different versions are an error for the author to settle; with
  exact versions there is nothing to choose.
- **`update` writes the manifest**, which cargo's does not: there a
  manifest has a range and the lock the version, here the manifest has
  the version.
- **`add`, `remove` and `update` put the manifest and the lock back**
  when the packages cannot be found afterwards, so a refused command
  leaves a package that still builds.
- **git is started as a program** (`git ls-remote`, `clone`, `fetch`,
  `checkout`), with `--` before an address; an address that starts with
  `-` is refused in the manifest. Rejected: reading the protocol of git
  in AIL.
- A package may name files of a package it does not list, if another
  package of the build lists it; the compiler is given all of them.

## Installation (agent, 2026-11-22; for the user to review)
- **`bin/ail` and `lib/ail/`**: the command where a shell looks, and the
  compiler, the formatter, the manifest and the library where only the
  command looks. `ailc` is not in `bin/`: a user of packages does not
  call it, and one who does has the checkout.
- **The library is installed as sources**, since a `use` compiles a
  file; there is nothing to build ahead.
- **`make dist` is the file of a release**, with times and owners set to
  zero so that the same build gives the same file. Publishing it, with a
  tag `v<version>`, is the user's.
- The seed and its manifest are no part of an installation: they build
  the compiler, which is installed as it was built.

## After the review of the pull requests 17 to 24 (agent, 2026-11-22)
The automatic review of GitHub left 30 findings on the seven pull requests; each was
checked against the code and fixed in a commit of its own on the branch
`packages-review`, with a test where one could be written. What they decided:
- **"Not there" is one answer of the kernel, `ENOENT`, and no other.** A manifest, a
  lock, a file of a test or a directory that is there and cannot be read is an error,
  never the same as none: the search for a package does not go past it, a lock is not
  written again from the tags, a test does not pass on an expectation it never read.
- **A file the command writes is made anew or written whole.** The file a source is
  compiled into, the one git's words are kept in and the files of `ail init` are opened
  so that they are created or the open fails, never through a link; a manifest and a
  lock are written beside themselves and renamed.
- **Putting the manifest and the lock back is done where the command fails** (`fail`),
  so it holds for every failure after the first change, not for the one that was thought
  of.
- **A name from the command line is not a path**: a test name has no `/`, an address or
  a directory is one value of a manifest line.
- **`ail fmt` follows no link**, and stops at a directory it cannot read.
- **One command at a time in a package**, by an exclusive lock on its directory, taken
  when the package is found and held to the end of the command (first a lock of
  `ail test` alone, on `build/tests/.lock`; the second review found that two builds
  share the file a lock is written to). Rejected: a name of its own for each writer's
  file, which keeps two writers apart and not a reader from a half-made `deps/`.
  The executable of a test is `<name>.exe`, and the compiler of a test has its deadline.
  The lock is required (third review): a directory that may be entered and not read
  cannot be opened for `flock`, and the command then ends with status 4 and touches
  nothing. Rejected: a lock file inside such a package, a second mechanism and a file
  left in the sources for a mode nobody was seen to use. The directory of a dependency
  may still be one that is not listed.
- **Two paths of one directory are one package**, compared by what the kernel names the
  directory.
- **A package called `ail`** is built with the library as `ail` and without itself
  under that name.
- **The group of a test also ends when the command is killed**: a watcher process in
  the group reads a pipe that only the command writes to and kills the group at its
  end. AIL has no way to handle a signal in a program, so the command cannot clean up
  on its own way out. Only a program with a limit of time gets a group; the compiler of
  a build stays in the group of the command.
  The program does not run before its watcher is there (third review): the child
  waits for a byte on a second pipe, which the command writes once the watcher is
  forked; if the command is gone first, the pipe ends and the child with it. A program
  whose pipes or watcher cannot be made is not started. The command itself moves the
  watcher into the group and checks it before it writes the byte (fourth review). `make` builds the formatter
  too, so that `ail fmt` works in a checkout that ran only `make`.
- **A test leads a group of processes, and the group ends with it**, as
  `tests/run.sh` has it for a test that is killed; here also for one that ends by itself
  and leaves a child, whose directory is about to be removed. Asked for by the review of
  the pull request 3 of aildb, whose tests start `aildb` and stop it in a build.
- **The command keeps the descriptors 0 to 2 open**, so no file it opens is taken by a
  program it starts for its input or output.

## Not checked
- No test fetches from a network; `tests/cli.sh` uses repositories on
  disk, by their paths.
- A dependency whose clone has changes of its own is not noticed while
  its `.git/HEAD` is the locked revision.
- That the file a source is compiled into is not opened through a link has
  no test: its name has the number of the process in it.
- More than 256 packages and a path of package and file above 4095 bytes
  are refused in the code and have no test.

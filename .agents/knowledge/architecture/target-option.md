---
title: A target for ail build and ail test
last-verified: 2026-11-28
sources: [conversation 2026-11-28, docs/TODO.md of aildb (step 19), cli/ail.aiw, cli/tool.aiw, tests/cli.sh, tests/win.sh, tools/install.sh, runs of 2026-11-28 on Windows 11 Pro build 26300 with WSL 2 (Ubuntu, kernel 6.18.33.2)]
status: current
---
# A target for ail build and ail test

**Summary.** aildb is to have an executable for Windows, and its step 19
asked AIL for a way to build and test a package for that platform with the
command `ail`, and for the compiler for Windows in the archive of a
release. The user told the agent to start that work on 2026-11-28, after
AIL 0.2.4. `ail build --target windows-x86_64` and
`ail test --target windows-x86_64` are the answer, on the branch
`windows-target`. Everything below was chosen by the agent and is for the
user to review.

## Decisions

- **An option of `build` and `test`, right after the command** (agent,
  2026-11-28). Rejected: a line of the manifest that names the targets
  of a package, which would build each of them at every `ail build`
  though only a release needs the second; a variable of the
  environment, which a command line does not show.
- **The name of a target is the name of its directory in `compiler/`
  and `rt/`**, `windows-x86_64`, and it is a name as the manifest has
  them, so it cannot lead out of `build/`. The compiler is found
  beside the compiler of AIL as `ailc-<target>`: a target is one that
  this AIL has a compiler for, and no list of them is kept in the
  command. A name without such a file is the status 4.
- **`build/<target>/` holds what is built for a target**, and
  `build/<target>/tests/` what its tests leave, so the executables of
  the two platforms lie side by side and `ail clean` removes both. An
  executable of a target whose name starts with `windows-` ends in
  `.exe`, which Windows asks of a program.
- **The tests of Windows are run by `wine`**, looked for on `PATH`
  before anything is built, status 4 without one. On a machine with
  Windows and WSL 2 a script of that name starts the program on
  Windows itself ([page](../testing/windows-itself.md)). Rejected: a
  variable that names the program to run them with, until a second
  way to run them is asked for.
- **`tests/<target>.skip` lists the tests that are not for the
  target**, a name a line, as `tests/win.skip` of this repository
  does; any other line is nothing, so a reason can stand above a
  name. They are printed as `skip` and counted after the failed. A
  test that is named on the command line is run whether the list has
  it or not, to try one that is being ported.
- **`AIL_TMP` is a path from the top of the package for a target.** A
  path from the root of Linux is none to a program of Windows, and a
  test runs in the top of the package. `AIL_HOME` stays the path the
  command has.
- **A test of a target has 20 seconds**, as `tests/win.sh` gives its
  programs, and is tried once. `tests/win.sh` tries a test twice
  under Wine; a package that sees a start fail there has no such
  second try yet.
- **`ail run` takes no target.** It puts the program in the place of
  the command, which a program of another platform cannot be.
- **The compiler for Windows is built by `make` and is in an
  installation and in the archive** (`tools/install.sh`), beside
  `ailc`. It runs on Linux, so the archive stays one for x86-64
  Linux. The command `ail` itself still runs on Linux alone
  (`docs/TODO.md`).

- **The command runs on Windows, and a release has an archive for it**
  (user, 2026-11-28: "A release 0.2.5 já deve conter o executável do
  ail", and asked which, the one for Windows). The agent chose the
  rest: the same sources with the platform asked of the runtime where
  it matters (`tlwin` of `cli/tool.aiw`), no second set of files; an
  archive `ail-<version>-x86_64-windows.tar.gz` with the layout of the
  one for Linux, a `tar.gz` because the `tar` of Windows 10 and later
  unpacks it and the build has no tool that writes a zip; in it the
  compiler for Windows as a program of Windows and no other compiler,
  so `--target` names nothing there; an executable of a build on
  Windows is `build/<name>.exe`.
- **The service `access`, the 65th** (user, 2026-11-28, for aildb): 1 to
  run, 4 to read. On Windows a file to run must start with `MZ`, since
  `start` gives Windows the file by its path. The compiler had room for
  64 services in two tables and has it for 128; `tests/tables.sh` held
  the first limit and holds the second.

## What is not known

- Wine: this machine has none. WSL gives a program of Windows only
  the variables of the environment that `WSLENV` names, so the script
  `wine` of this machine names `AIL_TMP` and `AIL_HOME` there; Wine
  gives a program the whole environment.
- The command on Windows beyond what `win_ail` runs: `add`, `update` and
  a build with dependencies, which start git, and `init`.
- A package whose sources still have `sys`: `ail test --target` builds
  every executable of the manifest first and ends with 1 at the first
  that does not compile, as without a target.

## Runs

- 2026-11-28, at `b2448f6`, Ubuntu under WSL 2: `make test` status 0,
  3183 lines of ok.
- The same day and revision, `tests/win.sh all` with the tree on NTFS
  and the programs started on Windows 11 itself: status 0,
  `win_tests (616 run)` and sixteen named checks, `win_package` among
  them.

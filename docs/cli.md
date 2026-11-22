# The command `ail`

`ail` makes a package, builds it and runs it. A package is a directory
with a manifest, `ail.pkg` ([packages.md](packages.md)); the command
reads it, finds the compiler and the library of AIL, and does what would
otherwise be a Makefile and a script in each project.

```
ail new hello
cd hello
ail run
```

prints `hello from hello`.

`make` builds the command as `build/ail`, from `cli/ail.aiw`;
`tests/cli.sh` is its test. Dependencies, tests and an installation are
not written yet ([TODO.md](TODO.md)): a package is built with the `ail` of
a checkout, and a line `dep` of its manifest is read and not yet used.

## Commands

| Command | Does |
|---|---|
| `ail new NAME` | makes the directory `NAME` with a new package in it |
| `ail init [NAME]` | makes the current directory a package |
| `ail build [BIN]` | compiles the executables of the package into `build/` |
| `ail run [BIN] [-- ARGUMENT...]` | builds an executable and runs it |
| `ail clean` | removes `build/` |
| `ail version` | prints `ail` and the version of AIL |
| `ail help` | prints the commands |

`build`, `run` and `clean` work on the package the current directory is
in: the nearest directory, this one or one above it, that has an
`ail.pkg`. Sources are compiled from that directory, so a `use` names a
file of the package from its top, wherever the command was started.

### `new` and `init`

`ail new NAME` makes the directory `NAME`, which must not be there, and in
it:

- `ail.pkg`, with the name, the version 0.1.0, the version of the AIL
  that made it as the one it needs, and one executable, `NAME`, from
  `src/main.aiw`;
- `src/main.aiw`, a program that prints a line;
- `.gitignore`, which names `build/` and `deps/`.

It then runs `git init` there, and goes on without a repository if git
is not installed. `ail init` writes the same files into the current
directory and calls the package like the directory, or `NAME` if one is
given. It refuses a directory that has an `ail.pkg`, and leaves a
`src/main.aiw` and a `.gitignore` that are there as they are.

### `build`

`ail build` compiles every `bin` of the manifest to `build/<name>`;
`ail build BIN` compiles that one, which may be a `testbin`. Every source
is compiled each time: the compiler takes a few milliseconds, and nothing
keeps track of which file was read. The executable is written to a file
beside it and given its name when the compiler has ended well, so a
source that does not compile leaves the executable of before. The
compiler says what is wrong on stderr, and the status is 1.

The library of AIL is the package `ail` of every build
([language.md](language.md#packages)): `use "lib/std/io.aiw"` reads the
library of the AIL that the command belongs to. A package has no copy of
it and no link to it.

### `run`

`ail run` builds the executable and starts it in the place of the
command: with the arguments after `--`, in the directory the command was
started in, with its standard input and output, and its status is the
status of the command. If the manifest has more than one `bin`, the one
to run is named: `ail run BIN -- ARGUMENT...`.

## Where AIL is

The command needs the compiler, the library and the manifest of AIL. It
looks, in this order:

1. in the directory that the variable `AIL_HOME` of the environment
   names, if it is set;
2. in `../lib/ail` from the directory of its own executable, where an
   installation is to have them;
3. in `..` from that directory, which is a checkout with the command in
   `build/`.

Such a directory has `ail.pkg`, `lib/` and the compiler as `ailc` or as
`build/ailc`. The line `ail` of a manifest is compared with the version
in that `ail.pkg`, and a package that asks for an AIL this one is not
([packages.md](packages.md)) is not built.

## Statuses

| Status | When |
|---:|---|
| 0 | done; for `run`, the status of the program |
| 1 | a source did not compile |
| 2 | wrong usage: the commands are printed on stderr |
| 3 | no manifest, a manifest that is wrong (with the line), an executable it does not name, an AIL it asks for and this one is not |
| 4 | a file or a directory that cannot be read, written or run; AIL not found |

A message of the command is one line on stderr that starts with `ail: `;
one of the compiler starts with `ailc: `.

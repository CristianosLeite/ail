# The command `ail`

`ail` makes a package, builds it, runs it and tests it. A package is a directory
with a manifest, `ail.pkg` ([packages.md](packages.md)); the command
reads it, finds the compiler and the library of AIL, and does what would
otherwise be a Makefile and a script in each project.

```
ail new hello
cd hello
ail run
```

prints `hello from hello`, and `ail test` runs the one test the package
starts with.

`make` builds the command as `build/ail`, from `cli/ail.aiw`;
`tests/cli.sh` is its test. Dependencies and an installation are
not written yet ([TODO.md](TODO.md)): a package is built with the `ail` of
a checkout, and a line `dep` of its manifest is read and not yet used.

## Commands

| Command | Does |
|---|---|
| `ail new NAME` | makes the directory `NAME` with a new package in it |
| `ail init [NAME]` | makes the current directory a package |
| `ail build [BIN]` | compiles the executables of the package into `build/` |
| `ail run [BIN] [-- ARGUMENT...]` | builds an executable and runs it |
| `ail test [NAME...]` | builds everything and runs the tests of `tests/` |
| `ail fmt [--check]` | indents the sources, or says which lines are not indented |
| `ail clean` | removes `build/` |
| `ail version` | prints `ail` and the version of AIL |
| `ail help` | prints the commands |

`build`, `run`, `test`, `fmt` and `clean` work on the package the current directory is
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
- `tests/hello.aiw` and `tests/hello.out`, a test and what it prints;
- `.gitignore`, which names `build/` and `deps/`.

It then runs `git init` there, and goes on without a repository if git
is not installed. `ail init` writes the same files into the current
directory and calls the package like the directory, or `NAME` if one is
given. It refuses a directory that has an `ail.pkg`, and leaves a
`src/main.aiw`, a test and a `.gitignore` that are there as they are.

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

### `test`

A test is a program and what is expected of it, files `tests/<name>.*`,
as in the repository of AIL:

| File | Holds |
|---|---|
| `.aiw` | the program, compiled from the top of the package like any source of it |
| `.out` | what it is to write to stdout; without the file, nothing |
| `.code` | the status it is to end with, a decimal number; without the file, 0 |
| `.err` | what the compiler is to say on stderr when it refuses the program, with status 1; the program is then not run |

`ail test` first builds every `bin` and every `testbin` of the manifest,
so that a test can start `build/<name>`, and then runs the tests in the
order of their names; `ail test NAME...` runs those. Only the files of
`tests/` itself are tests: a directory below it, such as `tests/lib/`,
is for the files that tests name with `use`.

A test runs in the top of the package, with `/dev/null` as its stdin. It
finds in the variable `AIL_TMP` of the environment a directory that is
its own and empty, for the files it makes, which is removed when the
test has ended. A test that still runs after 10 seconds is killed and
has failed.

For each test a line `ok   <name>` or `FAIL <name>` is written to
stdout, then the number of tests and of those that failed; a line on
stderr says in what a test failed. What the compiler said, what the
program wrote to stdout and what it wrote to stderr stay in
`build/tests/<name>.err`, `.out` and `.log`, to be compared with what
was expected. The status is 1 if a test failed.

### `fmt`

`ail fmt` indents every source of the package with one tab for each
block, the [source style](language.md#source-style) of AIL, and changes
no other byte; `ail fmt --check` changes nothing, prints `path:line` for
each line that is not indented so, and ends with status 1 if there is
one. The sources are the files whose names end in `.aiw`, in the
package and the directories below it, without `build/`, `deps/` and
what starts with a dot. The work is done by the formatter of AIL
(`tools/indent.aiw`), which the command starts.

## Where AIL is

The command needs the compiler, the library and the manifest of AIL. It
looks, in this order:

1. in the directory that the variable `AIL_HOME` of the environment
   names, if it is set;
2. in `../lib/ail` from the directory of its own executable, where an
   installation is to have them;
3. in `..` from that directory, which is a checkout with the command in
   `build/`.

Such a directory has `ail.pkg`, `lib/`, the compiler as `ailc` or as
`build/ailc`, and the formatter as `indent` or as `build/tools/indent`. The line `ail` of a manifest is compared with the version
in that `ail.pkg`, and a package that asks for an AIL this one is not
([packages.md](packages.md)) is not built.

## Statuses

| Status | When |
|---:|---|
| 0 | done; for `run`, the status of the program |
| 1 | a source did not compile; a test failed; `fmt --check` found a line |
| 2 | wrong usage: the commands are printed on stderr |
| 3 | no manifest, a manifest that is wrong (with the line), an executable it does not name, an AIL it asks for and this one is not |
| 4 | a file or a directory that cannot be read, written or run; AIL not found |

A message of the command is one line on stderr that starts with `ail: `;
one of the compiler starts with `ailc: `.

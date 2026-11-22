# The command `ail`

`ail` makes a package, builds it, runs it and tests it, and brings in
the packages it uses. A package is a directory
with a manifest, `Ailfile` ([packages.md](packages.md)); the command
reads it, finds the compiler and the library of AIL, and does what would
otherwise be a Makefile and a script in each project.

```
ail new hello
cd hello
ail run
```

prints `hello from hello`, and `ail test` runs the one test the package
starts with.

`make` builds the command as `build/ail`, from `cli/ail.aiw`, with the
compiler and the formatter it looks for in a checkout, and
`make install` puts it where a shell finds it ([Installing](#installing));
`tests/cli.sh` and `tests/install.sh` are its tests.

## Commands

| Command | Does |
|---|---|
| `ail new NAME` | makes the directory `NAME` with a new package in it |
| `ail init [NAME]` | makes the current directory a package |
| `ail add URL [VERSION]` | uses the package of a git repository, at its tag `v<VERSION>` |
| `ail add --path DIRECTORY` | uses the package in a directory |
| `ail remove NAME` | uses the package `NAME` no longer |
| `ail update [NAME]` | moves the dependencies to their latest versions |
| `ail build [BIN]` | compiles the executables of the package into `build/` |
| `ail run [BIN] [-- ARGUMENT...]` | builds an executable and runs it |
| `ail test [NAME...]` | builds everything and runs the tests of `tests/` |
| `ail fmt [--check]` | indents the sources, or says which lines are not indented |
| `ail clean` | removes `build/` |
| `ail version` | prints `ail` and the version of AIL |
| `ail help` | prints the commands |

All but `new`, `init`, `version` and `help` work on the package the current directory is
in: the nearest directory, this one or one above it, that has an
`Ailfile`. Sources are compiled from that directory, so a `use` names a
file of the package from its top, wherever the command was started.

One command at a time works on a package: a second one, started while
the first runs, waits for it, since both would write the manifest, the
lock, `deps/` and `build/`. The lock is on the directory of the package
and is held by the command, not by the program that `ail run` starts;
a command that is killed leaves none. A test of a package therefore
does not start `ail` on that same package.
No command works on a package without the lock, and the lock needs
the directory of the package opened to be read: a package in a
directory that may be entered and not read is not built, with status 4.

### `new` and `init`

`ail new NAME` makes the directory `NAME`, which must not be there, and in
it:

- `Ailfile`, with the name, the version 0.1.0, the version of the AIL
  that made it as the one it needs, and one executable, `NAME`, from
  `src/main.aiw`;
- `src/main.aiw`, a program that prints a line;
- `tests/hello.aiw` and `tests/hello.out`, a test and what it prints;
- `.gitignore`, which names `build/` and `deps/`.

It then runs `git init` there, and goes on without a repository if git
is not installed. `ail init` writes the same files into the current
directory and calls the package like the directory, or `NAME` if one is
given. It refuses a directory that has an `Ailfile`, and leaves a
`src/main.aiw`, a test and a `.gitignore` that are there as they are.

### `add`, `remove` and `update`

```
ail add https://github.com/CristianosLeite/aildb.git
```

`ail add URL` reads the tags of the repository, takes the latest that is
a version, `v1.2.3`, fetches it into `deps/`, reads the name of the
package from its manifest, and writes the line `dep` into `Ailfile` and
the revision into `Ailfile.lock`; `ail add URL VERSION` takes that version.
A source of the package then names a file of it as
`use "name:path"` ([language.md](language.md#packages)).
`ail add --path DIRECTORY` uses the package as it lies in a directory,
for two packages that are worked on together: nothing is fetched and the
lock has no line for it. A package that is a dependency already is
replaced by what is added. An address or a directory is one value of a
line of the manifest: one with a space, or that starts with `#` or `-`,
is refused before anything is written.

`ail remove NAME` takes the line out of the manifest, the lines that are
no longer needed out of the lock, and the clone out of `deps/`, unless
another package of the build still uses that package: then its clone
and its line of the lock stay.

`ail update` looks for a later version of every dependency that comes
from a repository, `ail update NAME` of that one, and writes it into the
manifest and the lock; it prints `name 1.0.0 -> 1.1.0` or
`name 1.0.0 is the latest` for each. A version in a manifest is exact,
so nothing but `update` and `add` moves a dependency.

The three write the manifest and the lock back as they were if they
cannot finish: a repository that does not answer, a package that two
others ask for in two versions, a file that cannot be written. Each of
the two files is written whole or not at all, to a file beside it that
is then given its name.

### Dependencies in a build

`build`, `run` and `test` first find every package of the build: those
the manifest names, and those that these name in their own manifests.

- A package from a repository is in `deps/<name>`, a clone at the
  revision that `Ailfile.lock` has for it. A clone that is missing is made,
  and one at another revision is moved; one that is at its revision is
  not looked at again, so a build asks nothing of a network.
- A package without a line in the lock, because the manifest was changed
  by hand or the lock is not there, gets the revision its tag names now,
  and the lock is written again. Only the lock of the package that is
  built counts; those of its dependencies are not read.
- A package in a directory is read where it is. Its directory is taken
  from that of the package that names it.
- Each package has one version in a build. Two that ask for the same
  package ask for the same version, or for the same directory, by
  whatever path each names it; else the build is refused.
- A dependency has the name its manifest gives it, and one from a
  repository the version of its tag; it is refused if it asks for an AIL
  that this one is not.

Each of them is given to the compiler with its directory, this package
under its own name too, unless that name is `ail`, which is the library
in every build. `deps/` is not kept with the sources: `ail new`
has git leave it out, and the lock is enough to make it again.

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
test has ended, and in `AIL_HOME` the directory of the AIL that runs
it ([Where AIL is](#where-ail-is)), for a test that reads a file of AIL.
A test that still runs after 10 seconds is killed and has failed, and
so has one whose compiling takes that long. The processes a test
started end with it: when it has ended or was killed, what is left of
its group of processes is killed, and so it is when the command itself
is interrupted or killed while a test runs. The compiler of a build
is in the group of the command and is interrupted with it.

For each test a line `ok   <name>` or `FAIL <name>` is written to
stdout, then the number of tests and of those that failed; a line on
stderr says in what a test failed. What the compiler said, what the
program wrote to stdout and what it wrote to stderr stay in
`build/tests/<name>.err`, `.out` and `.log`, to be compared with what
was expected; the executable of the test is `build/tests/<name>.exe`. The status is 1 if a test failed.

### `fmt`

`ail fmt` indents every source of the package with one tab for each
block, the [source style](language.md#source-style) of AIL, and changes
no other byte; `ail fmt --check` changes nothing, prints `path:line` for
each line that is not indented so, and ends with status 1 if there is
one. The sources are the files whose names end in `.aiw`, in the
package and the directories below it, without `build/`, `deps/`, what
starts with a dot and what is a link: a link may name a file of
another project. The work is done by the formatter of AIL
(`tools/indent.aiw`), which the command starts.

## Installing

```
make install PREFIX=$HOME/.local
```

puts the command at `bin/ail` under the prefix, `/usr/local` if none is
given, and in `lib/ail/` what the command looks for from there: the
compiler `ailc`, the formatter `indent`, the manifest `Ailfile` with the
version, the licence, and the library, `lib/`. With `bin/` on `PATH`
nothing else is needed, and the checkout it was built in may go.
`DESTDIR` is put before the prefix, for a package made in one place and
installed to another. A second `make install` replaces the first, the
library whole. The directories are made for every user to enter and
the files to read, whatever mask the installing user has.

`make dist` writes the same files as `build/ail-<version>-x86_64-linux.tar.gz`,
which unpacks into a directory of that name with `bin/` and `lib/` in it:
the file of a release, for a machine that has no checkout and no seed.
It is used where it is unpacked, with its `bin/` on `PATH`.

One AIL is installed under a prefix. A package that asks for a later one
is refused by the command and built after AIL is installed again;
several versions side by side are not managed ([TODO.md](TODO.md)).

## Where AIL is

The command needs the compiler, the library and the manifest of AIL. It
looks, in this order:

1. in the directory that the variable `AIL_HOME` of the environment
   names, if it is set;
2. in `../lib/ail` from the directory of its own executable, where an
   installation has them;
3. in `..` from that directory, which is a checkout with the command in
   `build/`.

Such a directory has `Ailfile`, `lib/`, the compiler as `ailc` or as
`build/ailc`, and the formatter as `indent` or as `build/tools/indent`. The line `ail` of a manifest is compared with the version
in that `Ailfile`, and a package that asks for an AIL this one is not
([packages.md](packages.md)) is not built.

## Statuses

| Status | When |
|---:|---|
| 0 | done; for `run`, the status of the program |
| 1 | a source did not compile; a test failed; `fmt --check` found a line |
| 2 | wrong usage: the commands are printed on stderr |
| 3 | no manifest, a manifest or a lock that is wrong (with the line), an executable or a dependency it does not name, an AIL it asks for and this one is not, a package asked for in two versions |
| 4 | a file or a directory that cannot be read, written or run; AIL not found; git failed, or a repository has no such tag |

A message of the command is one line on stderr that starts with `ail: `;
one of the compiler starts with `ailc: `, and git says in its own words
why it failed, before the line of the command.

# Packages

A package is a directory of AIL sources with a name and a version: a
program, a library that other packages use, or both. Its manifest, the
file `Ailfile` at its top, says what it is called, which version it is,
which AIL it needs, what is built from it and which packages it uses.
AIL itself has one, and so has everything built on it, so that a version
means the same thing in each.

How a source names a file of another package is in
[language.md](language.md#packages). This page is the manifest and the
lock. The command that works with them is `ail` ([cli.md](cli.md)):
`cli/manifest.aiw` reads, checks and changes both files, with
`tests/cli_manifest.aiw` as its test, and `cli/deps.aiw` finds and
fetches the packages they name.

## The manifest, `Ailfile`

```
# a vector search engine
name aildb
version 0.1.0
ail 0.1.0

bin aildb src/aildb.aiw
testbin aildb-stops tests/lib/stops.aiw

dep other 1.2.0 https://example.org/other.git
dep local ../local
```

A line is a key and its values, parted by spaces or tabs. A value that
starts with `#` ends the line, with everything after it, so a line that
starts with `#` is a comment; an empty line is nothing. No value has a
space, and none has a byte below 32 or the byte 127.

| Key | Values | Says |
|---|---|---|
| `name` | a name | what the package is called; once, and required |
| `version` | a version | which version this is; once, and required |
| `ail` | a version | the version of AIL the package needs; once at most |
| `bin` | a name, a source | an executable `build/<name>`, compiled from the source |
| `testbin` | a name, a source | the same, built only for the tests |
| `dep` | a name, a version, an address | a package it uses: the tag `v<version>` of the git repository at the address |
| `dep` | a name, a directory | a package it uses, as it lies in that directory: for work in progress |

- **A name** is 1 to 64 bytes, each a small letter, a digit, `-` or `_`,
  the first a letter or a digit. It is the name before the colon of
  `use "name:path"`. No dependency is called `ail`, which is the library
  of AIL in every package.
- **A version** is three decimal numbers with dots between, `1.2.3`, none
  above 2097151 and none with a zero in front. A later version is one
  whose first number is larger, or with that equal the second, or the
  third. There is nothing after the third number.
- **The line `ail`** is met by an AIL that is not earlier than the
  version and has the same first number: `ail 0.1.5` is met by 0.1.5 and
  0.2.0, not by 0.1.4 or 1.0.0.
- **A source** is a path inside the package: not one from the root,
  without a colon, and with no `..` that leads above the top of the
  package (`src/../a.aiw` is one, `../a.aiw` and `src/../../a.aiw` are
  none). The names of `bin` and `testbin` are one set: each is
  the name of a file in `build/`.
- **A dependency** is named once. The version of one is exact: the tag
  `v1.2.0`, and no later one is taken in its place.
- An address or a directory does not start with `-`: it is given to git,
  which would read it as an option.
- Another key, a value too few or too many, and `name`, `version` or
  `ail` a second time are errors, with the number of the line.

## The lock, `Ailfile.lock`

```
other 1.2.0 0123456789abcdef0123456789abcdef01234567 https://example.org/other.git
```

The lock has a line for every package that is fetched from a git
repository, those that a dependency uses in turn included: its name, its
version, the revision that the tag named when the package was added, in
forty digits of base sixteen with small letters, and the address. It is
written by the command and kept with the sources, so that a build of the
same sources reads the same revisions; a tag that later names another
revision does not change what is built. A line counts for a dependency
while the manifest asks for that version from that address; when it
asks for another, the tag is read again. A dependency that is a directory
has no line, and none is called `ail`, as in the manifest. Comments and empty lines are as in the manifest.

## Versions of AIL

The version of AIL is in its own `Ailfile`, and is the one a line `ail`
asks for. It is apart from the number of the seed in `seed/MANIFEST`,
which counts the released compilers that the source is built from: a
seed is cut when the source of the compiler is to use a new statement,
a version is given when AIL is released to those who use it.

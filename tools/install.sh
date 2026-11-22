#!/bin/sh
# usage: tools/install.sh BUILD PREFIX
#
# Put AIL as it was built in the directory BUILD under the directory
# PREFIX: the command as bin/ail, and in lib/ail/ what the command looks
# for from there (docs/cli.md), the compiler, the formatter, the manifest
# of AIL, its licence and the library. make install and make dist call
# it. What was in lib/ail/lib before is removed, so that a file the
# library no longer has does not stay.
set -eu
cd "$(dirname "$0")/.."
[ $# -eq 2 ] || { echo "usage: tools/install.sh BUILD PREFIX" >&2; exit 2; }
b=$1 p=$2
for f in "$b/ail" "$b/ailc" "$b/tools/indent"; do
    [ -x "$f" ] || { echo "install: $f is not built" >&2; exit 1; }
done
mkdir -p "$p/bin" "$p/lib/ail"
install -m 755 "$b/ail" "$p/bin/ail"
install -m 755 "$b/ailc" "$p/lib/ail/ailc"
install -m 755 "$b/tools/indent" "$p/lib/ail/indent"
install -m 644 ail.pkg LICENSE "$p/lib/ail/"
rm -rf "$p/lib/ail/lib"
# the sources of the library, and nothing else that lies among them
find lib -type f -name '*.aiw' | while read -r f; do
    mkdir -p "$p/lib/ail/$(dirname "$f")"
    install -m 644 "$f" "$p/lib/ail/$f"
done

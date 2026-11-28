#!/bin/sh
# usage: tools/install.sh BUILD PREFIX [windows]
#
# Put AIL as it was built in the directory BUILD under the directory
# PREFIX: the command as bin/ail, and in lib/ail/ what the command looks
# for from there (docs/cli.md), the compiler, the compiler for Windows,
# which runs here too, the formatter, the manifest of AIL, its licence
# and the library. make install and make dist call
# it. What was in lib/ail/lib before is removed, so that a file the
# library no longer has does not stay. With "windows" the programs are
# those of Windows that make built in BUILD/windows-x86_64, under the
# same names with ".exe": the command, the compiler and the formatter,
# for a machine with Windows.
set -eu
# the directories are for every user, whatever mask the one who installs
# has for new files: the files get their modes from install below
umask 022
cd "$(dirname "$0")/.."
[ $# -eq 2 ] || { [ $# -eq 3 ] && [ "$3" = windows ]; } || { echo "usage: tools/install.sh BUILD PREFIX [windows]" >&2; exit 2; }
b=$1 p=$2
lib() {
    install -m 644 Ailfile LICENSE "$p/lib/ail/"
    rm -rf "$p/lib/ail/lib"
    # the sources of the library, and nothing else that lies among them
    find lib -type f -name '*.aiw' | while read -r f; do
        mkdir -p "$p/lib/ail/$(dirname "$f")"
        install -m 644 "$f" "$p/lib/ail/$f"
    done
}
if [ $# -eq 3 ]; then
    w=$b/windows-x86_64
    for f in "$w/ail.exe" "$w/ailc.exe" "$w/indent.exe"; do
        [ -f "$f" ] || { echo "install: $f is not built" >&2; exit 1; }
    done
    mkdir -p "$p/bin" "$p/lib/ail"
    install -m 755 "$w/ail.exe" "$p/bin/ail.exe"
    install -m 755 "$w/ailc.exe" "$p/lib/ail/ailc.exe"
    install -m 755 "$w/indent.exe" "$p/lib/ail/indent.exe"
    lib
    exit 0
fi
for f in "$b/ail" "$b/ailc" "$b/ailc-windows-x86_64" "$b/tools/indent"; do
    [ -x "$f" ] || { echo "install: $f is not built" >&2; exit 1; }
done
mkdir -p "$p/bin" "$p/lib/ail"
install -m 755 "$b/ail" "$p/bin/ail"
install -m 755 "$b/ailc" "$p/lib/ail/ailc"
install -m 755 "$b/ailc-windows-x86_64" "$p/lib/ail/ailc-windows-x86_64"
install -m 755 "$b/tools/indent" "$p/lib/ail/indent"
lib

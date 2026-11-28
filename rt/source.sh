#!/bin/sh
# usage: rt/source.sh <name> <source.aiw> > data lines
#
# Write an AIL source of the runtime as data, the form in which the
# compiler has it: the four bytes of its length under the name <name>n
# and its bytes, 16 a line, under <name>. Lines that are a comment or
# empty are left out, since the compiler reads the text for every
# program; the others are as they are. The compiler has room for 128 KiB
# of the two it carries, so the source of the services (rtsrc) is
# refused beyond 112 KiB and any other beyond 16 KiB.
set -eu
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$2" > "$tmp" || true
n=$(wc -c < "$tmp")
max=16384
[ "$1" != rtsrc ] || max=114688
[ "$n" -le $max ] || { echo "source.sh: $2 is $n bytes, more than $max" >&2; exit 1; }
echo "# $2 without its comments, written by rt/source.sh"
echo "data $1n $((n % 256)) $((n / 256 % 256)) $((n / 65536 % 256)) 0"
if [ "$n" -eq 0 ]; then
    echo "data $1 0"
else
    od -An -v -tu1 -w16 "$tmp" | awk -v name="$1" 'NR == 1 { print "data " name $0; next } { print "data" $0 }' |
        tr -s ' '
fi

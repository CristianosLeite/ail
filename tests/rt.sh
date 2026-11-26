#!/bin/sh
# Check the runtime beyond what its services do, which the tests rt_*
# run: the form of its image, build/rt/image (docs/runtime.md), that the
# compiler named by AILC (default build/ailc) puts that image into an
# executable and nothing else of its own, and that the library asks its
# platform for nothing but through the runtime: no file of lib/ has a
# sys statement.
set -u
cd "$(dirname "$0")/.." || exit 1
ailc=${AILC:-build/ailc}
img=build/rt/image
mkdir -p build/tests
tmp=$(mktemp -d build/tests/rt.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0

say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
u4() { od -An -tu4 -j"$1" -N4 "$img" | tr -d ' '; }

# the header: the mark, the version, a size that is the file's and a
# multiple of 64, entries that lie in the image behind the table, and no
# distance to the state yet
size=$(wc -c < "$img")
n=$(u4 16)
r=0
[ "$(head -c 4 "$img")" = AILR ] || r=1
[ "$(u4 4)" -eq 1 ] || r=1
[ "$(u4 8)" -eq "$size" ] && [ $((size % 64)) -eq 0 ] || r=1
[ "$(u4 20)" -eq 0 ] && [ "$(u4 24)" -eq 0 ] && [ "$(u4 28)" -eq 0 ] || r=1
i=0
while [ $i -lt "$n" ]; do
    e=$(u4 $((32 + 4 * i)))
    [ "$e" -ge $((32 + 4 * n)) ] && [ "$e" -lt "$size" ] || r=1
    i=$((i + 1))
done
[ "$n" -gt 1 ] || r=1
say rt_image_header $r

# an executable is the header, the image with the distance filled in, and
# the program: the empty program is two instructions
: | "$ailc" > "$tmp/empty" 2> /dev/null
r=0
[ "$(wc -c < "$tmp/empty")" -eq $((176 + size + 7)) ] || r=1
head -c 200 "$tmp/empty" | tail -c 24 > "$tmp/a"; head -c 24 "$img" > "$tmp/b"
cmp -s "$tmp/a" "$tmp/b" || r=1
head -c $((176 + size)) "$tmp/empty" | tail -c +209 > "$tmp/a"; tail -c +33 "$img" > "$tmp/b"
cmp -s "$tmp/a" "$tmp/b" || r=1
chmod +x "$tmp/empty"
"$tmp/empty" || r=1
say rt_image_in_executable $r

# a program runs with no descriptor open, and says so by its status
printf 'rt write 1 "x" as n\nrt exit 0-n\n' | "$ailc" > "$tmp/closed" 2> /dev/null
chmod +x "$tmp/closed"
"$tmp/closed" <&- >&- 2>&-
[ $? -eq 9 ]
say rt_runs_without_descriptors $?

# the library is the same on every platform
out=$(grep -n '^[[:space:]]*sys ' $(find lib -name '*.aiw') /dev/null)
[ -z "$out" ]
r=$?
say rt_library_has_no_sys $r
[ $r -eq 0 ] || echo "$out" | sed 's/^/     /'

exit $fail

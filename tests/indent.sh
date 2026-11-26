#!/bin/sh
# Check tools/indent.aiw, built as build/tools/indent, which sets the
# indentation of a source: a copy of tests/indent/in.aiw must become
# tests/indent/out.aiw, byte for byte, and that must be left as it is;
# both must compile to the same executable, which exits with 209.
# tests/indent/wrong.aiw, which is no program (an end too many, a block
# left open, no LF at its end), must become tests/indent/wrong.out.aiw.
# --check must print the lines that would change, write nothing and
# exit with 1, or print nothing and exit with 0; - must write to stdout
# what it reads from stdin. A file with no line to change is not written,
# and the tool fails with a message without arguments, for a file it
# cannot read and for one it cannot write.
# Last, the sources of the repository must be indented as the tool would
# indent them: the examples, the compiler, the libraries, the tools
# and the tests, but for the files that tests/indent/skip
# lists.
set -u
cd "$(dirname "$0")/.." || exit 1
ailc=${AILC:-build/ailc}
mkdir -p build/tests
tmp=$(mktemp -d build/tests/indent.XXXXXX) || exit 1
trap 'chmod -R u+w "$tmp" 2> /dev/null; rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0
say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
cp tests/indent/in.aiw "$tmp/a.aiw"
build/tools/indent "$tmp/a.aiw" > "$tmp/said" 2>&1 &&
    cmp -s "$tmp/a.aiw" tests/indent/out.aiw && [ ! -s "$tmp/said" ]
say indent_formats $?
r=0
cp tests/indent/out.aiw "$tmp/b.aiw"
chmod a-w "$tmp/b.aiw"
build/tools/indent "$tmp/b.aiw" > "$tmp/said" 2>&1 || r=1
cmp -s "$tmp/b.aiw" tests/indent/out.aiw && [ ! -s "$tmp/said" ] || r=1
say indent_formatted_stays $r
r=0
for f in in out; do
    timeout --signal=KILL 10 "$ailc" < tests/indent/$f.aiw > "$tmp/$f" 2> /dev/null && chmod +x "$tmp/$f" || r=1
done
cmp -s "$tmp/in" "$tmp/out" || r=1
timeout --signal=KILL 10 "$tmp/out" > /dev/null 2>&1
[ $? -eq 209 ] || r=1
say indent_same_bytes $r
r=0
cp tests/indent/wrong.aiw "$tmp/w.aiw"
build/tools/indent "$tmp/w.aiw" 2> /dev/null && cmp -s "$tmp/w.aiw" tests/indent/wrong.out.aiw || r=1
build/tools/indent "$tmp/w.aiw" "$tmp/a.aiw" 2> /dev/null && cmp -s "$tmp/w.aiw" tests/indent/wrong.out.aiw || r=1
say indent_wrong_program $r
r=0
printf 'if x\ny=1\n\tend\n' > "$tmp/c.aiw"
cp "$tmp/c.aiw" "$tmp/c0.aiw"
build/tools/indent --check "$tmp/a.aiw" "$tmp/c.aiw" "$tmp/w.aiw" > "$tmp/said" 2> "$tmp/err"
[ $? -eq 1 ] && [ ! -s "$tmp/err" ] || r=1
[ "$(cat "$tmp/said")" = "$tmp/c.aiw:2
$tmp/c.aiw:3" ] || r=1
cmp -s "$tmp/c.aiw" "$tmp/c0.aiw" || r=1
build/tools/indent --check "$tmp/a.aiw" "$tmp/w.aiw" > "$tmp/said" 2>&1
[ $? -eq 0 ] && [ ! -s "$tmp/said" ] || r=1
say indent_check $r
r=0
build/tools/indent - < tests/indent/in.aiw > "$tmp/o.aiw" 2> "$tmp/err" &&
    cmp -s "$tmp/o.aiw" tests/indent/out.aiw && [ ! -s "$tmp/err" ] || r=1
build/tools/indent - < /dev/null > "$tmp/o.aiw" 2>&1 && [ ! -s "$tmp/o.aiw" ] || r=1
say indent_stdin $r
# the path of a use has no escapes: a backslash before its last quote
# opens no string, and the lines behind it are indented
[ "$(printf 'use "a\\"\nif 1\nx=1\nend\n' | build/tools/indent -)" = "$(printf 'use "a\\"\nif 1\n\tx=1\nend\n')" ]
say indent_use_path_ends_with_backslash $?
r=0
for a in "" "--check" "- x.aiw" "--check -"; do
    build/tools/indent $a > /dev/null 2> "$tmp/said"
    [ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "usage: indent [--check] file.aiw ... | indent -" ] || r=1
done
build/tools/indent "$tmp/none.aiw" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "indent: cannot read $tmp/none.aiw" ] || r=1
[ ! -e "$tmp/none.aiw" ] || r=1
chmod a-w "$tmp/c.aiw"
if [ -w "$tmp/c.aiw" ]; then
    :   # root writes anything
else
    build/tools/indent "$tmp/c.aiw" > /dev/null 2> "$tmp/said"
    [ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "indent: cannot write $tmp/c.aiw" ] || r=1
    cmp -s "$tmp/c.aiw" "$tmp/c0.aiw" || r=1
fi
say indent_errors $r
ls examples/*.aiw compiler/*.aiw compiler/*/*.aiw rt/*/*.aiw lib/std/*.aiw lib/async/*.aiw lib/nd/*.aiw lib/algo/*.aiw tools/*.aiw tools/lib/*.aiw \
    tests/*.aiw tests/lib/*.aiw |
    grep -vxFf tests/indent/skip > "$tmp/list"
xargs build/tools/indent --check < "$tmp/list" > "$tmp/said" 2>&1
r=$?
[ $r -eq 0 ] || head -n 20 "$tmp/said"
say indent_sources $r
exit $fail

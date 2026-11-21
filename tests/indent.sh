#!/bin/sh
# Check tools/indent.ai, built as build/tools/indent, which sets the
# indentation of a source: a copy of tests/indent/in.ai must become
# tests/indent/out.ai, byte for byte, and that must be left as it is;
# both must compile to the same executable, which exits with 209.
# tests/indent/wrong.ai, which is no program (an end too many, a block
# left open, no LF at its end), must become tests/indent/wrong.out.ai.
# --check must print the lines that would change, write nothing and
# exit with 1, or print nothing and exit with 0; - must write to stdout
# what it reads from stdin. A file with no line to change is not written,
# and the tool fails with a message without arguments, for a file it
# cannot read and for one it cannot write.
# Last, the sources of the repository must be indented as the tool would
# indent them: the examples, the compiler, the libraries, the tools, the
# bench programs and the tests, but for the files that tests/indent/skip
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
cp tests/indent/in.ai "$tmp/a.ai"
build/tools/indent "$tmp/a.ai" > "$tmp/said" 2>&1 &&
    cmp -s "$tmp/a.ai" tests/indent/out.ai && [ ! -s "$tmp/said" ]
say indent_formats $?
r=0
cp tests/indent/out.ai "$tmp/b.ai"
chmod a-w "$tmp/b.ai"
build/tools/indent "$tmp/b.ai" > "$tmp/said" 2>&1 || r=1
cmp -s "$tmp/b.ai" tests/indent/out.ai && [ ! -s "$tmp/said" ] || r=1
say indent_formatted_stays $r
r=0
for f in in out; do
    timeout --signal=KILL 10 "$ailc" < tests/indent/$f.ai > "$tmp/$f" 2> /dev/null && chmod +x "$tmp/$f" || r=1
done
cmp -s "$tmp/in" "$tmp/out" || r=1
timeout --signal=KILL 10 "$tmp/out" > /dev/null 2>&1
[ $? -eq 209 ] || r=1
say indent_same_bytes $r
r=0
cp tests/indent/wrong.ai "$tmp/w.ai"
build/tools/indent "$tmp/w.ai" 2> /dev/null && cmp -s "$tmp/w.ai" tests/indent/wrong.out.ai || r=1
build/tools/indent "$tmp/w.ai" "$tmp/a.ai" 2> /dev/null && cmp -s "$tmp/w.ai" tests/indent/wrong.out.ai || r=1
say indent_wrong_program $r
r=0
printf 'if x\ny=1\n\tend\n' > "$tmp/c.ai"
cp "$tmp/c.ai" "$tmp/c0.ai"
build/tools/indent --check "$tmp/a.ai" "$tmp/c.ai" "$tmp/w.ai" > "$tmp/said" 2> "$tmp/err"
[ $? -eq 1 ] && [ ! -s "$tmp/err" ] || r=1
[ "$(cat "$tmp/said")" = "$tmp/c.ai:2
$tmp/c.ai:3" ] || r=1
cmp -s "$tmp/c.ai" "$tmp/c0.ai" || r=1
build/tools/indent --check "$tmp/a.ai" "$tmp/w.ai" > "$tmp/said" 2>&1
[ $? -eq 0 ] && [ ! -s "$tmp/said" ] || r=1
say indent_check $r
r=0
build/tools/indent - < tests/indent/in.ai > "$tmp/o.ai" 2> "$tmp/err" &&
    cmp -s "$tmp/o.ai" tests/indent/out.ai && [ ! -s "$tmp/err" ] || r=1
build/tools/indent - < /dev/null > "$tmp/o.ai" 2>&1 && [ ! -s "$tmp/o.ai" ] || r=1
say indent_stdin $r
r=0
for a in "" "--check" "- x.ai" "--check -"; do
    build/tools/indent $a > /dev/null 2> "$tmp/said"
    [ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "usage: indent [--check] file.ai ... | indent -" ] || r=1
done
build/tools/indent "$tmp/none.ai" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "indent: cannot read $tmp/none.ai" ] || r=1
[ ! -e "$tmp/none.ai" ] || r=1
chmod a-w "$tmp/c.ai"
if [ -w "$tmp/c.ai" ]; then
    :   # root writes anything
else
    build/tools/indent "$tmp/c.ai" > /dev/null 2> "$tmp/said"
    [ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "indent: cannot write $tmp/c.ai" ] || r=1
    cmp -s "$tmp/c.ai" "$tmp/c0.ai" || r=1
fi
say indent_errors $r
ls examples/*.ai compiler/*.ai lib/*.ai lib/async/*.ai tools/*.ai tools/lib/*.ai \
    bench/par/*.ai bench/async/*.ai tests/*.ai tests/lib/*.ai |
    grep -vxFf tests/indent/skip > "$tmp/list"
xargs build/tools/indent --check < "$tmp/list" > "$tmp/said" 2>&1
r=$?
[ $r -eq 0 ] || head -n 20 "$tmp/said"
say indent_sources $r
exit $fail

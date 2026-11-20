#!/bin/sh
# Check tools/infix.py, which rewrites statements as expressions:
# tests/infix/in.ai must become tests/infix/out.ai, byte for byte; that
# result must be left as it is when rewritten again; and both programs
# must compile and exit alike, with the same output. tests/infix/long.ai
# has two assignments in place that are too long for one line: it must
# become tests/infix/long.out.ai, the same program.
set -u
cd "$(dirname "$0")/.." || exit 1
ailc=${AILC:-build/ailc}
mkdir -p build/tests
tmp=$(mktemp -d build/tests/infix.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0
say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
python3 tools/infix.py tests/infix/in.ai "$tmp/out.ai" 2> /dev/null &&
    cmp -s "$tmp/out.ai" tests/infix/out.ai
say infix_rewrites $?
python3 tools/infix.py tests/infix/out.ai "$tmp/again.ai" 2> /dev/null &&
    cmp -s "$tmp/again.ai" tests/infix/out.ai
say infix_rewritten_stays $?
r=0
for f in in out; do
    timeout --signal=KILL 10 "$ailc" < tests/infix/$f.ai > "$tmp/$f" 2> /dev/null && chmod +x "$tmp/$f" || r=1
    timeout --signal=KILL 10 "$tmp/$f" > "$tmp/$f.txt" 2> /dev/null
    echo $? > "$tmp/$f.code"
done
cmp -s "$tmp/in.txt" "$tmp/out.txt" || r=1
cmp -s "$tmp/in.code" "$tmp/out.code" || r=1
[ "$(cat "$tmp/in.code")" = 6 ] || r=1
say infix_same_program $r
r=0
python3 tools/infix.py tests/infix/long.ai "$tmp/long.out.ai" 2> /dev/null &&
    cmp -s "$tmp/long.out.ai" tests/infix/long.out.ai || r=1
for f in long long.out; do
    timeout --signal=KILL 10 "$ailc" < tests/infix/$f.ai > "$tmp/$f" 2> /dev/null && chmod +x "$tmp/$f" || r=1
    timeout --signal=KILL 10 "$tmp/$f" > /dev/null 2>&1
    [ $? -eq 16 ] || r=1
done
say infix_long_lines_stay_two $r
exit $fail

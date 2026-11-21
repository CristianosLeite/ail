#!/bin/sh
# Check the compiler on random programs whose result no AIL program
# computed, and tools/randvars.aw itself.
# - tests/randvars/seed<s>[-top]-<n>-<form>.aw are programs that the
#   Python script wrote which the tool was ported from, each in its three
#   forms, and seed<s>[-top]-<n>.code is the exit status that Python
#   computed for it. Every form must compile and exit with that status,
#   and the forms statements and flat must compile to the same file.
# - The tool must write the program of tests/randvars/dump/0.txt for the
#   seed 1: the random numbers and what is made of them stay what they are.
# - With a compiler that fails, the tool must report every form, keep the
#   sources and exit with 1.
set -u
cd "$(dirname "$0")/.." || exit 1
ailc=${AILC:-build/ailc}
top=$PWD
mkdir -p build/tests
tmp=$(mktemp -d build/tests/randvars.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0
say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

for code in tests/randvars/*.code; do
    base=${code%.code}
    want=$(cat "$code")
    r=0
    for form in statements flat expressions; do
        timeout --signal=KILL 10 "$ailc" < "$base-$form.aw" > "$tmp/$form" 2> /dev/null && chmod +x "$tmp/$form" || r=1
        timeout --signal=KILL 10 "$tmp/$form" > /dev/null 2>&1
        [ $? -eq "$want" ] || r=1
    done
    cmp -s "$tmp/statements" "$tmp/flat" || r=1
    say "randvars_fixture $(basename "$base")" $r
done

mkdir "$tmp/dump"
build/tools/randvars dump "$tmp/dump" 1 1 > /dev/null 2>&1 &&
    cmp -s "$tmp/dump/0.txt" tests/randvars/dump/0.txt
say randvars_same_programs $?

# in a directory of its own, where it keeps the sources of what failed
mkdir "$tmp/run"
(cd "$tmp/run" && "$top/build/tools/randvars" /bin/false 3 1 > out 2> /dev/null; echo $? > code)
r=0
[ "$(cat "$tmp/run/code")" = 1 ] || r=1
n=$(grep -c '^FAIL randvars [0-9]* as [a-z]*: does not compile:  (kept as build/randvars/seed1-[0-9]*-[a-z]*\.aw)$' "$tmp/run/out")
[ "$n" -gt 0 ] && [ "$n" -eq "$(wc -l < "$tmp/run/out")" ] || r=1
[ "$n" -eq "$(ls "$tmp/run/build/randvars" 2> /dev/null | wc -l)" ] || r=1
say randvars_reports_failures $r

r=0
build/tools/randvars > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && grep -q '^usage: randvars <compiler> <count> <seed> \[top|async|asyncs\]$' "$tmp/said" || r=1
build/tools/randvars "$ailc" many 1 > /dev/null 2>&1
[ $? -eq 1 ] || r=1
say randvars_usage $r

exit $fail

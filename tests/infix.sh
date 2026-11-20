#!/bin/sh
# Check tools/infix.ai, built as build/tools/infix, which rewrites
# statements as expressions: tests/infix/in.ai must become
# tests/infix/out.ai, byte for byte; that result must be left as it is
# when rewritten again; and both programs must compile and exit alike,
# with the same output. tests/infix/long.ai has two assignments in place
# that are too long for one line: it must become tests/infix/long.out.ai,
# the same program. tests/infix/edge.ai has the lines at the edges of the
# rules (separators, CR, comments, the limit of 100 bytes) and must become
# tests/infix/edge.out.ai. The three .out.ai files are what the Python
# script made that the tool was ported from. The tool must say what it
# did, and fail with a message without its two files or its input.
# A var declared in a file the source names with use (tests/infix/use.ai)
# or in a file named after the two (tests/infix/part.ai) is not folded,
# and a file of a use that cannot be read is refused.
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
build/tools/infix tests/infix/in.ai "$tmp/out.ai" 2> "$tmp/said" &&
    cmp -s "$tmp/out.ai" tests/infix/out.ai &&
    [ "$(cat "$tmp/said")" = "spelled 20, loops 1, folded 5" ]
say infix_rewrites $?
build/tools/infix tests/infix/out.ai "$tmp/again.ai" 2> "$tmp/said" &&
    cmp -s "$tmp/again.ai" tests/infix/out.ai &&
    [ "$(cat "$tmp/said")" = "spelled 0, loops 0, folded 0" ]
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
build/tools/infix tests/infix/long.ai "$tmp/long.out.ai" 2> /dev/null &&
    cmp -s "$tmp/long.out.ai" tests/infix/long.out.ai || r=1
for f in long long.out; do
    timeout --signal=KILL 10 "$ailc" < tests/infix/$f.ai > "$tmp/$f" 2> /dev/null && chmod +x "$tmp/$f" || r=1
    timeout --signal=KILL 10 "$tmp/$f" > /dev/null 2>&1
    [ $? -eq 16 ] || r=1
done
say infix_long_lines_stay_two $r
build/tools/infix tests/infix/edge.ai "$tmp/edge.out.ai" 2> /dev/null &&
    cmp -s "$tmp/edge.out.ai" tests/infix/edge.out.ai
say infix_edges $?
r=0
build/tools/infix tests/infix/in.ai > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "usage: infix in.ai out.ai [vars.ai ...]" ] || r=1
build/tools/infix "$tmp/none.ai" "$tmp/o.ai" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "infix: cannot read $tmp/none.ai" ] || r=1
[ ! -e "$tmp/o.ai" ] || r=1
build/tools/infix tests/infix/in.ai "$tmp/no/dir/o.ai" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "infix: cannot write $tmp/no/dir/o.ai" ] || r=1
printf 'use "%s/none.ai"\nx=1\n' "$tmp" > "$tmp/uses.ai"
build/tools/infix "$tmp/uses.ai" "$tmp/o.ai" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "infix: cannot read $tmp/none.ai" ] || r=1
[ ! -e "$tmp/o.ai" ] || r=1
say infix_errors $r
# a var of a file that the source names with use is a var: the line that
# sets it stays, and the program gives what the function reads, 42
r=0
build/tools/infix tests/infix/use.ai "$tmp/use.ai" 2> "$tmp/said" &&
    cmp -s "$tmp/use.ai" tests/infix/use.ai &&
    [ "$(cat "$tmp/said")" = "spelled 0, loops 0, folded 0" ] || r=1
timeout --signal=KILL 10 "$ailc" < "$tmp/use.ai" > "$tmp/use" 2> /dev/null && chmod +x "$tmp/use" || r=1
timeout --signal=KILL 10 "$tmp/use" > /dev/null 2>&1
[ $? -eq 42 ] || r=1
say infix_keeps_var_of_used_file $r
# the var line of such a file is read as the compiler reads it. $1 is the
# name of the check, $2 the text of the file, in which the var must be
# declared: the line that sets it must stay
keeps() {
    printf '%b' "$2" > "$tmp/$1_lib.ai"
    printf 'use "%s"\nshared=42\nif shared\nsys exit 1\nend\n' "$tmp/$1_lib.ai" > "$tmp/$1.ai"
    build/tools/infix "$tmp/$1.ai" "$tmp/$1.out.ai" 2> /dev/null &&
        cmp -s "$tmp/$1.ai" "$tmp/$1.out.ai" &&
        "$ailc" < "$tmp/$1.ai" > /dev/null 2>&1
    say "infix_$1" $?
}
keeps var_after_tab '\tvar shared\n'
keeps var_before_comment 'var other shared#set by the program\n'
# a string that goes on over the end of a line is no use and no var, also
# behind a backslash at the end of a line and after a quote in a comment
keeps string_over_lines 'data s "a\\\nvar other\nuse \\"none.ai\\"" 0 # "\nvar shared\n'
# and so is a var of a file named on the command line, for a source that
# is itself named by that file: without it the write is folded away
r=0
build/tools/infix tests/infix/part.ai "$tmp/part.ai" tests/infix/part_decl.ai 2> /dev/null &&
    cmp -s "$tmp/part.ai" tests/infix/part.ai || r=1
build/tools/infix tests/infix/part.ai "$tmp/part0.ai" 2> "$tmp/said" &&
    [ "$(cat "$tmp/said")" = "spelled 0, loops 0, folded 1" ] || r=1
timeout --signal=KILL 10 "$ailc" < tests/infix/part_decl.ai > "$tmp/part" 2> /dev/null && chmod +x "$tmp/part" || r=1
timeout --signal=KILL 10 "$tmp/part" > /dev/null 2>&1
[ $? -eq 7 ] || r=1
say infix_keeps_var_of_named_file $r
exit $fail

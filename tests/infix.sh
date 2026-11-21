#!/bin/sh
# Check tools/infix.aiw, built as build/tools/infix, which rewrites
# statements as expressions: tests/infix/in.aiw must become
# tests/infix/out.aiw, byte for byte; that result must be left as it is
# when rewritten again; and both programs must compile and exit alike,
# with the same output. tests/infix/long.aiw has two assignments in place
# that are too long for one line: it must become tests/infix/long.out.aiw,
# the same program. tests/infix/edge.aiw has the lines at the edges of the
# rules (separators, CR, comments, the limit of 100 bytes) and must become
# tests/infix/edge.out.aiw. The three .out.aiw files are what the Python
# script made that the tool was ported from, indented since by
# build/tools/indent, which changed no other byte: the tool writes its
# result indented. tests/infix/in.aiw has no indentation; indented first,
# it must give the same result. The tool must say what it
# did, and fail with a message without its two files or its input.
# A var declared in a file the source names with use (tests/infix/use.aiw)
# or in a file named after the two (tests/infix/part.aiw) is not folded,
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
build/tools/infix tests/infix/in.aiw "$tmp/out.aiw" 2> "$tmp/said" &&
    cmp -s "$tmp/out.aiw" tests/infix/out.aiw &&
    [ "$(cat "$tmp/said")" = "spelled 20, loops 1, folded 5" ]
say infix_rewrites $?
build/tools/infix tests/infix/out.aiw "$tmp/again.aiw" 2> "$tmp/said" &&
    cmp -s "$tmp/again.aiw" tests/infix/out.aiw &&
    [ "$(cat "$tmp/said")" = "spelled 0, loops 0, folded 0" ]
say infix_rewritten_stays $?
# the source indented gives the same result, and the result is indented
# as build/tools/indent has it
cp tests/infix/in.aiw "$tmp/dented.aiw" && build/tools/indent "$tmp/dented.aiw" &&
    ! cmp -s "$tmp/dented.aiw" tests/infix/in.aiw &&
    build/tools/infix "$tmp/dented.aiw" "$tmp/dout.aiw" 2> "$tmp/said" &&
    cmp -s "$tmp/dout.aiw" tests/infix/out.aiw &&
    [ "$(cat "$tmp/said")" = "spelled 20, loops 1, folded 5" ] &&
    build/tools/indent --check "$tmp/dout.aiw" > /dev/null
say infix_indented $?
r=0
for f in in out; do
    timeout --signal=KILL 10 "$ailc" < tests/infix/$f.aiw > "$tmp/$f" 2> /dev/null && chmod +x "$tmp/$f" || r=1
    timeout --signal=KILL 10 "$tmp/$f" > "$tmp/$f.txt" 2> /dev/null
    echo $? > "$tmp/$f.code"
done
cmp -s "$tmp/in.txt" "$tmp/out.txt" || r=1
cmp -s "$tmp/in.code" "$tmp/out.code" || r=1
[ "$(cat "$tmp/in.code")" = 6 ] || r=1
say infix_same_program $r
r=0
build/tools/infix tests/infix/long.aiw "$tmp/long.out.aiw" 2> /dev/null &&
    cmp -s "$tmp/long.out.aiw" tests/infix/long.out.aiw || r=1
for f in long long.out; do
    timeout --signal=KILL 10 "$ailc" < tests/infix/$f.aiw > "$tmp/$f" 2> /dev/null && chmod +x "$tmp/$f" || r=1
    timeout --signal=KILL 10 "$tmp/$f" > /dev/null 2>&1
    [ $? -eq 16 ] || r=1
done
say infix_long_lines_stay_two $r
build/tools/infix tests/infix/edge.aiw "$tmp/edge.out.aiw" 2> /dev/null &&
    cmp -s "$tmp/edge.out.aiw" tests/infix/edge.out.aiw
say infix_edges $?
r=0
build/tools/infix tests/infix/in.aiw > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "usage: infix in.aiw out.aiw [vars.aiw ...]" ] || r=1
build/tools/infix "$tmp/none.aiw" "$tmp/o.aiw" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "infix: cannot read $tmp/none.aiw" ] || r=1
[ ! -e "$tmp/o.aiw" ] || r=1
build/tools/infix tests/infix/in.aiw "$tmp/no/dir/o.aiw" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "infix: cannot write $tmp/no/dir/o.aiw" ] || r=1
printf 'use "%s/none.aiw"\nx=1\n' "$tmp" > "$tmp/uses.aiw"
build/tools/infix "$tmp/uses.aiw" "$tmp/o.aiw" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "infix: cannot read $tmp/none.aiw" ] || r=1
[ ! -e "$tmp/o.aiw" ] || r=1
say infix_errors $r
# a var of a file that the source names with use is a var: the line that
# sets it stays, and the program gives what the function reads, 42
r=0
build/tools/infix tests/infix/use.aiw "$tmp/use.aiw" 2> "$tmp/said" &&
    cmp -s "$tmp/use.aiw" tests/infix/use.aiw &&
    [ "$(cat "$tmp/said")" = "spelled 0, loops 0, folded 0" ] || r=1
timeout --signal=KILL 10 "$ailc" < "$tmp/use.aiw" > "$tmp/use" 2> /dev/null && chmod +x "$tmp/use" || r=1
timeout --signal=KILL 10 "$tmp/use" > /dev/null 2>&1
[ $? -eq 42 ] || r=1
say infix_keeps_var_of_used_file $r
# the var line of such a file is read as the compiler reads it. $1 is the
# name of the check, $2 the text of the file, in which the var must be
# declared: the line that sets it must stay
keeps() {
    printf '%b' "$2" > "$tmp/$1_lib.aiw"
    printf 'use "%s"\nshared=42\nif shared\n\tsys exit 1\nend\n' "$tmp/$1_lib.aiw" > "$tmp/$1.aiw"
    build/tools/infix "$tmp/$1.aiw" "$tmp/$1.out.aiw" 2> /dev/null &&
        cmp -s "$tmp/$1.aiw" "$tmp/$1.out.aiw" &&
        "$ailc" < "$tmp/$1.aiw" > /dev/null 2>&1
    say "infix_$1" $?
}
keeps var_after_tab '\tvar shared\n'
keeps var_before_comment 'var other shared#set by the program\n'
# a string that goes on over the end of a line is no use and no var, also
# behind a backslash at the end of a line and after a quote in a comment
keeps string_over_lines 'data s "a\\\nvar other\nuse \\"none.aiw\\"" 0 # "\nvar shared\n'
# the path of a use has no escapes: one that ends with a backslash ends at
# the quote behind it, its file is read, and the line after is a line
r=0
printf 'var other\n' > "$tmp/more\\"
printf 'use "%s/more\\"\nvar shared\n' "$tmp" > "$tmp/back\\"
printf 'use "%s/back\\"\nshared=42\nif shared\n\tsys exit 1\nend\n' "$tmp" > "$tmp/bs.aiw"
build/tools/infix "$tmp/bs.aiw" "$tmp/bs.out.aiw" 2> /dev/null &&
    cmp -s "$tmp/bs.aiw" "$tmp/bs.out.aiw" &&
    "$ailc" < "$tmp/bs.aiw" > /dev/null 2>&1 || r=1
say infix_use_path_ends_with_backslash $r
# and so is a var of a file named on the command line, for a source that
# is itself named by that file: without it the write is folded away
r=0
build/tools/infix tests/infix/part.aiw "$tmp/part.aiw" tests/infix/part_decl.aiw 2> /dev/null &&
    cmp -s "$tmp/part.aiw" tests/infix/part.aiw || r=1
build/tools/infix tests/infix/part.aiw "$tmp/part0.aiw" 2> "$tmp/said" &&
    [ "$(cat "$tmp/said")" = "spelled 0, loops 0, folded 1" ] || r=1
timeout --signal=KILL 10 "$ailc" < tests/infix/part_decl.aiw > "$tmp/part" 2> /dev/null && chmod +x "$tmp/part" || r=1
timeout --signal=KILL 10 "$tmp/part" > /dev/null 2>&1
[ $? -eq 7 ] || r=1
say infix_keeps_var_of_named_file $r
exit $fail

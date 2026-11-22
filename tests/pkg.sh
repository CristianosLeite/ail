#!/bin/sh
# usage: tests/pkg.sh      (AILC names the compiler, default build/ailc)
#
# The packages of use, which tests/run.sh cannot express since it gives
# the compiler no arguments. The sources are under tests/pkg: app, the
# directory the compiler runs in, and the packages one and two beside it.
# A compiler or program still running after 10 seconds is killed, which
# fails the case.
cd "$(dirname "$0")/.." || exit 1
top=$PWD
case ${AILC:-build/ailc} in
    /*) ailc=$AILC ;;
    *) ailc=$top/${AILC:-build/ailc} ;;
esac
ailc="timeout --signal=KILL 10 $ailc"
mkdir -p build/tests
tmp=$(mktemp -d "$top/build/tests/pkg.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
cd tests/pkg/app || exit 1
fail=0

# runs <name> <source> <output> [argument...]: the source compiles with
# the arguments and the program prints the output
runs() {
    name=$1 src=$2 want=$3
    shift 3
    if $ailc "$@" < "$src" > "$tmp/prog" 2> "$tmp/err" && [ ! -s "$tmp/err" ] &&
        chmod +x "$tmp/prog" && [ "$(timeout --signal=KILL 10 "$tmp/prog")" = "$want" ]
    then echo "ok   $name"
    else echo "FAIL $name"; fail=1
    fi
}
# fails <name> <source> <status> <line> [argument...]: the compiler ends
# with the status, writes nothing to stdout and the one line to stderr
fails() {
    name=$1 src=$2 st=$3 want=$4
    shift 4
    $ailc "$@" < "$src" > "$tmp/prog" 2> "$tmp/err"
    if [ $? -eq "$st" ] && [ ! -s "$tmp/prog" ] && [ "$(cat "$tmp/err")" = "$want" ] &&
        [ $(wc -l < "$tmp/err") -eq 1 ]
    then echo "ok   $name"
    else echo "FAIL $name"; fail=1
    fi
}
all="ail=../../.. one=../one two=../two"
usage="ailc: usage: ailc [name=directory]... < source > executable"

# a file of a package, the files it names in its own package and in
# another, and a file used from two packages
runs pkg_use main.aiw "two is read
a of one
b of one
own of app
b of app
t of two" $all
runs pkg_library_once twice.aiw "once" $all
# a path from the root is in no package, and its library is still found
echo "use \"$top/tests/pkg/two/t.aiw\"" > "$tmp/abs.aiw"
runs pkg_absolute_path "$tmp/abs.aiw" "two is read" $all
# a directory may end in a slash and be the working directory
runs pkg_directory_forms main.aiw "two is read
a of one
b of one
own of app
b of app
t of two" ail=../../../ one=../one/ two=../two app=.

fails pkg_unknown unknown.aiw 1 "ailc: 1: unknown package three" $all
fails pkg_none_named unknown.aiw 1 "ailc: 1: unknown package three"
fails pkg_empty_path empty.aiw 1 "ailc: 1: syntax error" $all
fails pkg_missing_file missing.aiw 1 "ailc: 1: cannot read file ../one/src/none.aiw" $all
fails pkg_missing_file_slash missing.aiw 1 "ailc: 1: cannot read file ../one/src/none.aiw" one=../one//
fails pkg_error_inside inside.aiw 1 "ailc: ../one/src/bad.aiw:2: unknown statement" $all
# without the library as a package, lib/ is read from the working directory
fails pkg_library_not_named main.aiw 1 "ailc: 1: cannot read file lib/std/io.aiw" one=../one two=../two

fails pkg_arg_no_equals main.aiw 2 "$usage" one
fails pkg_arg_no_name main.aiw 2 "$usage" =../one
fails pkg_arg_no_directory main.aiw 2 "$usage" one=
fails pkg_arg_slash_in_name main.aiw 2 "$usage" a/b=../one
fails pkg_arg_colon_in_name main.aiw 2 "$usage" a:b=../one
fails pkg_arg_twice main.aiw 2 "$usage" one=../one one=../two
exit $fail

#!/bin/sh
# usage: tests/stage1.sh [name...]     (no names = every test and example)
#
# stage1 must behave exactly like stage0: for the source of each test, and
# with no names also for each example, both compilers must give the same
# stdout byte for byte, the same stderr and the same exit status.
# A compiler still running after $limit seconds is killed and fails the test,
# also when both do: a compiler only ever exits with 0, 1 or 2. With no
# names it also checks the fixed point: stage1 compiled by stage0
# (build/ailc1) and stage1 compiled by itself (build/ailc2) are one file.
cd "$(dirname "$0")/.." || exit 1
limit=10
mkdir -p build/tests
tmp=$(mktemp -d build/tests/stage1.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

# same <source file>
same() {
    timeout --signal=KILL $limit build/ailc < $1 > $tmp/a 2> $tmp/a.err
    a=$?
    timeout --signal=KILL $limit build/ailc1 < $1 > $tmp/b 2> $tmp/b.err
    [ $? -eq $a ] && [ $a -le 2 ] && cmp -s $tmp/a $tmp/b && cmp -s $tmp/a.err $tmp/b.err
}

check() {
    case $1 in
    fixed_point) cmp -s build/ailc1 build/ailc2; return;;
    examples/*) same $1; return;;
    esac
    if [ -f tests/$1.ai.sh ]
    then sh tests/$1.ai.sh > $tmp/src || return 1
    else cp tests/$1.ai $tmp/src || return 1
    fi
    same $tmp/src
}

[ $# -eq 0 ] && set -- $(ls tests | sed -n 's/\.ai\(\.sh\)\{0,1\}$//p' | sort -u) \
    examples/*.ai fixed_point
fail=0
for t; do
    if check $t
    then echo "ok   stage1 $t"
    else echo "FAIL stage1 $t"; fail=1
    fi
done
exit $fail

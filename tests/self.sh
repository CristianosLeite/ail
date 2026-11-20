#!/bin/sh
# usage: tests/self.sh [name...]     (no names = every test and example)
#
# The compiler checked against itself. build/ailc1 and build/ailc are the
# same source, stage1/ailc.ai, compiled by two compilers: the seed, and the
# compiler that the seed built. They are one program in two translations,
# so for the source of each test, and with no names also for each example,
# they must give the same stdout byte for byte, the same stderr and the
# same exit status; where they do not, the compiler has compiled itself
# wrongly. A compiler still running after $limit seconds is killed and
# fails the test, also when both do: a compiler only ever exits with 0, 1
# or 2. With no names it also checks the fixed point: build/ailc and
# build/ailc2, which build/ailc wrote from the same source, are one file.
cd "$(dirname "$0")/.." || exit 1
limit=10
mkdir -p build/tests
tmp=$(mktemp -d build/tests/self.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

# same <source file>
same() {
    timeout --signal=KILL $limit build/ailc1 < $1 > $tmp/a 2> $tmp/a.err
    a=$?
    timeout --signal=KILL $limit build/ailc < $1 > $tmp/b 2> $tmp/b.err
    [ $? -eq $a ] && [ $a -le 2 ] && cmp -s $tmp/a $tmp/b && cmp -s $tmp/a.err $tmp/b.err
}

check() {
    case $1 in
    fixed_point) cmp -s build/ailc build/ailc2; return;;
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
    then echo "ok   self $t"
    else echo "FAIL self $t"; fail=1
    fi
done
exit $fail

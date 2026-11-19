#!/bin/sh
# usage: tests/run.sh [name...]     (no names = every tests/*.ai)
# A test is tests/<name>.ai plus tests/<name>.out, the expected stdout.
# It passes when the program compiles, exits 0 and prints exactly that.
cd "$(dirname "$0")/.." || exit 1
out=build/tests
mkdir -p $out
[ $# -eq 0 ] && set -- $(basename -s .ai tests/*.ai)
fail=0
for t; do
    if build/ailc < tests/$t.ai > $out/$t && chmod +x $out/$t &&
       $out/$t > $out/$t.got && cmp -s $out/$t.got tests/$t.out
    then echo "ok   $t"
    else echo "FAIL $t"; fail=1
    fi
done
exit $fail

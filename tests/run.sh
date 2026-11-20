#!/bin/sh
# usage: tests/run.sh [name...]     (no names = every test)
#
# A test is a set of files named tests/<name>.*:
#   .ai     the program (or .ai.sh, a script that prints the program)
#   .out    expected stdout of the compiled program
#   .code   expected exit status of the compiled program (default 0)
#   .err    expected compiler stderr; the compiler must then exit 1
# A test has either .err (compiling must fail) or .out (program must run).
# A program still running after $limit seconds is killed and fails its test,
# whatever status the test expects: the status is taken from a file that is
# only written when the program ends by itself.
cd "$(dirname "$0")/.." || exit 1
out=build/tests
limit=10
mkdir -p $out
[ $# -eq 0 ] && set -- $(ls tests | sed -n 's/\.ai\(\.sh\)\{0,1\}$//p' | sort -u)

check() {
    if [ -f tests/$1.ai.sh ]
    then sh tests/$1.ai.sh > $out/$1.ai || return 1
    else cp tests/$1.ai $out/$1.ai || return 1
    fi
    build/ailc < $out/$1.ai > $out/$1 2> $out/$1.err
    rc=$?
    if [ -f tests/$1.err ]; then
        [ $rc -eq 1 ] && cmp -s $out/$1.err tests/$1.err
        return
    fi
    [ $rc -eq 0 ] && [ ! -s $out/$1.err ] || return 1
    chmod +x $out/$1
    rm -f $out/$1.rc
    timeout $limit sh -c '"$1" > "$1.got"; echo $? > "$1.rc"' sh $out/$1
    [ -f $out/$1.rc ] || return 1
    rc=$(cat $out/$1.rc)
    want=0
    [ -f tests/$1.code ] && want=$(cat tests/$1.code)
    [ $rc -eq "$want" ] && cmp -s $out/$1.got tests/$1.out
}

fail=0
for t; do
    if check $t
    then echo "ok   $t"
    else echo "FAIL $t"; fail=1
    fi
done
exit $fail

#!/bin/sh
# Fuzzing: give the compiler sources made by random edits of the tests, the
# examples and the library. Whatever the source, a compiler ends in one of
# two ways: exit status 0, nothing on stderr and an executable on stdout,
# or exit status 1, nothing on stdout and one line "ailc: ..." on stderr.
# A signal, a deadline, another status or anything else written fails.
# The same source also goes to a second translation of the compiler,
# build/ailc1, which the seed compiled from the same compiler/ailc.aw: the
# two must give the same status, output bytes and message, or the compiler
# has compiled itself wrongly.
# Usage: tests/fuzz.sh [count [seed]]     (default 300 sources, seed 1)
# The compiled programs are never run: an edited program may do anything.
# A source that fails is kept in build/fuzz/. FUZZ_A and FUZZ_B name other
# compilers: FUZZ_B is the one whose behaviour is checked.
set -u
cd "$(dirname "$0")/.."
count=${1:-300}
seed=${2:-1}
a=${FUZZ_A:-build/ailc1}
b=${FUZZ_B:-build/ailc}
limit=10
mkdir -p build/fuzz
out=$(mktemp -d build/fuzz/run.XXXXXX) || exit 1
trap 'rm -rf "$out"' EXIT
trap 'exit 1' HUP INT TERM
ls tests/*.aw examples/*.aw lib/*.aw tests/lib/*.aw > "$out/corpus"
n=$(wc -l < "$out/corpus")

# print source number $1: one corpus file after one to four random edits
mutate() {
    LC_ALL=C awk -v seed="$seed" -v i="$1" -v n="$n" -v corpus="$out/corpus" '
    function rnd(k) { return int(rand() * k) }
    function slurp(path,   s, l, first) {
        s = ""; first = 1
        while ((getline l < path) > 0) { s = s (first ? "" : "\n") l; first = 0 }
        close(path)
        return s "\n"
    }
    function pick(   k, j, p) {
        k = rnd(n) + 1; j = 0
        while ((getline p < corpus) > 0) if (++j == k) break
        close(corpus)
        return p
    }
    BEGIN {
        srand(seed * 1000003 + i)
        nw = split("a+1 (b)*2 x= x+= x=1 n-1 1<<2 (( ) a<=b x==y + * a=a+1 while " \
            "sys set add sub mul div mod and or xor shl shr eq ne lt le gt ge " \
            "slt sdiv sar buf data var const local len at load loadb load2 load4 " \
            "store storeb store2 store4 label jmp jz jnz jeq jlt jsge if ifz ifeq " \
            "else end fn ret tail call ref callp use alloc free args as itof fadd " \
            "xadd cas a b c x y n p 0 1 7 255 4096 -1 0x10 0xffffffffffffffff " \
            "18446744073709551616 0x11111111111111111 -9223372036854775809 " \
            "\"s\" \"\\n\" \"\\x4\" \"\\q\" # \" - _", w, " ")
        s = slurp(pick())
        edits = rnd(4) + 1
        for (e = 0; e < edits; e++) {
            len = length(s); at = rnd(len + 1); op = rnd(8)
            if (op == 0) {                      # a token goes in
                s = substr(s, 1, at) " " w[rnd(nw) + 1] " " substr(s, at + 1)
            } else if (op == 1) {               # a span goes out
                s = substr(s, 1, at) substr(s, at + 1 + rnd(20) + 1)
            } else if (op == 2) {               # a byte is replaced, by any byte but NUL
                s = substr(s, 1, at) sprintf("%c", rnd(255) + 1) substr(s, at + 2)
            } else if (op == 3) {               # the source ends early
                s = substr(s, 1, at)
            } else if (op == 4) {               # a span is repeated elsewhere
                span = substr(s, at + 1, rnd(40) + 1); to = rnd(len + 1)
                s = substr(s, 1, to) span substr(s, to + 1)
            } else if (op == 5) {               # a piece of another source follows
                t = slurp(pick()); from = rnd(length(t) + 1)
                s = s substr(t, from + 1, rnd(200) + 1)
            } else if (op == 6) {               # a line end goes in or out
                if (rnd(2)) s = substr(s, 1, at) "\n" substr(s, at + 1)
                else sub(/\n/, " ", s)
            } else {                            # a space goes out: tokens touch
                sub(/ /, "", s)
            }
        }
        printf "%s", s
    }'
}

# proper <status>: the second compiler ended in one of the two ways
proper() {
    case $1 in
    0) [ ! -s "$out/b.err" ] && [ -s "$out/b.out" ];;
    1) [ ! -s "$out/b.out" ] && [ "$(wc -l < "$out/b.err")" -eq 1 ] &&
        grep -q '^ailc: .' "$out/b.err";;
    *) false;;
    esac
}

fail=0
i=1
while [ "$i" -le "$count" ]; do
    mutate "$i" > "$out/src"
    timeout --signal=KILL $limit $a < "$out/src" > "$out/a.out" 2> "$out/a.err"; ra=$?
    timeout --signal=KILL $limit $b < "$out/src" > "$out/b.out" 2> "$out/b.err"; rb=$?
    if [ $ra -ne $rb ] || ! proper $rb ||
        ! cmp -s "$out/a.out" "$out/b.out" || ! cmp -s "$out/a.err" "$out/b.err"; then
        cp "$out/src" "build/fuzz/seed$seed-$i.aw"
        echo "FAIL fuzz $i (kept as build/fuzz/seed$seed-$i.aw)"
        fail=1
    fi
    i=$((i + 1))
done
[ $fail -eq 0 ] && echo "ok   fuzz $count sources, seed $seed"
exit $fail

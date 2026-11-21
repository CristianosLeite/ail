#!/bin/sh
# Check the algorithm programs of examples/ against references that share
# nothing with them. A program reads five words (bench/algo/harness.aw):
# seed, count, shape, runs and mode, and writes its input in mode 1, its
# result in mode 2 and a checksum of the result with its times in mode 0.
# For the counts 0, 1, 2, 3 and 1000 in each of the four shapes:
#   a sort     its result must be what sort(1) makes of its input
#   checksum   mode 0 must write the checksum of the result, computed
#              here, and 8 bytes for each of its kernels
# Words are compared as 16 hexadecimal digits, which sort as the numbers
# do. Two runs each, so that a program which does not start again from
# its input is seen. The same is asked of the C programs of bench/ if
# there is a gcc; without one that part is skipped.
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/tests
tmp=$(mktemp -d build/tests/algo.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0

sorts='quicksort'

# words n ...: each number as 8 bytes, the lowest first
words() {
    for x; do
        i=0
        while [ $i -lt 64 ]; do
            printf "\\$(printf '%03o' $((x >> i & 255)))"
            i=$((i + 8))
        done
    done
}

# run program count shape mode: what it writes, a word a line
run() {
    words 7 "$2" "$3" 2 "$4" | timeout --signal=KILL 10 "$1" | od -An -tx8 -w8 -v | tr -d ' '
}

# checksum file: h = h * 31 + word over its lines, as 16 digits
checksum() {
    h=0
    while read -r w; do
        h=$((h * 31 + (0x${w%????????} << 32 | 0x${w#????????})))
    done < "$1"
    printf '%08x%08x\n' $((h >> 32 & 0xffffffff)) $((h & 0xffffffff))
}

# summed program count shape kernels: mode 0 gives the checksum of
# $tmp/res and that many times
summed() {
    run "$1" "$2" "$3" 0 > "$tmp/sum"
    [ "$(sed -n 1p "$tmp/sum")" = "$(checksum "$tmp/res")" ] &&
        [ "$(wc -l < "$tmp/sum")" -eq $(($4 + 1)) ]
}

# sorted program: a sort
sorted() {
    for s in 0 1 2 3; do
        for n in 0 1 2 3 1000; do
            run "$1" $n $s 1 > "$tmp/in"
            run "$1" $n $s 2 > "$tmp/res"
            [ "$(wc -l < "$tmp/in")" -eq $n ] || return 1
            LC_ALL=C sort "$tmp/in" | cmp -s - "$tmp/res" || return 1
            summed "$1" $n $s 1 || return 1
        done
    done
}

# each kind program ...: check the programs, and their C forms
each() {
    kind=$1
    shift
    for p; do
        if $kind "build/$p"
        then echo "ok   algo $p"
        else echo "FAIL algo $p"; fail=1
        fi
        [ -n "$cc" ] || continue
        if gcc -O1 -o "$tmp/$p" "bench/$p.c" 2> /dev/null && $kind "$tmp/$p"
        then echo "ok   algo $p.c"
        else echo "FAIL algo $p.c"; fail=1
        fi
    done
}

cc=$(command -v gcc)
[ -n "$cc" ] || echo "skip algo C programs: no gcc"
each sorted $sorts

# anything but five whole words is refused
r=0
for p in $sorts; do
    printf 12345678 | "build/$p" > "$tmp/res"
    [ $? -eq 1 ] && [ ! -s "$tmp/res" ] || r=1
    words 7 268435456 0 1 0 | "build/$p" > "$tmp/res"
    [ $? -eq 1 ] && [ ! -s "$tmp/res" ] || r=1
done
if [ $r -eq 0 ]
then echo "ok   algo refuses"
else echo "FAIL algo refuses"; fail=1
fi
exit $fail

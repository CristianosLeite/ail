#!/bin/sh
# Check that every program in bench/ behaves like the example it mirrors:
# same output and exit status for the same input. Needs gcc and rustc
# besides as and ld, so it is not part of `make test`.
set -u
cd "$(dirname "$0")/.."
make -s all >/dev/null || exit 1
t=$(mktemp -d build/bench.XXXXXX) || exit 1
trap 'rm -rf "$t"' EXIT
f=0
for src in examples/*.ai; do
    n=$(basename "$src" .ai)
    gcc -O1 -w -o "$t/$n.c.bin" "bench/$n.c" &&
        rustc -O -o "$t/$n.rs.bin" "bench/$n.rs" 2>/dev/null &&
        as -o "$t/$n.o" "bench/$n.s" && ld -o "$t/$n.s.bin" "$t/$n.o" ||
        { echo "FAIL $n: build"; f=1; continue; }
    for input in '' 'hi\n'; do
        printf "$input" | "build/$n" > "$t/ref"; r=$?
        for l in c rs s; do
            printf "$input" | "$t/$n.$l.bin" > "$t/got"; g=$?
            if cmp -s "$t/ref" "$t/got" && [ "$r" = "$g" ]; then
                echo "ok   $n.$l"
            else
                echo "FAIL $n.$l"; f=1
            fi
        done
    done
done
exit $f

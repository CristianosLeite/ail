#!/bin/sh
# Check what the Makefile does when an example fails to compile: the build
# must fail, and fail again when it is repeated; an executable from an
# earlier build must survive untouched; and no temporary file may be left.
# It runs make in a scratch copy with the compiler that is already built.
set -u
cd "$(dirname "$0")/.."
mkdir -p build/tests
d=$(mktemp -d build/tests/make.XXXXXX) || exit 1
trap 'rm -rf "$d"' EXIT
trap 'exit 1' HUP INT TERM
fail=0

say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
# the files that the build of an example could leave behind, besides the target
leftovers() {
    ls "$d/build" | grep -v -e '^ailc$' -e '^good$' -e '^good\.saved$' | wc -l
}

mkdir "$d/stage0" "$d/examples" "$d/build"
cp -p Makefile "$d/"
cp -p stage0/ailc.s "$d/stage0/"
cp -p build/ailc "$d/build/"            # newer than its source, so make keeps it

# a good example builds and runs
printf 'sys exit 7\n' > "$d/examples/good.ai"
make -s -C "$d" build/good > /dev/null 2>&1
"$d/build/good"
[ $? -eq 7 ] && [ "$(leftovers)" -eq 0 ]
say make_good_example $?

# its source becomes faulty: the build fails twice, the old executable stays
cp -p "$d/build/good" "$d/build/good.saved"
touch -d '2001-01-01 00:00:00' "$d/build/good"
printf 'frob\n' > "$d/examples/good.ai"
r=0
make -s -C "$d" build/good > /dev/null 2>&1 && r=1
make -s -C "$d" build/good > /dev/null 2>&1 && r=1
cmp -s "$d/build/good" "$d/build/good.saved" || r=1
[ "$(leftovers)" -eq 0 ] || r=1
say make_failed_build_keeps_old_target $r

# a faulty example that was never built: no target appears
printf 'frob\n' > "$d/examples/bad.ai"
r=0
make -s -C "$d" build/bad > /dev/null 2>&1 && r=1
make -s -C "$d" build/bad > /dev/null 2>&1 && r=1
[ ! -e "$d/build/bad" ] || r=1
[ "$(leftovers)" -eq 0 ] || r=1
say make_failed_build_leaves_no_target $r

# once the source is right again, the build works
printf 'sys exit 9\n' > "$d/examples/good.ai"
r=0
make -s -C "$d" build/good > /dev/null 2>&1 || r=1
"$d/build/good"
[ $? -eq 9 ] || r=1
say make_repaired_example $r

exit $fail

#!/bin/sh
# Check what the Makefile does when an example fails to compile: the build
# must fail, and fail again when it is repeated; an executable from an
# earlier build must survive untouched; and no temporary file may be left.
# The same for a tool, tools/<name>.ai, which another rule builds.
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
    ls "$d/build" | grep -v -e '^ailc[01]\{0,1\}$' -e '^good$' -e '^good\.saved$' -e '^tools$' | wc -l
}
# the same in build/tools, where only the tool t may be
toolleftovers() {
    ls "$d/build/tools" 2> /dev/null | grep -v -e '^t$' | wc -l
}

mkdir "$d/compiler" "$d/seed" "$d/tools" "$d/examples" "$d/build"
cp -p Makefile "$d/"
cp -p compiler/*.ai "$d/compiler/"
cp -p seed/MANIFEST "$d/seed/"
cp -p tools/seed.sh "$d/tools/"
# the seed and the compilers built from it, each newer than what it is
# made from, so make keeps them
cp -p build/ailc0 build/ailc1 build/ailc "$d/build/"

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

# a tool builds and runs; when its source becomes faulty the build fails
# twice and the old executable stays
printf 'sys exit 5\n' > "$d/tools/t.ai"
r=0
make -s -C "$d" build/tools/t > /dev/null 2>&1 || r=1
"$d/build/tools/t"
[ $? -eq 5 ] || r=1
cp -p "$d/build/tools/t" "$d/build/t.saved"
touch -d '2001-01-01 00:00:00' "$d/build/tools/t"
printf 'frob\n' > "$d/tools/t.ai"
make -s -C "$d" build/tools/t > /dev/null 2>&1 && r=1
make -s -C "$d" build/tools/t > /dev/null 2>&1 && r=1
cmp -s "$d/build/tools/t" "$d/build/t.saved" || r=1
[ "$(toolleftovers)" -eq 0 ] || r=1
say make_failed_tool_keeps_old_target $r

# a faulty tool that was never built: no target appears
rm -f "$d/build/tools/t" "$d/build/t.saved"
r=0
make -s -C "$d" build/tools/t > /dev/null 2>&1 && r=1
make -s -C "$d" build/tools/t > /dev/null 2>&1 && r=1
[ ! -e "$d/build/tools/t" ] || r=1
[ "$(toolleftovers)" -eq 0 ] || r=1
say make_failed_tool_leaves_no_target $r

exit $fail

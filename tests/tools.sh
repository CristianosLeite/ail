#!/bin/sh
# Check the tools written in AIL, tools/<name>.aw, built as
# build/tools/<name> by make tools.
# - The prerequisites that the Makefile gives a tool must be its source and
#   every file that source reaches with use, no more and no less: an edit
#   of a shared file must build its callers again.
# - hashcol must print the pair of names that the test hash_collision_prefix
#   declares, so that the test still has two names in one bucket.
# - fuse must make tests/fuse/out.aw of tests/fuse/in.aw, byte for byte,
#   which is what the Python tool it was ported from made of it, indented
#   since by build/tools/indent, and of that source indented too, and say
#   what it did; leave that result and tests/fuse/same.aw as they are; and
#   both programs must compile and exit alike. Without its two files it
#   must fail with a message, and so for a file it cannot read.
# - perf needs gcc and rustc to measure, so only its refusals are checked:
#   a program it does not know and a CPU that is no number.
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/tests
tmp=$(mktemp -d build/tests/tools.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0
say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

# the files a source reaches with use, itself included, one a line
closure() {
    todo=$1
    seen=
    while [ -n "$todo" ]; do
        set -- $todo
        [ $# -gt 0 ] || break
        f=$1
        shift
        todo=$*
        case " $seen " in *" $f "*) continue ;; esac
        seen="$seen $f"
        [ -f "$f" ] || continue
        todo="$todo $(sed -n 's/^use "\(.*\)".*/\1/p' "$f" | tr '\n' ' ')"
    done
    printf '%s\n' $seen | sort
}

make -pn tools 2> /dev/null > "$tmp/db"
for src in tools/*.aw; do
    [ -f "$src" ] || continue
    name=$(basename "$src" .aw)
    closure "$src" > "$tmp/uses"
    sed -n "s|^build/tools/$name: ||p" "$tmp/db" | tr ' ' '\n' |
        grep -v -e '^build/ailc$' -e '^$' | sort > "$tmp/deps"
    cmp -s "$tmp/uses" "$tmp/deps"
    say "tools_deps $name" $?
done

r=0
timeout --signal=KILL 10 build/tools/hashcol > "$tmp/pair" 2> /dev/null || r=1
[ "$(wc -l < "$tmp/pair")" -eq 1 ] || r=1
set -- $(cat "$tmp/pair")
[ $# -eq 2 ] || r=1
for n in "$@"; do
    grep -q "^data $n " tests/hash_collision_prefix.aw || r=1
done
# the long name starts with the short one
case "${2:-}" in "${1:-x}"?*) ;; *) r=1 ;; esac
say tools_hashcol $r

build/tools/fuse tests/fuse/in.aw "$tmp/out.aw" 2> "$tmp/said" &&
    cmp -s "$tmp/out.aw" tests/fuse/out.aw &&
    [ "$(cat "$tmp/said")" = "fused 6 blocks 7" ]
say tools_fuse_rewrites $?
build/tools/fuse tests/fuse/out.aw "$tmp/again.aw" 2> "$tmp/said" &&
    cmp -s "$tmp/again.aw" tests/fuse/out.aw &&
    [ "$(cat "$tmp/said")" = "fused 0 blocks 0" ]
say tools_fuse_rewritten_stays $?
# the source indented, where every line of a function starts with a tab,
# gives the same result, and the result is indented
cp tests/fuse/in.aw "$tmp/dented.aw" && build/tools/indent "$tmp/dented.aw" &&
    ! cmp -s "$tmp/dented.aw" tests/fuse/in.aw &&
    build/tools/fuse "$tmp/dented.aw" "$tmp/dout.aw" 2> "$tmp/said" &&
    cmp -s "$tmp/dout.aw" tests/fuse/out.aw &&
    [ "$(cat "$tmp/said")" = "fused 6 blocks 7" ] &&
    build/tools/indent --check "$tmp/dout.aw" > /dev/null
say tools_fuse_indented $?
# the path of a use has no escapes: one that ends with a backslash opens
# no string, and the indented lines behind it are read like any others
printf 'use "a\\"\nfn f a b\n\tlt a b as c\n\tjz c l\n\tret 1\n\tlabel l\n\tret 0\nend\n' > "$tmp/bs.aw"
build/tools/fuse "$tmp/bs.aw" "$tmp/bs.out.aw" 2> "$tmp/said" &&
    [ "$(cat "$tmp/said")" = "fused 1 blocks 1" ] &&
    [ "$(cat "$tmp/bs.out.aw")" = "$(printf 'use "a\\"\nfn f a b\n\tiflt a b\n\t\tret 1\n\tend\n\tret 0\nend')" ]
say tools_fuse_use_path_ends_with_backslash $?
build/tools/fuse tests/fuse/same.aw "$tmp/same.aw" 2> /dev/null &&
    cmp -s "$tmp/same.aw" tests/fuse/same.aw
say tools_fuse_leaves_alone $?
r=0
for f in in out; do
    timeout --signal=KILL 10 build/ailc < tests/fuse/$f.aw > "$tmp/$f" 2> /dev/null && chmod +x "$tmp/$f" || r=1
    timeout --signal=KILL 10 "$tmp/$f" > /dev/null 2>&1
    echo $? > "$tmp/$f.code"
done
cmp -s "$tmp/in.code" "$tmp/out.code" || r=1
[ "$(cat "$tmp/in.code")" = 27 ] || r=1
say tools_fuse_same_program $r
r=0
build/tools/fuse tests/fuse/in.aw > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "usage: fuse in.aw out.aw" ] || r=1
build/tools/fuse "$tmp/none.aw" "$tmp/o.aw" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "fuse: cannot read $tmp/none.aw" ] || r=1
[ ! -e "$tmp/o.aw" ] || r=1
printf 'label\n' > "$tmp/bad.aw"
build/tools/fuse "$tmp/bad.aw" "$tmp/o.aw" > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "fuse: a label or a jump without a name" ] || r=1
[ ! -e "$tmp/o.aw" ] || r=1
say tools_fuse_errors $r

r=0
build/tools/perf no-such-program > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "perf: unknown program no-such-program" ] || r=1
build/tools/perf --cpu two > /dev/null 2> "$tmp/said"
[ $? -eq 1 ] && [ "$(cat "$tmp/said")" = "perf: usage: perf [--cpu N] [--quick] [--qsort] [--places] [name ...]" ] || r=1
say tools_perf_errors $r

exit $fail

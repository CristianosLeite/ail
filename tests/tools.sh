#!/bin/sh
# Check the tools written in AIL, tools/<name>.ai, built as
# build/tools/<name> by make tools.
# - The prerequisites that the Makefile gives a tool must be its source and
#   every file that source reaches with use, no more and no less: an edit
#   of a shared file must build its callers again.
# - hashcol must print the pair of names that the test hash_collision_prefix
#   declares, so that the test still has two names in one bucket.
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
for src in tools/*.ai; do
    [ -f "$src" ] || continue
    name=$(basename "$src" .ai)
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
    grep -q "^data $n " tests/hash_collision_prefix.ai || r=1
done
# the long name starts with the short one
case "${2:-}" in "${1:-x}"?*) ;; *) r=1 ;; esac
say tools_hashcol $r

exit $fail

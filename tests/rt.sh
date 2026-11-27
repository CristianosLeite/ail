#!/bin/sh
# Check the runtime beyond what its services do, which the tests rt_*
# run: how the compiler named by AILC (default build/ailc) puts it into
# an executable (docs/runtime.md), and that the library, the command
# ail and the tools ask their platform for nothing but through the
# runtime: no file of lib/, cli/ or tools/ has a sys statement.
set -u
cd "$(dirname "$0")/.." || exit 1
ailc=${AILC:-build/ailc}
mkdir -p build/tests
tmp=$(mktemp -d build/tests/rt.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0

say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

# an executable is the header, the code of the runtime, which ends where
# the code of a program stood in a line of the cache behind the header
# alone, and the program: the empty program is two instructions. Its
# first line would keep the stack, and does nothing in a program that
# never asks for it; a program that asks has it.
: | "$ailc" > "$tmp/empty" 2> /dev/null
r=0
all=$(wc -c < "$tmp/empty")
[ "$all" -gt 183 ] && [ $(( (all - 183) % 64 )) -eq 0 ] || r=1
[ "$(od -An -tu8 -j24 -N8 "$tmp/empty" | tr -d ' ')" -eq 176 ] || r=1
[ "$(od -An -tx1 -j176 -N10 "$tmp/empty" | tr -d ' \n')" = 660f1f84000000000090 ] || r=1
chmod +x "$tmp/empty"
"$tmp/empty" || r=1
printf 'args as p\n' | "$ailc" > "$tmp/args" 2> /dev/null
[ "$(od -An -tx1 -j176 -N3 "$tmp/args" | tr -d ' \n')" = 488d05 ] || r=1
[ "$(od -An -tx1 -j183 -N3 "$tmp/args" | tr -d ' \n')" = 488920 ] || r=1
# and the state of the runtime is memory of a program only if a service
# that keeps something there is called
mem() { od -An -tu8 -j160 -N8 "$1" | tr -d ' '; }
[ "$(mem "$tmp/empty")" -eq 0 ] || r=1
[ "$(mem "$tmp/args")" -gt 0 ] || r=1
printf 'rt write 1 "x"\nrt clock as t\n' | "$ailc" > "$tmp/clock" 2> /dev/null
[ "$(mem "$tmp/clock")" -gt 0 ] || r=1
printf 'buf b 16\nrt write 1 b 16\n' | "$ailc" > "$tmp/buf" 2> /dev/null
[ "$(mem "$tmp/buf")" -eq 16 ] || r=1
printf 'buf b 16\nalloc 8 as p\n' | "$ailc" > "$tmp/alloc" 2> /dev/null
[ "$(mem "$tmp/alloc")" -gt 16 ] || r=1
say rt_in_executable $r

# a program runs with no descriptor open, and says so by its status
printf 'rt write 1 "x" as n\nrt exit 0-n\n' | "$ailc" > "$tmp/closed" 2> /dev/null
chmod +x "$tmp/closed"
"$tmp/closed" <&- >&- 2>&-
[ $? -eq 9 ]
say rt_runs_without_descriptors $?

# the library is the same on every platform, and so are the command
# ail and the tools
for d in lib cli tools; do
    out=$(grep -n '^[[:space:]]*sys ' $(find $d -name '*.aiw') /dev/null)
    [ -z "$out" ]
    r=$?
    case $d in lib) say rt_library_has_no_sys $r ;; *) say rt_${d}_has_no_sys $r ;; esac
    [ $r -eq 0 ] || echo "$out" | sed 's/^/     /'
done

exit $fail

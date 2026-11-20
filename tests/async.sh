#!/bin/sh
# Check the programs of bench/async/, which use the async runtime as a
# program does, with arguments and other processes, which tests/run.sh
# cannot give a test:
# - timer prints its five lines, three of one task and two of the other,
#   and takes the 300 milliseconds of its timers, not their sum;
# - ping with its own server: 4 connections of 50 round trips, then 300
#   of 20, which all must finish while the others wait their turn;
# - echod as a process of its own, on a port the kernel chose, and ping
#   against it; the server is still there afterwards and is killed;
# - switch, mem and hop end and print figures of the right kind.
# The compiler is build/ailc, or the one named by AILC.
set -u
cd "$(dirname "$0")/.." || exit 1
ailc=${AILC:-build/ailc}
mkdir -p build/tests
tmp=$(mktemp -d build/tests/async.XXXXXX) || exit 1
srv=
trap '[ -n "$srv" ] && kill "$srv" 2> /dev/null; rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0
say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

r=0
for p in timer echod ping switch mem hop; do
    timeout --signal=KILL 10 "$ailc" < bench/async/$p.ai > "$tmp/$p" 2> "$tmp/err" &&
        [ ! -s "$tmp/err" ] && chmod +x "$tmp/$p" || r=1
done
say async_programs_compile $r
[ $r -eq 0 ] || exit 1

r=0
start=$(date +%s%N)
timeout --signal=KILL 10 "$tmp/timer" > "$tmp/out" || r=1
ms=$(( ($(date +%s%N) - start) / 1000000 ))
[ "$(sort "$tmp/out" | tr '\n' ' ')" = "100 100 100 150 150 " ] || r=1
[ "$(sed -n 1p "$tmp/out")" = 100 ] && [ "$(sed -n 2p "$tmp/out")" = 150 ] || r=1
[ $ms -ge 295 ] && [ $ms -lt 600 ] || r=1
say async_timer $r

r=0
timeout --signal=KILL 10 "$tmp/ping" 4 50 > "$tmp/out" || r=1
[ "$(cut -d' ' -f1-3 "$tmp/out")" = "4 50 200" ] || r=1
say async_ping_own_server $r

r=0
timeout --signal=KILL 10 "$tmp/ping" 300 20 > "$tmp/out" || r=1
[ "$(cut -d' ' -f1-3 "$tmp/out")" = "300 20 6000" ] || r=1
say async_ping_load $r

r=0
"$tmp/echod" 0 > "$tmp/port" &
srv=$!
n=0
while [ ! -s "$tmp/port" ] && [ $n -lt 50 ]; do sleep 0.1; n=$((n + 1)); done
port=$(cat "$tmp/port")
[ -n "$port" ] || r=1
timeout --signal=KILL 10 "$tmp/ping" 20 100 "$port" > "$tmp/out" || r=1
[ "$(cut -d' ' -f1-3 "$tmp/out")" = "20 100 2000" ] || r=1
timeout --signal=KILL 10 "$tmp/ping" 1 10 "$port" > "$tmp/out" || r=1
[ "$(cut -d' ' -f1-3 "$tmp/out")" = "1 10 10" ] || r=1
kill -0 "$srv" 2> /dev/null || r=1
kill "$srv" 2> /dev/null
wait "$srv" 2> /dev/null
srv=
# nobody listens there any more: every connection fails, status 1
timeout --signal=KILL 10 "$tmp/ping" 2 1 "$port" > /dev/null
[ $? -eq 1 ] || r=1
say async_echod $r

r=0
timeout --signal=KILL 10 "$tmp/switch" 100 100 > "$tmp/out" || r=1
[ "$(cut -d' ' -f1 "$tmp/out")" = 10000 ] || r=1
timeout --signal=KILL 10 "$tmp/mem" 20000 > "$tmp/out" || r=1
b=$(cat "$tmp/out")
[ "${b:-0}" -ge 200 ] && [ "${b:-0}" -le 600 ] || r=1
timeout --signal=KILL 10 "$tmp/hop" 200 > "$tmp/out" || r=1
[ "$(cut -d' ' -f1 "$tmp/out")" = 200 ] || r=1
timeout --signal=KILL 10 "$tmp/hop" 200 all > "$tmp/out" || r=1
[ "$(cut -d' ' -f1 "$tmp/out")" = 200 ] || r=1
say async_figures $r
exit $fail

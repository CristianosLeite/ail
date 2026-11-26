#!/bin/sh
# usage: tests/io.sh      (AILC names the compiler, default build/ailc)
#
# The compiler's I/O errors, which tests/run.sh cannot express: each case
# must exit with status 2 and print exactly one line on stderr. A compiler
# still running after 10 seconds is killed, which fails the case.
cd "$(dirname "$0")/.." || exit 1
ailc="timeout --signal=KILL 10 ${AILC:-build/ailc}"
mkdir -p build/tests
tmp=$(mktemp -d build/tests/io.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
src=tests/hello.aiw

# expect <name> <message>: the status is in $rc, stderr in $tmp/err
expect() {
    if [ "$rc" = 2 ] && [ "$(cat $tmp/err)" = "$2" ] && [ $(wc -l < $tmp/err) -eq 1 ]
    then echo "ok   $1"
    else echo "FAIL $1"; fail=1
    fi
}
fail=0

# A pipe whose read end is already closed: the reader opens the fifo and
# exits, and the compiler starts only after that, so the write cannot win
# a race against the close.
mkfifo $tmp/pipe
: < $tmp/pipe &
exec 4> $tmp/pipe
wait
$ailc < $src >&4 2> $tmp/err
rc=$?
exec 4>&-
expect io_closed_pipe "ailc: write error"

$ailc < $src > /dev/full 2> $tmp/err
rc=$?
expect io_dev_full "ailc: write error"

$ailc <&- > /dev/null 2> $tmp/err
rc=$?
expect io_closed_stdin "ailc: read error"

# A short write: stdout is a pipe that takes 4096 bytes and no more, since
# nobody reads it, and does not block. A helper program run with the pipe as
# its stdout sets both properties; they belong to the open pipe, so they
# outlast it. The compiler must write the first 4096 bytes of an executable
# larger than that, then fail on the rest.
# the source of the compiler, which names its target and its runtime as
# packages
src=compiler/ailc.aiw
pk="target=compiler/linux-x86_64 rt=build/rt/linux-x86_64"
mkfifo $tmp/short
exec 4<> $tmp/short
$ailc > $tmp/setup << 'EOF2'
sys 72 1 1031 4096 as r     # fcntl(1, F_SETPIPE_SZ, 4096)
ne r 4096 as r
jnz r bad
sys 72 1 4 2048 as r        # fcntl(1, F_SETFL, O_NONBLOCK)
jz r good
label bad
sys 60 1
label good
EOF2
chmod +x $tmp/setup
$tmp/setup >&4 || echo "FAIL io_short_write: no small pipe"
$ailc $pk < $src > $tmp/full
$ailc $pk < $src >&4 2> $tmp/err
rc=$?
dd bs=4096 count=1 <&4 > $tmp/got 2> /dev/null
exec 4>&-
head -c 4096 $tmp/full > $tmp/want
[ $(wc -c < $tmp/full) -gt 4096 ] && cmp -s $tmp/got $tmp/want || rc=prefix
expect io_short_write "ailc: write error"

exit $fail

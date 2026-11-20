#!/bin/sh
# usage: tests/io.sh
#
# The compiler's I/O errors, which tests/run.sh cannot express: each case
# must exit with status 2 and print exactly one line on stderr.
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/tests
tmp=$(mktemp -d build/tests/io.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
src=tests/hello.ai

# expect <name> <message>: the status is in $rc, stderr in $tmp/err
expect() {
    if [ $rc -eq 2 ] && [ "$(cat $tmp/err)" = "$2" ] && [ $(wc -l < $tmp/err) -eq 1 ]
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
build/ailc < $src >&4 2> $tmp/err
rc=$?
exec 4>&-
expect io_closed_pipe "ailc: write error"

build/ailc < $src > /dev/full 2> $tmp/err
rc=$?
expect io_dev_full "ailc: write error"

build/ailc <&- > /dev/null 2> $tmp/err
rc=$?
expect io_closed_stdin "ailc: read error"

exit $fail

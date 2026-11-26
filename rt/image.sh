#!/bin/sh
# usage: rt/image.sh <image> > image.aiw
#
# Write the image of the runtime as data lines, 16 bytes a line, under
# the name rtimg: the form in which the compiler has it (compiler/ailc.aiw
# names the file with use).
set -eu
echo "# the image of the runtime, written by rt/image.sh"
od -An -v -tu1 -w16 "$1" | awk 'NR == 1 { print "data rtimg" $0; next } { print "data" $0 }' |
    tr -s ' '

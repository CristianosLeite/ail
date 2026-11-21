#!/bin/sh
# a chain of 150000 functions, each a tail to the one defined after it:
# the count of the last comes to the first in time that grows with the
# number of functions, not with its square
awk 'BEGIN { n = 150000
  for (i = n; i >= 1; i--) printf "fn f%d a\ntail f%d a\nend\n", i, i - 1
  print "fn f0 a\nret a\nend\ncall f" n " 9 as x\nsys exit x" }'

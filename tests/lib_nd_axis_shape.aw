# a sum along an axis needs a result with the lengths of the array
# without that axis: a length of 1 where the array has more is not
# given every element, as it would be in ndadd, but refused, and the
# result stays what it was
use "lib/std/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "tests/lib/ndshow.aw"
buf a 176
buf o 176
buf p 176
buf q 176
buf sh 24
call ndmat a 2 3 as r
call ramp a 4 4
itof 7 as x
# one element for three columns, and for two rows
call ndvec o 1 as r
call ndfill o x
call ndsumax o a 0 as s
call ndsumax o a 1 as t
call ndmeanax o a 0 as u
# 2 by 1 by 3 along the axis 1: 1 by 3 and 2 by 1 are refused, 2 by 3 not
store sh 2
store sh+8 1
store sh+16 3
call ndreshape q a 3 sh as r
call ndmat p 1 3 as r
call ndfill p x
call ndsumax p q 1 as v
call show p
call ndfree p
call ndmat p 2 1 as r
call ndfill p x
call ndsumax p q 1 as w
call show p
call ndfree p
call ndmat p 2 3 as r
call ndsumax p q 1 as y
call show o
call show p
call putn s+t+u+v+w
call putn y
call print "\n"
call ndfree a
call ndfree o
call ndfree p

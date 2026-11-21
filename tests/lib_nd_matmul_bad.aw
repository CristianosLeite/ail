# a product of matrices is refused, and nothing written, for lengths
# that do not go together, arrays that have not two axes, a result in
# the storage of one of the two, and what is no array
use "lib/std/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "tests/lib/ndshow.aw"
buf a 176
buf b 176
buf c 176
buf q 176
buf v 176
buf z 176
call ndmat a 2 3 as r
call ndmat b 3 2 as r
call ndmat c 2 2 as r
call ndmat q 3 3 as r
call ramp a 4 4
call ramp b 4 4
call ramp q 4 4
itof 7 as x
call ndfill c x
# 2 by 3 times 2 by 3, a result of 3 by 3 for 2 by 2, of 2 by 3
call ndmatmul c a a as s
call ndmatmul q a b as t
call ndmatmul a a b as u
# one axis on either side, and as the result
call ndvec v 3 as r
call ndmatmul c a v as w
call ndmatmul c v b as y
call ndfree v
call ndvec v 2 as r
call ndmatmul v a b as d
# a square in place, and into a view of itself
call ndmatmul q q q as e
call ndtrans v q as r
call ndmatmul v q q as f
call ndmatmul q v v as g
# no array
call ndmatmul c a z as h
call ndmatmul c z b as k
call ndmatmul z a b as l
call show c
call show q
call show a
call putn s+t+u+w+y+d+e+f+g+h+k+l
call print "\n"
call ndfree a
call ndfree b
call ndfree c
call ndfree q
sys exit r

# between doubles and integers there are only ndtoi and ndtof: a double
# is cut off towards 0, an integer becomes the nearest double; arrays of
# two kinds in one operation are refused, and ndkind changes how the
# bits are read and none of them
use "lib/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "tests/lib/ndshow.aw"
buf a 176
buf i 176
buf j 176
buf f 176
buf k 176
buf z 176
call ndvec a 6 as r
call ndvec i 6 as r
call ndkind i 2 as r
call ndvec j 6 as r
call ndkind j 2 as r
call ndvec f 6 as r
# -1.75 -1 -0.25 0.5 1.25 2
call ramp a -7 3
call ndtoi i a as s
call showi i
call count j -3 2
call ndtof f j as t
call show f
# one number to all, and a view backwards
itof 9 as x
fsqrt x as x
call ndscalar k x
call ndtoi i k as u
call showi i
call ndslice z j 0 0 6 -1 as v
call ndtof f z as w
call show f
# what is no number and what does not fit give the lowest integer
store z 0
call ndfill a 0x7ff8000000000000
call ndtoi i a as y
load i as p
load p as x
call putn x==0x8000000000000000
# the kinds that are refused
call ndtoi f a as b
call ndtoi i j as c
call ndtof i j as d
call ndtof f a as e
call ndadd f a j as g
call ndadd f j a as h
call ndadd i a a as l
call ndput f j as m
call ndput i a as n
call nddot a j as x o
call ndmatmul f a j as q
call ndsumax k j 0 as q
call putn b+c+d+e+g+h+l+m+n+o+q
# ndkind: the bits of 1.0 read as an integer, and back
itof 1 as x
call ndfill a x
call ndkind a 2 as b
call ndsum a as x c
call putn x==0x3ff0000000000000*6
call ndkind a 1 as d
call ndsum a as x e
ftoi x as x
call putn x
call ndkind a 0 as g
call ndkind a 3 as h
store z+8 0
call ndkind z 1 as l
call putn g+h+l
call print "\n"
call ndfree a
call ndfree i
call ndfree j
call ndfree f
sys exit r+s+t+u+v+w+y+b+c+d+e

# the result may be one of the arrays it is made of, or both; storage
# shared in any other way is refused, as is a result whose elements are
# one, and then nothing is written
use "lib/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "tests/lib/ndshow.aw"
buf a 176
buf b 176
buf v 176
buf w 176
buf k 176
call ndvec a 6 as r
call ndvec b 6 as r
call ramp a 4 4
call ramp b 40 0
# a += b, a = b - a, a *= a
call ndadd a a b as s
call show a
call ndsub a b a as t
call show a
call ndmul a a a as u
call show a
# a view that is the whole array is the array
call ndslice v a 0 0 6 1 as x
call ndadd v a v as y
call show a
# shifted by one, backwards, and the half that lies between
call ndslice v a 0 0 5 1 as x
call ndslice w a 0 1 6 1 as x
call ndadd v v w as c
call ndadd w v b as d
call ndslice w a 0 0 6 -1 as x
call ndadd a w b as e
call ndput w a as f
call ndslice v a 0 0 6 2 as x
call ndslice w a 0 1 6 2 as x
call ndslice b b 0 0 3 1 as x
call ndadd v w b as g
call show a
# apart they go
call ndslice v a 0 0 3 1 as x
call ndslice w a 0 3 6 1 as x
call ndadd v w b as h
call show a
# a result with a stride of 0: six times the one element
store w+112 0
store w+48 6
store w+24 w
call ndput w b as l
# and the number itself as the result is one element
itof 3 as z
call ndscalar k z
call ndadd k k k as m
call show k
call putn c+d+e+f+g+l
call print "\n"
call ndfree a
call ndfree b
sys exit r+s+t+u+x+y+h+m

# the sum of the products of two arrays of one axis, also of views with
# steps; other lengths and other numbers of axes are refused
use "lib/std/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "tests/lib/ndshow.aw"
buf a 176
buf b 176
buf m 176
buf v 176
buf w 176
buf e 176
call ndvec a 4 as r
call ndvec b 4 as r
call ramp a 4 4
call ramp b 2 -4
# 1 2 3 4 times 0.5 -0.5 -1.5 -2.5
call nddot a b as x s
call showx x
call nddot a a as x t
call showx x
# b backwards, and every other element of each
call ndslice v b 0 0 4 -1 as u
call nddot a v as x c
call showx x
call ndslice v a 0 0 4 2 as u
call ndslice w b 0 1 4 2 as u
call nddot v w as x d
call showx x
# a column and a row of a table
call ndmat m 3 3 as f
call ramp m 0 4
call ndslice v m 1 2 3 1 as g
call ndslice v v 0 0 3 1 as g
store v+16 1
load v+112 as y
call ndslice w m 0 1 2 1 as g
load w+120 as z
store w+16 1
store w+48 3
store w+112 z
call nddot v w as x h
call showx x
# no element is 0
call ndvec e 0 as k
call nddot e e as x l
call showx x
call print "\n"
call nddot a e as x n
call nddot a m as x o
call nddot m m as x p
call nddot a w+8 as x q
call putn n+o+p+q+x
call print "\n"
call ndfree a
call ndfree b
call ndfree m
sys exit r+s+t+u+c+d+f+g+h+k+l

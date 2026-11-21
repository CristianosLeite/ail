# the product of matrices: 2 by 3 times 3 by 2, a matrix times a column
# and a row times a matrix, views with exchanged axes and steps as any
# of the three, and matrices without rows or columns
use "lib/std/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "tests/lib/ndshow.aw"
buf a 176
buf b 176
buf c 176
buf d 176
buf v 176
buf w 176
buf e 176
buf f 176
buf p 176
call ndmat a 2 3 as r
call ndmat b 3 2 as r
call ndmat c 2 2 as r
call ndmat d 3 3 as r
# 1 2 3 / 4 5 6 and 0.5 1 / 1.5 2 / 2.5 3
call ramp a 4 4
call ramp b 2 2
call ndmatmul c a b as s
call show c
call ndmatmul d b a as t
call show d
# a times its own transpose, and the transpose times a
call ndtrans v a as u
call ndmatmul c a v as x
call show c
call ndmatmul d v a as y
call show d
# the columns of b backwards as the second, into d's corners
call ndslice v b 1 0 2 -1 as u
call ndslice w d 0 0 3 2 as u
call ndslice w w 1 0 3 2 as u
call ndfill d 0
call ndmatmul w a v as z
call show d
# a column and a row are matrices of one column and one row
call ndslice v b 1 1 2 1 as u
call ndslice w c 1 0 1 1 as u
call ndmatmul w a v as g
call show c
call ndslice v a 0 1 2 1 as u
call ndmat p 1 3 as u
call ndmatmul p v d as h
call show p
# 2 by 0 times 0 by 2 is 2 by 2 of zeros; 0 rows give none
call ndmat e 2 0 as k
call ndmat f 0 2 as k
itof 5 as o
call ndfill c o
call ndmatmul c e f as l
call show c
call ndmatmul f f c as m
call ndsize f as n
call putn n
call print "\n"
call ndfree a
call ndfree b
call ndfree c
call ndfree d
sys exit r+s+t+u+x+y+z+g+h+k+l+m

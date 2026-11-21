# the dot product and the product of matrices against NumPy, within
# 2^-40 of the sizes: 6 by 7 times 7 by 5, the transpose of a matrix
# times the matrix, and views with steps and backwards
use "lib/std/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "tests/lib/ndcheck.aw"
use "tests/lib/ndfix.aw"
buf a 176
buf b 176
buf o 176
buf w 176
buf v 176
buf x 176
buf y 176
call fix a fxpa 2 6 7 0 as r
call fix b fxpb 2 7 5 0 as r
call ndmat o 6 5 as r
call ndmatmul o a b as s
call fix w fxpab 2 6 5 0 as r
call differ o w 1 as n
call putn n
call print " "
call ndfree o
call ndmat o 7 7 as r
call ndtrans v a as t
call ndmatmul o v a as u
call fix w fxpata 2 7 7 0 as r
call differ o w 1 as n
call putn n
call print " "
# pa[::2, ::-1] @ pb
call ndfree o
call ndmat o 3 5 as r
call ndslice v a 0 0 6 2 as c
call ndslice v v 1 0 7 -1 as c
call ndmatmul o v b as d
call fix w fxpview 2 3 5 0 as r
call differ o w 1 as n
call putn n
call print " "
call fix x fxpx 1 100 0 0 as r
call fix y fxpy 1 100 0 0 as r
call nddot x y as p e
load fxpdot as q
call near p q as n
call putn n
# px[::-2] . py[1::2]
call ndslice x x 0 0 100 -2 as f
call ndslice y y 0 1 100 2 as f
call nddot x y as p g
load fxpdotv as q
call near p q as n
call putn n
call print "\n"
call ndfree o
sys exit r+s+t+u+c+d+e+f+g

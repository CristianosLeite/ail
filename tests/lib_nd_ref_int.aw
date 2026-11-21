# integers against NumPy, bit for bit: sums, differences and products
# that wrap, the sum of all and along an axis, the product of matrices,
# and the two conversions
use "lib/io.aw"
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
# make o of the kind k and print how it differs from the numbers at p,
# r axes of the lengths a and b
fn same o p r a b
	local w 176
	call fix w p r a b 0
	call differ o w 0 as n
	call putn n
	call print " "
end
call fix a fxia 2 3 4 0 as r
call ndkind a 2 as r
call fix b fxib 2 3 4 0 as r
call ndkind b 2 as r
call ndmat o 3 4 as r
call ndkind o 2 as r
call ndadd o a b as s
call same o fxiadd 2 3 4
call ndsub o a b as t
call same o fxisub 2 3 4
call ndmul o a b as u
call same o fximul 2 3 4
call ndsum a as x c
load fxisum as y
call putn x==y
call print " "
call ndfree o
call ndvec o 4 as r
call ndkind o 2 as r
call ndsumax o a 0 as d
call same o fxis0 1 4 0
# ia @ ib.T
call ndfree o
call ndmat o 3 3 as r
call ndkind o 2 as r
call ndtrans v b as e
call ndmatmul o a v as f
call same o fximm 2 3 3
# doubles to integers and integers to doubles
call ndfree o
call ndvec o 6 as r
call ndkind o 2 as r
call fix v fxifa 1 6 0 0 as r
call ndtoi o v as g
call same o fxitoi 1 6 0
call ndfree o
call ndmat o 3 4 as r
call ndtof o a as h
call same o fxitof 2 3 4
# the mean of a column, a double
call ndslice v a 1 1 2 1 as k
call ndmean v as x l
load fximean as y
call near x y as n
call putn n
call print "\n"
call ndfree o
sys exit r+s+t+u+c+d+e+f+g+h+k+l

# doubles that lie one behind the other are computed two at a time, the
# last of an odd count alone: for 0 to 9 numbers, and for matrices of
# sides 4 and 5, the bits must be those that the same arrays give
# backwards. The matrices backwards are computed one at a time; the
# arrays of one axis are then computed from their lowest address on,
# which tests/lib_nd_reversed compares with loops of its own
use "lib/std/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "tests/lib/ndcheck.aw"
buf a 176
buf b 176
buf o 176
buf p 176
buf ra 176
buf rb 176
buf rp 176
buf k 176
buf c 176
buf d 176
# fill the array x, whose elements lie one behind the other, with
# numbers that have many digits: (7i + s) / (i + 3)
fn fill x s
	call ndsize x as n
	load x as q
	i=0
	while i<n
		itof i*7+s as u
		itof i+3 as v
		fdiv u v as u
		store q+i*8 u
		i+=1
	end
end
# the four operations on n numbers: forwards into o and backwards into
# p, with two arrays, with a number second and with a number first
fn four n
	call ndvec a n
	call ndvec b n
	call ndvec o n
	call ndvec p n
	call fill a 1
	call fill b 11
	call ndslice ra a 0 0 n -1
	call ndslice rb b 0 0 n -1
	call ndslice rp p 0 0 n -1
	itof 3 as x
	fsqrt x as x
	call ndscalar k x
	bad=0
	call ndadd o a b as r
	call ndadd rp ra rb as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndsub o a b as r
	call ndsub rp ra rb as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndmul o a b as r
	call ndmul rp ra rb as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call nddiv o a b as r
	call nddiv rp ra rb as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndadd o a k as r
	call ndadd rp ra k as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndsub o a k as r
	call ndsub rp ra k as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndmul o a k as r
	call ndmul rp ra k as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call nddiv o a k as r
	call nddiv rp ra k as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndsub o k a as r
	call ndsub rp k ra as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call nddiv o k a as r
	call nddiv rp k ra as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndadd o k a as r
	call ndadd rp k ra as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndmul o k a as r
	call ndmul rp k ra as s
	call differ o p 0 as m
	bad+=m+2-r-s
	call ndfree a
	call ndfree b
	call ndfree o
	call ndfree p
	ret bad
end
# the product of two matrices of side n and the sums of the columns of
# one: forwards, and into a result with its columns backwards from a
# matrix with its columns backwards
fn square n
	call ndmat a n n
	call ndmat b n n
	call ndmat o n n
	call ndmat p n n
	call fill a 1
	call fill b 11
	call ndslice rb b 1 0 n -1
	call ndslice rp p 1 0 n -1
	call ndmatmul o a b as r
	call ndmatmul rp a rb as s
	call differ o p 0 as m
	bad=m+2-r-s
	call ndvec c n
	call ndvec d n
	call ndslice ra a 1 0 n -1
	call ndslice rp d 0 0 n -1
	call ndsumax c a 0 as r
	call ndsumax rp ra 0 as s
	call differ c d 0 as m
	bad+=m+2-r-s
	call ndfree a
	call ndfree b
	call ndfree o
	call ndfree p
	call ndfree c
	call ndfree d
	ret bad
end
n=0
while n<10
	call four n as x
	call putn x
	n+=1
end
call print " "
call square 4 as x
call putn x
call square 5 as x
call putn x
call square 1 as x
call putn x
call print "\n"

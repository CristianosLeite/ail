# other lengths for the same elements, when they lie one behind the
# other and are as many; a view whose elements lie apart is refused
# until it is copied
use "lib/std/io.aw"
use "lib/nd/array.aw"
buf a 176
buf v 176
buf t 176
buf sh 32
buf ix 32
call ndvec a 12 as r
load a as p
i=0
while i<12
	store p+i*8 i
	i+=1
end
store sh 3
store sh+8 4
call ndreshape v a 2 sh as s
store ix 2
store ix+8 1
call ndget v ix as x b
call putn x
call print " "
load v+40 as o
load v+112 as e
call putn o
call putn e
call print " "
# 3 rows of 4 to 2 times 3 times 2, in place of the view
store sh 2
store sh+8 3
store sh+16 2
call ndreshape v v 3 sh as c
store ix 1
store ix+8 2
store ix+16 1
call ndget v ix as x d
call putn x
call print " "
# to no axis at all only for one element
call ndreshape t a 0 sh as f
store sh 5
call ndreshape t a 1 sh as g
store sh 12
store sh+8 1
store sh+16 1
call ndreshape t a 9 sh as h
# the transposed view lies apart
store sh 3
store sh+8 4
call ndreshape v a 2 sh as k
call ndtrans t v as l
store sh 12
call ndreshape t t 1 sh as m
call ndcontig t as n
load t+16 as q
call putn f+g+h+m+n
call putn q
call print " "
# a row of it does not
call ndslice t v 0 1 2 1 as u
store sh 2
store sh+8 2
call ndreshape t t 2 sh as w
store ix 1
store ix+8 1
call ndget t ix as x y
call putn x
call print " "
# and in place the array keeps its storage
store sh 6
store sh+8 2
call ndreshape a a 2 sh as z
load a+40 as o
load a+56 as e
call putn o
call putn e
call print "\n"
call ndfree a
sys exit r+s+b+c+d+k+l+u+w+y+z

# the axes in the reverse order, or two of them exchanged: the same
# elements under other indices, and nothing is moved
use "lib/io.aw"
use "lib/nd/array.aw"
buf a 176
buf t 176
buf sh 24
buf ix 24
store sh 2
store sh+8 3
store sh+16 4
call ndnew a 3 sh as r
load a as p
i=0
while i<24
	store p+i*8 i
	i+=1
end
call ndtrans t a as s
load t+48 as x
call putn x
load t+56 as x
call putn x
load t+64 as x
call putn x
call print " "
# the element 3 2 1 of the view is the element 1 2 3 of the array
store ix 3
store ix+8 2
store ix+16 1
call ndget t ix as x u
call putn x
call print " "
call ndcontig a as c
call ndcontig t as d
call putn c
call putn d
call print " "
call ndswap t a 1 2 as v
load t+56 as x
call putn x
load t+64 as x
call putn x
store ix 1
store ix+8 3
store ix+16 2
call ndget t ix as x w
call print " "
call putn x
call ndswap t a 1 3 as e
call ndswap t a 3 0 as f
call ndtrans t ix+16 as g
# in place the array keeps its storage
call ndtrans a a as h
load a+40 as o
load a+48 as n
call print " "
call putn e+f+g
call putn o
call putn n
call print "\n"
call ndfree a
sys exit r+s+u+v+w+h

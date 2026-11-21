# arrays of doubles with one axis that lie one behind the other, apart
# from the result, take a short way through ndadd, ndsub, ndmul and
# nddiv, also with a number on either side or on both: the bits are
# those of a loop over the indices. What shares storage with the result
# takes the long way, which allows the result in the place of one of
# the two and refuses elements that are shifted; an array of one
# element with an axis still goes with every index
use "lib/std/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
buf a 176
buf b 176
buf o 176
buf k 176
buf l 176
buf v 176
buf w 176
buf m 96
buf sh 8
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
fn one op x y
	if op==0
		fadd x y as x
	end
	if op==1
		fsub x y as x
	end
	if op==2
		fmul x y as x
	end
	if op==3
		fdiv x y as x
	end
	ret x
end
# how many of the n doubles at r are not the operation op of those at
# x and at y, which are sx and sy bytes apart
fn wrong op n r x sx y sy
	bad=0
	i=0
	while i<n
		load x+i*sx as u
		load y+i*sy as v
		call one op u v as u
		load r+i*8 as v
		bad+=u!=v
		i+=1
	end
	ret bad
end
fn nd op r x y
	if op==0
		tail ndadd r x y
	end
	if op==1
		tail ndsub r x y
	end
	if op==2
		tail ndmul r x y
	end
	tail nddiv r x y
end
fn all n
	call ndvec a n
	call ndvec b n
	call ndvec o n
	call fill a 1
	call fill b 11
	itof 3 as x
	fsqrt x as x
	call ndscalar k x
	itof 7 as x
	fsqrt x as x
	call ndscalar l x
	load a as pa
	load b as pb
	load o as po
	bad=0
	op=0
	while op<4
		call nd op o a b as r
		call wrong op n po pa 8 pb 8 as q
		bad+=q+1-r
		call nd op o a k as r
		call wrong op n po pa 8 k+48 0 as q
		bad+=q+1-r
		call nd op o k b as r
		call wrong op n po k+48 0 pb 8 as q
		bad+=q+1-r
		call nd op o k l as r
		call wrong op n po k+48 0 l+48 0 as q
		bad+=q+1-r
		op+=1
	end
	call ndfree a
	call ndfree b
	call ndfree o
	ret bad
end
n=0
while n<10
	call all n as x
	call putn x
	n+=1
end
call print " "
# 12 doubles 1 to 12: v the first 8 of them, w 8 from the second on
i=0
while i<12
	itof i+1 as x
	store m+i*8 x
	i+=1
end
store sh 8
call ndwrap v m 64 1 sh as r
call ndwrap w m+8 64 1 sh as r
# shifted by one element: refused both ways, nothing written
call ndadd w v v as s
call ndadd v w w as t
bad=s+t
i=0
while i<12
	load m+i*8 as x
	ftoi x as x
	bad+=x!=i+1
	i+=1
end
call putn bad
# the result in the place of the first, of the second and of both,
# with the other four doubles apart
store sh 4
call ndwrap v m 32 1 sh as r
call ndwrap w m+32 32 1 sh as r
call ndadd v v w as s
load m as x
load m+24 as y
ftoi x as x
ftoi y as y
call putn s
call putn (x==6)+(y==12)
call ndsub w v w as s
load m+32 as x
load m+56 as y
ftoi x as x
ftoi y as y
call putn s
call putn (x==1)+(y==4)
call ndadd v v v as s
load m as x
ftoi x as x
call putn s
call putn x
call print " "
# a result right behind its array is apart from it
call ndmul w v v as s
load m+32 as x
ftoi x as x
call putn s
call putn x
call print " "
# one element with an axis goes with all four, two do not
store sh 1
call ndwrap v m 8 1 sh as r
call ndadd w w v as s
load m+56 as x
ftoi x as x
call putn s
call putn x
store sh 2
call ndwrap v m 16 1 sh as r
call ndadd w w v as s
call putn s
call print "\n"

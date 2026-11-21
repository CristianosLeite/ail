# keys that belong at one place of the table stand behind each other: all
# are found; with the first taken out the others are still found, and a
# new key of that place takes the place that was given up, so that the
# places that hold or held a key do not become more
use "lib/std/io.aw"
use "lib/std/map.aw"
buf m 32
buf k 40
# five keys whose hash ends in the same six bits as that of 1
n=0
w=0
x=1
while n<5
	h=(x^x>>30)*0xbf58476d1ce4e5b9
	h=(h^h>>27)*0x94d049bb133111eb
	h=(h^h>>31)&63
	if n==0
		w=h
	end
	if h==w
		store k+n*8 x
		n+=1
	end
	x+=1
end
i=0
while i<4
	load k+i*8 as x
	call mapput m x i+10
	i+=1
end
load m+8 as c
call putn c
load k as x
call mapdel m x as a
call mapget m x as v b
s=0
i=1
while i<4
	load k+i*8 as x
	call mapget m x as v r
	s+=v*r
	i+=1
end
call print " "
call putn s
load m+24 as u
load k+32 as x
call mapput m x 99 as d
call mapget m x as v e
load m+24 as t
load m+16 as n
call print " "
call putn v
call print " "
call putn n
call print "\n"
call mapfree m
sys exit a+b+d+e+(u==t)

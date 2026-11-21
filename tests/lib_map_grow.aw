# 100000 keys go in while the table doubles many times, and every one
# keeps its value; with all but 100 taken out and as many new ones put
# in, the table is cleared of what was taken out and does not grow
use "lib/io.aw"
use "lib/map.aw"
buf m 32
i=0
while i<100000
	call mapput m i*0x9e3779b97f4a7c15 i as r
	ifz r
		sys exit 1
	end
	i+=1
end
load m+8 as c
load m+16 as n
call putn n
call print " "
call putn c
s=0
i=0
while i<100000
	call mapget m i*0x9e3779b97f4a7c15 as v r
	ifz r&(v==i)
		sys exit 2
	end
	i+=1
end
i=100
while i<100000
	call mapdel m i*0x9e3779b97f4a7c15 as r
	s+=r
	i+=1
end
call mapdel m 7 as a
i=0
while i<100000
	call mapput m i*2+1 i as r
	i+=1
end
load m+8 as d
load m+16 as n
call print " "
call putn s
call print " "
call putn n
call print " "
call putn d
call mapget m 99*0x9e3779b97f4a7c15 as v b
call print " "
call putn v
call mapget m 100*0x9e3779b97f4a7c15 as v e
call mapget m 199999 as v f
call print " "
call putn v
call print "\n"
call mapfree m
load m as p
load m+8 as c
call mapput m 1 2 as g
call mapget m 1 as v h
call mapfree m
sys exit a+e+p+c+b+f+g+h+v

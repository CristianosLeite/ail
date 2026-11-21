# a buffer that grows many times keeps its bytes: 100000 numbers of 8
# bytes, added one at a time and in pieces, then summed; an offset stays
# good while the address changes
use "lib/std/io.aw"
use "lib/std/bytes.aw"
buf b 24
buf w 8
i=0
while i<100000
	store w i*7
	ifz i&1
		call byadd b w 8
	else
		call byadd b w 3
		call byadd b w+3 5
	end
	i+=1
end
load b as p
load b+8 as n
load b+16 as c
s=0
i=0
while i<100000
	load p+i*8 as v
	s+=v
	i+=1
end
call putn n
call print " "
call putn s
call print " "
call putn c>=n
call print "\n"

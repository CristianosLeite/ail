# the ring goes round many times: a queue of 5 that holds 3 or 4 values
# while 100000 pass through it, each leaving as it came; the values do
# not move
use "lib/io.aw"
use "lib/queue.aw"
buf q 32
call queueinit q 5 as r
load q as p
call queuepush q 0
call queuepush q 1
call queuepush q 2
s=0
i=3
while i<100000
	call queuepush q i as a
	call queuepop q as x b
	ifz a&b&(x==i-3)
		sys exit 1
	end
	s+=x
	i+=1
end
load q as o
load q+16 as h
load q+24 as n
call putn s
call print " "
call putn h
call print " "
call putn n
call print "\n"
call queuefree q
sys exit r+(p==o)

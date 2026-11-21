# values leave the smallest first, in the unsigned order, equal ones one
# after the other and 0 like any other; an empty heap gives 0 and 0
use "lib/std/io.aw"
use "lib/std/vec.aw"
use "lib/std/heap.aw"
buf h 24
call heappeek h as x a
call heappop h as x b
call heappush h 5 as c
call heappush h 3
call heappush h 18446744073709551615
call heappush h 3
call heappush h 0
call heappush h 9
call heappush h 3
call heappush h 1
call heappeek h as x d
load h+8 as n
call putn n
while n
	call heappop h as x e
	call print " "
	call putn x
	c+=e
	load h+8 as n
end
call print "\n"
call heappop h as x f
call heapfree h
sys exit a+b+f+x+c+d

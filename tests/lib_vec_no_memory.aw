# with the memory of the process limited to 64 MiB a vector and a heap
# grow until the kernel refuses: the push that fails returns 0 and
# changes nothing, every value is still there, and what needs no new
# room still works
use "lib/std/io.aw"
use "lib/std/vec.aw"
use "lib/std/heap.aw"
const setrlimit 160
buf lim 16
buf v 24
buf h 24
store lim 0x4000000
store lim+8 0x4000000
sys setrlimit 9 lim as r
if r
	sys exit 1
end
n=0
r=1
while r
	call vecpush v n*3 as r
	n+=r
end
load v as p
load v+8 as m
load v+16 as c
call vecpush v 1 as a
load v as q
load v+8 as d
load v+16 as e
i=0
while i<n
	call vecget v i as x r
	ifz r&(x==i*3)
		sys exit 2
	end
	i+=1
end
call vecpop v as x b
call vecpush v 7 as f
call vecfree v
k=0
r=1
while r
	call heappush h k as r
	k+=r
end
load h+8 as g
call heappush h 0 as s
load h+8 as t
call heappeek h as x u
call heappop h as y w
call heapfree h
call putn n==m
call putn m==c
call putn k==n
call putn x+y
call print "\n"
sys exit a+s+(p==q)+(m==d)+(c==e)+b+f+(g==t)+u+w

# 100000 tasks at once, more than a block holds, and their results
use "lib/async/task.aw"
buf hs 800000
fn poll t
	load t+64 as a
	store t+16 a
	ret 1
end
ref poll as p
i=0
while i<100000
	call async 72 p as h
	store h+64 i
	store hs+i*8 h
	i+=1
end
call asyncrun as n
s=n
i=0
while i<100000
	load hs+i*8 as h
	call await h 0 as x
	s+=x
	i+=1
end
sys exit_group s==4999950000

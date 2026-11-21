# records of every size, written to their last byte: from blocks, of
# their own, and given back to the kernel
use "lib/async/task.aw"
fn poll t
	load t+64 as z
	loadb t+z-1 as c
	store t+16 c
	ret 1
end
fn try z
	ref poll as p
	call async z p as h
	store h+64 z
	storeb h+z-1 z%251
	call await h 0 as x
	ret x==z%251
end
n=0
z=80
while z<300000
	call try z as r
	n+=r
	call try z+1 as r
	n+=r
	z*=2
end
# smaller than a record: a record
call async 0 0 as h
call asyncfinish h 3
call await h 0 as x
sys exit_group n+x

# a task that is detached gives its record back when it is done, whether
# it was detached before or after, and also while it is in the queue
use "lib/async/task.aw"
var ran
fn poll t
	ran+=1
	ret 1
end
fn twice t
	load t+8 as s
	store t+8 1
	ifz s
		call asyncwake t
		ret 0
	end
	call asyncwake t
	ret 1
end
ref poll as p
call async 64 p as a
call asyncdetach a
call asyncrun as n
call async 64 0 as b
r=a==b
call asyncfinish b 0
call asyncdetach b
call async 64 0 as c
r+=b==c
call asyncdetach c
call asyncfinish c 0
ref twice as p
call async 64 p as d
r+=c==d
call asyncdetach d
call asyncrun as m
call async 64 0 as e
r+=d==e
call asyncdetach 0
sys exit_group r*10+n+m+ran

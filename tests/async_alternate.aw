# two tasks that give the thread back after every letter run in turn: a
# task that wakes itself while it is polled is polled again, behind the
# other
use "lib/io.aw"
use "lib/async/task.aw"
fn poll t
	load t+64 as c
	load t+72 as n
	buf ch 8
	storeb ch c
	call print ch 1
	n-=1
	store t+72 n
	ifz n
		ret 1
	end
	call asyncwake t
	ret 0
end
ref poll as p
call async 80 p as a
store a+64 97
store a+72 3
call async 80 p as b
store b+64 98
store b+72 3
call asyncrun as n
call print "\n"
call await a 0
call await b 0
sys exit_group n

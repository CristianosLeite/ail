# a task that always has something to do does not keep a timer from
# being seen: the task that sleeps is woken while the other spins
use "lib/async/task.aw"
use "lib/async/time.aw"
var stop
fn spin t
	if stop
		ret 1
	end
	call asyncwake t
	ret 0
end
fn sleeper t
	load t+8 as h
	ifz h
		call asyncsleep 5 as h
		store t+8 h
	end
	call await h t as v r
	ifz r
		ret 0
	end
	stop=1
	ret 1
end
ref spin as p
call async 64 p as a
ref sleeper as p
call async 64 p as b
call asyncrun as n
sys exit_group n+stop

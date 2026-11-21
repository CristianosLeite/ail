# a task that is done at its first poll, awaited by code that is no task
use "lib/async/task.aw"
fn poll t
	load t+64 as a
	store t+16 a*2
	ret 1
end
ref poll as p
call async 72 p as h
store h+64 21
call await h 0 as x r
sys exit_group x+r

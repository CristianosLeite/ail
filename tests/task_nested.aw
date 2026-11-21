use "lib/std/task.aw"
# a task spawns tasks and joins them, with fewer workers than tasks
fn fib n
	if n<2
		ret n
	end
	spawn fib n-1 as a
	spawn fib n-2 as b
	join a as x
	join b as y
	ret x+y
end
call workers 2
spawn fib 16 as h
join h as x
sys exit_group x==987

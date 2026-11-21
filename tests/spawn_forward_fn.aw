use "lib/std/task.aw"
spawn work 5 as h
join h as x
sys exit_group x
fn work a
	ret a+1
end

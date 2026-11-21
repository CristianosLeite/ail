use "lib/std/task.aw"
fn work a b
	ret a*b
end
spawn work 6 7 as h
join h as x
sys exit_group x

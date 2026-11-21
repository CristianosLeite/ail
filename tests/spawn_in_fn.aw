use "lib/task.aw"
fn sq a
	ret a*a
end
fn both a b
	spawn sq a as h
	spawn sq b as g
	join g as y
	join h as x
	ret x+y
end
call both 3 4 as r
sys exit_group r

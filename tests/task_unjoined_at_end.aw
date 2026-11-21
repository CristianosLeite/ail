use "lib/std/task.aw"
# tasks that nobody joins do not keep the program
fn work a
	label l
	jmp l
end
spawn work 1 as h
spawn work 2 as g

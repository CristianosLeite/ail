# die ends the whole program, a worker that is busy included
use "lib/std/io.aw"
use "lib/std/task.aw"
buf up 8
fn work
	store up 1
	label l
	jmp l
end
fn nap
	local ts 16
	store ts 0
	store ts+8 1000000
	sys nanosleep ts 0
end
call workers 1
spawn work as h
label w
load up as u
ifz u
	call nap
	jmp w
end
call die "fatal\n"

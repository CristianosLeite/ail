# a task that awaits asyncyield lets the tasks in the queue run first
use "lib/io.aw"
use "lib/async/task.aw"
fn poll t
	load t+8 as s
	ifz s
		call print "a"
		call asyncyield as y
		store t+64 y
		store t+8 1
	end
	load t+64 as y
	call await y t as v r
	ifz r
		ret 0
	end
	call print "c"
	ret 1
end
fn other t
	call print "b"
	ret 1
end
ref poll as p
call async 72 p as h
ref other as p
call async 64 p as g
call asyncrun as n
call print "\n"
sys exit_group n

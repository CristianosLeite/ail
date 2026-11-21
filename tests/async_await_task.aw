# a task that makes another one and awaits it: it is polled again when
# the other is done, and has the result then
use "lib/std/io.aw"
use "lib/async/task.aw"
fn child t
	load t+64 as n
	ifz n
		store t+16 30
		ret 1
	end
	store t+64 n-1
	call print "c"
	call asyncwake t
	ret 0
end
fn parent t
	load t+8 as s
	ifz s
		ref child as p
		call async 72 p as h
		store h+64 2
		store t+64 h
		store t+8 1
	end
	call print "p"
	load t+64 as h
	call await h t as v r
	ifz r
		ret 0
	end
	store t+16 v+12
	ret 1
end
ref parent as p
call async 72 p as h
call await h 0 as x
call print "\n"
sys exit_group x

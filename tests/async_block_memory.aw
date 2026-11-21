# a task that gave work of the pool a local of its own does not go on
# while the work runs, however it stops waiting: cancelled itself, with
# a limit that runs out, with a limit that is cancelled, or by asyncstop.
# Each time the work has written the last byte before the task returns.
use "lib/std/io.aw"
use "lib/std/task.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
use "lib/async/io.aw"
use "lib/async/pool.aw"
fn fill p ms c d
	local ts 16
	store ts 0
	store ts+8 ms*1000000
	sys nanosleep ts 0
	storeb p+63 7
	ret 1
end
# how: 0 awaits the work, 1 a limit of 10 ms on it. The result is the
# last byte of the local, and 100 more if the await gave an error.
async fn user how
	local b 64
	storeb b+63 0
	ref fill as p
	call asyncblock p b 60 0 0 as h
	if how
		call asynctimeout h 10 as h
	end
	await h as r
	loadb b+63 as v
	ret v+(r>-4096)*100
end
call user 0 as t
await asyncsleep 20
call asynccancel t
await t as a
call putn a
call print " "
await user 1 as a
call putn a
call print " "
call user 1 as t
await asyncsleep 5
call asynccancel t
await t as a
call putn a
call print " "
call user 0 as t
await asyncsleep 20
call asyncclock as t0
call asyncstop as n
call asyncclock as t1
call putn n
call putn (t1-t0)/1000000>20
call print "\n"

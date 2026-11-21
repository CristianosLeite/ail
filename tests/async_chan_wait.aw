# receives that wait are served in their order; one that is cancelled or
# runs out of time leaves the value to the next; sends that wait for
# room are cancelled the same way; a task that waits at a channel is
# reached by asyncstop
use "lib/std/io.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
use "lib/async/chan.aw"
async fn stuck c
	await asyncrecv c as v
	ret v
end
call asyncchan 1 as c
call asyncrecv c as a
call asyncrecv c as b
call asyncrecv c as d
call asynctimeout d 5 as g
call asynccancel a
await g as x
call putn 0-x
call print " "
await asyncsend c 7
await a as x
await b as y
call putn 0-x
call putn y
call print " "
await asyncsend c 1
call asyncsend c 2 as s
call asyncsend c 3 as t
call asynccancel s
await asyncrecv c as x
await asyncrecv c as y
await s as z
await t
call putn x
call putn y
call putn 0-z
call print " "
call stuck c as k
call asyncdetach k
call asyncstep
call asyncstop as n
call putn n
call print "\n"

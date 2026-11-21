# asyncstop with tasks alive: one that accepts in a loop, one that reads,
# one that sleeps in a loop and never looks at a result, one that waits
# for work of the pool, one in the queue. All are ended, none is left,
# and the library works again afterwards. The work of the pool is being
# done and cannot be stopped, so asyncstop returns when it has returned.
use "lib/std/io.aw"
use "lib/std/task.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
use "lib/async/io.aw"
use "lib/async/pool.aw"
buf rb 16
var closed
async fn conn c
	await asyncread c rb 16 as n
	call asyncclose c
	closed+=1
end
async fn serve l
	while 1
		await asyncaccept l as c
		if c>-4096
			call asyncclose l
			closed+=1
			ret 0
		end
		call conn c as k
		call asyncdetach k
	end
end
async fn ticker
	while 1
		await asyncsleep 3
	end
end
fn nap ms b c d
	local ts 16
	store ts 0
	store ts+8 ms*1000000
	sys nanosleep ts 0
end
async fn worker
	ref nap as p
	await asyncblock p 150 0 0 0 as r
	ret r
end
async fn fresh
	ret 5
end
call asynclisten 0x7f000001 0 as l
call asyncport l as port
call serve l as s
call asyncdetach s
call ticker as t
call asyncdetach t
call worker as w
call asyncdetach w
await asyncconnect 0x7f000001 port as c
await asyncsleep 10
call fresh as f
call asyncdetach f
call asyncclock as t0
call asyncstop as n
call asyncclock as t1
call putn n
call putn closed
call putn (t1-t0)/1000000>100
call print " "
# again, from nothing
sys close c
call asynclisten 0x7f000001 0 as l
call asyncport l as port
call asyncaccept l as ha
await asyncconnect 0x7f000001 port as c
await ha as a
call asyncwrite c "x" as hw
await hw
await asyncread a rb 16 as m
await asyncsleep 2 as z
call putn m
call putn z
call asyncstop as n
call putn n
call print " "
# a task that waits for what only the program ends is left
call async 64 0 as e
call fresh as f
await f as x
call asyncstop as n
call putn n
call putn x
call print "\n"

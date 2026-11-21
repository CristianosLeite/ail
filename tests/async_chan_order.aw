# a channel of two values between a task that sends ten and one that
# receives: the values come in order, the sender waits when the channel
# is full, and after the channel is shut the receiver gets what is left
# and then -32
use "lib/io.aw"
use "lib/async/task.aw"
use "lib/async/chan.aw"
var most
async fn produce c
	i=1
	while i<=10
		await asyncsend c i*i
		load c+8 as n
		if n>most
			most=n
		end
		i+=1
	end
	call asyncshut c
	await asyncsend c 1 as r
	ret r
end
async fn consume c
	s=0
	while 1
		await asyncrecv c as v
		if v==-32
			ret s
		end
		call putn v
		call print " "
		s+=v
	end
end
call asyncchan 2 as c
call produce c as p
call consume c as q
await p as x
await q as y
call asyncchanfree c
call asyncrun as n
call putn 0-x
call print " "
call putn y
call putn most
call putn n
call print "\n"

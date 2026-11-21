# work for the pool when the pool has no thread: it is run by the thread
# that polls, and its event is done like any other
use "lib/task.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
use "lib/async/io.aw"
use "lib/async/pool.aw"
fn mul a b c d
	ret a*b
end
async fn f
	ref mul as p
	await asyncblock p 5 4 0 0 as x
	ret x
end
call workers 0
ref mul as p
await asyncblock p 6 7 0 0 as x
await f as y
call asyncstop as n
sys exit_group x+y+n

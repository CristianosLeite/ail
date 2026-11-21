# await of a handle, in an async function and at top level: the task
# waits for the other and has its result
use "lib/async/task.aw"
async fn mul a b
	ret a*b
end
async fn both a b
	call mul a b as h
	call mul b b as g
	await h as x
	await g as y
	ret x+y
end
call both 3 4 as h
await h as x
sys exit_group x

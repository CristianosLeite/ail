# work given to the pool: its result is awaited like any other, by a
# task and by the top level, and many pieces of work are all done
use "lib/task.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
use "lib/async/io.aw"
use "lib/async/pool.aw"
buf hs 8000
fn mul a b c d
	ret a*b+c-d
end
async fn f
	ref mul as p
	await asyncblock p 6 7 2 1 as x
	ret x
end
await f as x
ref mul as p
i=0
while i<1000
	call asyncblock p i 2 1 0 as h
	store hs+i*8 h
	i+=1
end
s=0
i=0
while i<1000
	load hs+i*8 as h
	await h as v
	s+=v
	i+=1
end
call asyncrun as n
sys exit_group (s==1000000)*100+x+n

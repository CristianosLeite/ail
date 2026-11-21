# a variable of an async function that no await falls into is in a
# register, one that is in use across an await in the record of its
# task: two tasks of one function, each leaving at its awaits while the
# other runs, must not see each other's values. s and k are in use
# across the awaits; t, u and v are computed and used between two; x
# is the result of an await, read before the next
use "lib/io.aw"
use "lib/async/task.aw"
async fn step n
	await asyncyield
	ret n*2+1
end
async fn work n k
	s=0
	i=0
	while i<5
		t=n+i
		u=t*k
		v=u^t
		s+=v
		await asyncyield
		t=s&255
		u=t+k
		await step u as x
		v=x-u
		s+=v*3
		i+=1
	end
	w=s%1000
	await asyncyield
	ret w+k
end
# the same without a task, to compare with
fn plain n k
	s=0
	i=0
	while i<5
		t=n+i
		u=t*k
		v=u^t
		s+=v
		t=s&255
		u=t+k
		x=u*2+1
		v=x-u
		s+=v*3
		i+=1
	end
	ret s%1000+k
end
call work 3 7 as a
call work 100 9 as b
call work 5 11 as c
await b as y
await a as x
await c as z
call plain 3 7 as p
call plain 100 9 as q
call plain 5 11 as r
call putn x
call print " "
call putn y
call print " "
call putn z
call print " "
call putn (x==p)+(y==q)+(z==r)
call print "\n"

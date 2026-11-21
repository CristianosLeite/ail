# bench/nd/mmtasks.aw -- time the product of matrices on one thread and
# in tasks. Stdin is six words of 8 bytes: the rows n of the first
# matrix, its columns m, the columns l of the second, the threads that
# may compute (the calling one among them), the tasks, and how often
# each product is called. It writes four numbers and a newline: the
# nanoseconds of the fastest ndmatmul, those of the first ndmatmulp,
# which also starts the threads, those of the fastest later one, and
# how many elements of the two results differ, which must be 0. The
# results are written once before any clock, so that no time is that of
# memory the kernel had not given yet. bench/nd/mmtasks.sh runs it for
# the table in docs/performance.md.
use "lib/io.aw"
use "lib/task.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "lib/nd/par.aw"
buf in 48
buf ts 16
buf a 176
buf b 176
buf o 176
buf q 176
fn now
	sys clock_gettime 1 ts
	load ts as s
	load ts+8 as n
	ret s*1000000000+n
end
# numbers with many digits: ((7i + s) mod 1000) / (i mod 13 + 3)
fn fill x s
	call ndsize x as n
	load x as p
	i=0
	while i<n
		itof (i*7+s)%1000 as u
		itof i%13+3 as v
		fdiv u v as u
		store p+i*8 u
		i+=1
	end
end
fn differ x y
	call ndsize x as n
	load x as p
	load y as r
	d=0
	i=0
	while i<n
		load p+i*8 as u
		load r+i*8 as v
		d+=u!=v
		i+=1
	end
	ret d
end
sys read 0 in 48 as r
if r!=48
	call die "mmtasks: six words on stdin\n"
end
load in as n
load in+8 as m
load in+16 as l
load in+24 as w
load in+32 as t
load in+40 as c
ifz w
	w=1
end
call ndmat a n m as r1
call ndmat b m l as r2
call ndmat o n l as r3
call ndmat q n l as r4
ifz r1&r2&r3&r4
	call die "mmtasks: no memory\n"
end
call fill a 1
call fill b 11
call fill o 5
call fill q 5
call workers w-1
best=0-1
i=0
while i<c
	call now as s
	call ndmatmul q a b
	call now as e
	if e-s<best
		best=e-s
	end
	i+=1
end
call now as s
call ndmatmulp o a b t as ok
call now as e
cold=e-s
warm=0-1
i=0
while i<c
	call now as s
	call ndmatmulp o a b t
	call now as e
	if e-s<warm
		warm=e-s
	end
	i+=1
end
call differ o q as d
call putn best
call print " "
call putn cold
call print " "
call putn warm
call print " "
call putn d+1-ok
call print "\n"

# lib/task.aw -- tasks: the functions that the statements spawn and join
# call, and the pool of threads that runs them. Put  use "lib/task.aw"  in
# a program that has them, compiled from the top of the repository. The
# file has no line that runs at its use: a program that never spawns pays
# nothing, and the first spawn finds everything zero.
#
# Every variable, parameter and label of this file has a name that starts
# with "task", as its functions and its buffer have: "as" on the name of a
# var writes that var in any function, so a short name here would be a
# var of a program that declared one before the use.
#
# A task is a record of 80 bytes, and its handle the address:
#    0  state: 0 waiting in the queue, 1 taken, 2 done, 3 taken and its
#       join asleep on this word
#    8  result
#   16  function
#   24  the five values
#   64  next and 72 previous task of the queue; 64 also links free records
#
# The state of the pool is the buffer taskq, every cell written under the
# lock except the two that a futex sleeps on:
#    0  lock: 0 free, 1 held, 2 held and someone asleep on it
#    8  count of the tasks ever queued, on which idle workers sleep
#   16  first and 24 last task waiting
#   32  how many wait
#   40  workers asleep
#   48  workers started
#   56  the most workers there may be, valid when 64 is not zero
#   72  free records, which come in blocks and are never given back
buf taskq 80

# take the lock: after a few tries, asleep in the kernel while another
# thread holds it. The lock is held for a few instructions, so a try
# mostly succeeds where a sleep would cost two system calls.
fn tasklock
	taskn=100
	while taskn
		cas taskq 0 1 as taskk
		jnz taskk taskx
		taskn-=1
	end
	label taska
	cas taskq 1 2 as taskk
	sys futex taskq 128 2 0
	cas taskq 0 2 as taskk
	jz taskk taska
	label taskx
end

# release it, and wake one thread if any may be asleep on it
fn taskunlock
	xadd taskq -1 as tasks
	if tasks!=1
		store taskq 0
		sys futex taskq 129 1
	end
end

# "call workers n": at most n threads run tasks, besides the threads that
# join them. Without it the limit is the number of processors the program
# may use. Workers already started stay.
fn workers taskn
	call tasklock
	store taskq+56 taskn
	store taskq+64 1
	call taskunlock
end

# the processors this process may run on; 1 if the kernel does not say
fn taskcpus
	local taskm 128
	sys sched_getaffinity 0 128 taskm as taskr
	if taskr>128
		ret 1
	end
	taskc=0
	while taskr
		taskr-=1
		loadb taskm+taskr as taskb
		while taskb
			taskb&=taskb-1
			taskc+=1
		end
	end
	ret taskc
end

# take the waiting task out of the queue; the caller holds the lock
fn tasktake taskt
	load taskt+64 as taskn
	load taskt+72 as taskp
	if taskp
		store taskp+64 taskn
	else
		store taskq+16 taskn
	end
	if taskn
		store taskn+72 taskp
	else
		store taskq+24 taskp
	end
	load taskq+32 as taskc
	store taskq+32 taskc-1
	store taskt 1
end

# run the task, which the caller has taken, and wake its join if that
# went to sleep. After the state is 2 the record may be gone.
fn taskrun taskt
	load taskt+16 as taskp
	load taskt+24 as taska
	load taskt+32 as taskb
	load taskt+40 as taskc
	load taskt+48 as taskd
	load taskt+56 as taske
	callp taskp taska taskb taskc taskd taske as taskx
	store taskt+8 taskx
	cas taskt 1 2 as taskk
	ifz taskk
		store taskt 2
		sys futex taskt 129 1
	end
end

# a worker: run the tasks of the queue, sleep while there are none. It
# never returns; the end of the program ends it.
fn taskwork
	label tasktop
	call tasklock
	label tasklook
	load taskq+16 as taskt
	ifz taskt
		load taskq+8 as tasks
		load taskq+40 as taski
		store taskq+40 taski+1
		call taskunlock
		sys futex taskq+8 128 tasks 0
		call tasklock
		load taskq+40 as taski
		store taskq+40 taski-1
		jmp tasklook
	end
	call tasktake taskt
	call taskunlock
	call taskrun taskt
	jmp tasktop
end

# start a worker: a thread on a stack of 8 MiB whose lowest page is closed
# before the thread exists, so that a task that needs more faults. 1 if it
# runs, 0 if the kernel refused the memory, the closed page or the thread;
# the stack is given back then. The stack is a mapping of its own and not
# an alloc, whose length would stand in the closed page. The new thread
# comes out of clone on the new stack with the registers of this one, so
# nothing between the clone and the call of taskwork may be kept in the
# frame: this function has two variables, which have registers.
fn taskstart
	sys mmap 0 8388608 3 0x22 -1 0 as tasks
	if tasks>-4096
		ret 0
	end
	sys mprotect tasks 4096 0 as taskr
	ifz taskr
		sys clone 0x50f00 tasks+8388608 0 0 0 as taskr
		ifz taskr
			call taskwork
		end
		if taskr<-4095
			ret 1
		end
	end
	sys munmap tasks 8388608
	ret 0
end

# 819 free records in one block of 64 KiB from alloc, linked; 0 if there
# is no memory. A task of its own mapping would be a page and a system
# call for 80 bytes.
fn taskmore
	alloc 65520 as taskt
	ifz taskt
		ret 0
	end
	taskp=taskt
	taskn=818
	while taskn
		store taskp+64 taskp+80
		taskp+=80
		taskn-=1
	end
	store taskp+64 0
	ret taskt
end

# put the task at the end of the queue; 1 if an idle worker is to be
# woken, 2 if a worker is to be started: when more tasks wait than workers
# sleep and the limit allows one more. The caller holds the lock.
fn taskput taskt
	store taskt+64 0
	load taskq+24 as taskn
	store taskt+72 taskn
	if taskn
		store taskn+64 taskt
	else
		store taskq+16 taskt
	end
	store taskq+24 taskt
	load taskq+8 as taskn
	store taskq+8 taskn+1
	load taskq+32 as taskn
	taskn+=1
	store taskq+32 taskn
	load taskq+40 as taski
	taskw=taski!=0
	if taskn>taski
		load taskq+64 as taskk
		ifz taskk
			call taskcpus as taskk
			store taskq+56 taskk
			store taskq+64 1
		end
		load taskq+48 as taskk
		load taskq+56 as taskm
		if taskk<taskm
			store taskq+48 taskk+1
			taskw=2
		end
	end
	ret taskw
end

# "spawn f a b c d e as h": a task that will call the function f with
# the five values; 0 if there is no memory for it
fn spawn taskp taska taskb taskc taskd taske
	call tasklock
	load taskq+72 as taskt
	ifz taskt
		call taskmore as taskt
		ifz taskt
			call taskunlock
			ret 0
		end
	end
	load taskt+64 as taskn
	store taskq+72 taskn
	store taskt 0
	store taskt+16 taskp
	store taskt+24 taska
	store taskt+32 taskb
	store taskt+40 taskc
	store taskt+48 taskd
	store taskt+56 taske
	call taskput taskt as taskw
	call taskunlock
	if taskw==1
		sys futex taskq+8 129 1
	end
	if taskw==2
		call taskstart as taskk
		ifz taskk
			call tasklock
			load taskq+48 as taskk
			store taskq+48 taskk-1
			call taskunlock
		end
	end
	ret taskt
end

# "join h as x": the result of the task h. A task still in the queue is
# run here; one that a worker took is waited for. The record is free
# afterwards. The result of no task is 0.
fn join taskt
	ifz taskt
		ret 0
	end
	load taskt as tasks
	ifz tasks
		call tasklock
		load taskt as tasks
		ifz tasks
			call tasktake taskt
			call taskunlock
			call taskrun taskt
			jmp taskdone
		end
		call taskunlock
	end
	label taskw
	load taskt as tasks
	if tasks!=2
		cas taskt 1 3 as taskk
		sys futex taskt 128 3 0
		jmp taskw
	end
	label taskdone
	load taskt+8 as taskx
	call tasklock
	load taskq+72 as taskn
	store taskt+64 taskn
	store taskq+72 taskt
	call taskunlock
	ret taskx
end

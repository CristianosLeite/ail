# lib/queue.aw -- a queue of 64-bit values with a fixed room.
#
# A queue is 32 bytes that the caller owns, in a buf or a local: the
# address of its values, the number there is room for, the index of the
# oldest and the number it holds. The values are a ring: the one after
# the last place is the first. The functions take the address of the 32
# bytes, here called the queue.
#
# queueinit gives a queue that is all zero its room, queuen values, with
# one alloc: 1, or 0 when the kernel has no memory or the room would not
# fit in 64 bits of bytes, and then the queue is as it was. The room
# never changes and the values never move. queuepush returns 0 when the
# queue is full and queuepop 0 and 0 when it is empty, a value and 1
# otherwise, since a value may be 0; a queue that is all zero is full
# and empty. The caller ends the queue with queuefree, after which it is
# all zero again.
#
# Every variable and parameter of this file has a name that starts with
# "queue"; a program has no var of such a name (see lib/io.aw).

# room for queuen values
fn queueinit queueq queuen
	# bytes that do not fit in 64 bits are no memory
	if queuen>>61
		ret 0
	end
	alloc queuen*8 as queuep
	ifz queuep
		ret 0
	end
	store queueq queuep
	store queueq+8 queuen
	store queueq+16 0
	store queueq+24 0
	ret 1
end

# add the value queuex as the newest: 1, or 0 if there is no room
fn queuepush queueq queuex
	load queueq+8 as queuen
	load queueq+24 as queuec
	if queuec>=queuen
		ret 0
	end
	load queueq as queuep
	load queueq+16 as queuei
	queuei+=queuec
	if queuei>=queuen
		queuei-=queuen
	end
	store queuep+queuei*8 queuex
	store queueq+24 queuec+1
	ret 1
end

# take the oldest value out: the value and 1, or 0 and 0 if there is none
fn queuepop queueq
	load queueq+24 as queuec
	ifz queuec
		ret 0 0
	end
	load queueq as queuep
	load queueq+8 as queuen
	load queueq+16 as queuei
	load queuep+queuei*8 as queuex
	queuei+=1
	if queuei==queuen
		queuei=0
	end
	store queueq+16 queuei
	store queueq+24 queuec-1
	ret queuex 1
end

# give the room back; the queue is all zero and may be given room again
fn queuefree queueq
	load queueq as queuep
	if queuep
		free queuep
	end
	store queueq 0
	store queueq+8 0
	store queueq+16 0
	store queueq+24 0
end

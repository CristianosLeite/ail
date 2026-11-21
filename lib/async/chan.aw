# lib/async/chan.aw -- for the tasks of lib/async/task.aw, which a
# program uses before this file: channels, which carry values from task
# to task and hold a limited number of them, and the wait for the first
# of several things. The file has no line that runs at its use.
#
# Every variable, parameter and label of this file has a name that starts
# with "async", as its functions have.
#
# A channel is a record from asyncget:
#    0  how many values it holds at most
#    8  how many it holds
#   16  the index of the oldest
#   32  1 once it is shut
#   40  first and 48 last event of a send that waits for room
#   56  first and 64 last event of a receive that waits for a value
#   72  the values, a ring
# An event that waits has the channel at 64, the value of a send at 72,
# the next event of its list at 80 and 1 at 88 if it receives.

# "call asyncchan n as c": a channel that holds up to n values, at least
# one; 0 if there is no memory
fn asyncchan asyncn
	ifz asyncn
		asyncn=1
	end
	if asyncn>>32
		ret 0
	end
	call asyncget asyncn*8+72 as asyncc
	ifz asyncc
		ret 0
	end
	store asyncc asyncn
	store asyncc+8 0
	store asyncc+16 0
	store asyncc+32 0
	store asyncc+40 0
	store asyncc+48 0
	store asyncc+56 0
	store asyncc+64 0
	ret asyncc
end

# take the first event out of the list at asynco of the channel
fn asyncchpop asyncc asynco
	load asyncc+asynco as asynch
	load asynch+80 as asyncn
	store asyncc+asynco asyncn
	ifz asyncn
		store asyncc+asynco+8 0
	end
	call asyncdisarm asynch
	ret asynch
end

# what asynccancel calls for a send or a receive that waits: it waits
# no longer
fn asyncchoff asynch
	load asynch+64 as asyncc
	load asynch+88 as asynco
	asynco=asynco*16+40
	asyncp=0
	load asyncc+asynco as asyncx
	while asyncx!=asynch
		asyncp=asyncx
		load asyncx+80 as asyncx
	end
	load asynch+80 as asyncn
	if asyncp
		store asyncp+80 asyncn
	else
		store asyncc+asynco asyncn
	end
	ifz asyncn
		store asyncc+asynco+8 asyncp
	end
end

# an event that waits in the list at asynco of the channel, with the
# value asyncv; 0 if there is no memory
fn asyncchwait asyncc asynco asyncv
	call async 128 0 as asynch
	ifz asynch
		ret 0
	end
	store asynch+64 asyncc
	store asynch+72 asyncv
	store asynch+80 0
	store asynch+88 asynco==56
	load asyncc+asynco+8 as asyncx
	if asyncx
		store asyncx+80 asynch
	else
		store asyncc+asynco asynch
	end
	store asyncc+asynco+8 asynch
	ref asyncchoff as asyncf
	call asyncarm asynch asyncf
	ret asynch
end

# an event that is done already, with the result asyncv
fn asyncdone asyncv
	call async 64 0 as asynch
	if asynch
		call asyncfinish asynch asyncv
	end
	ret asynch
end

# "call asyncsend c v as h": an event that is done, with the result 0,
# when the channel has taken the value: at once if a receive waits for
# one or there is room, else when a receive has made room. Values are
# received in the order of their sends. The result is -32 if the channel
# is shut, now or while the send waits.
fn asyncsend asyncc asyncv
	load asyncc+32 as asyncx
	if asyncx
		tail asyncdone -32
	end
	load asyncc+56 as asynch
	if asynch
		call asyncchpop asyncc 56
		call asyncfinish asynch asyncv
		tail asyncdone 0
	end
	load asyncc as asyncm
	load asyncc+8 as asyncn
	if asyncn<asyncm
		load asyncc+16 as asynci
		store asyncc+72+(asynci+asyncn)%asyncm*8 asyncv
		store asyncc+8 asyncn+1
		tail asyncdone 0
	end
	tail asyncchwait asyncc 40 asyncv
end

# "call asyncrecv c as h": an event whose result is the oldest value of
# the channel: at once if it holds one, else when one is sent. The
# result is -32 if the channel is shut and holds nothing more, so a
# program that sends such numbers tells the end another way.
fn asyncrecv asyncc
	load asyncc+8 as asyncn
	if asyncn
		load asyncc as asyncm
		load asyncc+16 as asynci
		load asyncc+72+asynci*8 as asyncv
		asynci=(asynci+1)%asyncm
		store asyncc+16 asynci
		asyncn-=1
		# a send that waited has room now
		load asyncc+40 as asynch
		if asynch
			call asyncchpop asyncc 40
			load asynch+72 as asyncx
			store asyncc+72+(asynci+asyncn)%asyncm*8 asyncx
			asyncn+=1
			call asyncfinish asynch 0
		end
		store asyncc+8 asyncn
		tail asyncdone asyncv
	end
	load asyncc+32 as asyncx
	if asyncx
		tail asyncdone -32
	end
	tail asyncchwait asyncc 56 0
end

# "call asyncshut c": no more values. Sends that wait, and receives that
# wait, end with -32; the values the channel holds are still received.
fn asyncshut asyncc
	store asyncc+32 1
	asynco=40
	while asynco<72
		label asyncnext
		load asyncc+asynco as asynch
		if asynch
			call asyncchpop asyncc asynco
			call asyncfinish asynch -32
			jmp asyncnext
		end
		asynco+=16
	end
end

# "call asyncchanfree c": shut the channel and give its record back
fn asyncchanfree asyncc
	call asyncshut asyncc
	tail asyncfree asyncc
end

# The first of several: a task with the number of handles at 64 and the
# handles from 128. It is the one that each of them wakes; its result is
# the index of the first that is done, the lowest if several are. None
# of them is awaited by it: the program awaits the one that is done,
# which gives the result at once, and goes on with the others or
# cancels them.
fn asyncanyp asynct
	load asynct+64 as asyncn
	asynci=0
	while asynci<asyncn
		load asynct+128+asynci*8 as asynch
		asyncs=4
		if asynch
			load asynch+24 as asyncs
		end
		if asyncs&4
			call asyncdisarm asynct
			call asyncanyoff asynct
			store asynct+16 asynci
			ret 1
		end
		asynci+=1
	end
	asynci=0
	while asynci<asyncn
		load asynct+128+asynci*8 as asynch
		store asynch+40 asynct
		asynci+=1
	end
	ret 0
end

# what asynccancel calls for it, and what it does when it is done: the
# handles wake nobody
fn asyncanyoff asynct
	load asynct+64 as asyncn
	asynci=0
	while asynci<asyncn
		load asynct+128+asynci*8 as asynch
		if asynch
			store asynch+40 0
		end
		asynci+=1
	end
end

# "call asyncany p n as g": a task that is done when the first of the n
# handles at p is, an array of 8 bytes each, with its index as the
# result; the handles stay the program's. No other task awaits one of
# them meanwhile. 0 if there is no memory.
fn asyncany asyncp asyncn
	ref asyncanyp as asyncf
	call async asyncn*8+128 asyncf as asynct
	ifz asynct
		ret 0
	end
	store asynct+64 asyncn
	asynci=0
	while asynci<asyncn
		load asyncp+asynci*8 as asynch
		store asynct+128+asynci*8 asynch
		asynci+=1
	end
	ref asyncanyoff as asyncf
	call asyncarm asynct asyncf
	ret asynct
end

# "call asyncfirst a b as g": the same for two handles: 0 if a is done
# first, 1 if b is
fn asyncfirst asynca asyncb
	local asyncp 16
	store asyncp asynca
	store asyncp+8 asyncb
	tail asyncany asyncp 2
end

# lib/async/io.aw -- files that the tasks of lib/async/task.aw wait for:
# reading, writing, accepting and connecting as events that are done when
# the kernel has done the work, with epoll to say when it can. A program
# uses lib/async/task.aw and lib/async/time.aw before this file. The file
# has no line that runs at its use; the first operation finds everything
# zero and makes the epoll object.
#
# Every variable, parameter and label of this file has a name that starts
# with "async", as its functions, constants and buffers have.
#
# An operation first asks the kernel. Only when that says "not now"
# (EAGAIN) does the event wait, in a list of its file, for the kernel to
# report the file ready, and is asked again then. A file is registered
# once, when the library first sees it, for both directions and for
# changes only (edge-triggered): the change that is reported is always
# one that came after an EAGAIN.
#
# A file the library knows is a record from asyncget:
#    0  the descriptor
#    8  its generation: a number that no other record has
#   16  bit 0 if epoll watches it, a plain file being never "not now";
#       bit 1 once it is known to be no socket
#   40  first and 48 last event that waits to read or accept
#   56  first and 64 last event that waits to write or connect
# asyncio: 0 the epoll descriptor plus 1, 8 the table of the records by
# descriptor, 16 how many descriptors it has room for, 24 the generation
# given last. An epoll event carries descriptor and generation, so that
# one for a descriptor that was closed and given out again is dropped.
#
# An event of an operation has these values:
#   64  the record of its file
#   72  kind: 1 read, 2 accept, 3 write, 4 write all, 5 connect
#   80  address and 88 length of the bytes
#   96  next event of the list
#  104  bytes written so far (kind 4); 1 once connect was called (kind 5)
# For a connect 80 and 88 are the address and the port.
buf asyncio 32
buf asyncev 768
const asyncfcntl 72
const asyncsetsockopt 54
const asyncgetsockopt 55
const asyncgetsockname 51
const asyncaccept4 288
const asyncepollcreate 291
const asyncepollctl 233
const asyncepollwait 232
const asyncsendto 44
const asyncsigmask 14
const asyncsigwait 128

# what asynctick calls to sleep: wait at most asyncms milliseconds (-1:
# without limit) for files to be ready, and ask again the events that
# wait for them
fn asyncpoll asyncms
	load asyncio as asyncep
	sys asyncepollwait asyncep-1 asyncev 64 asyncms as asyncn
	if asyncn>64
		ret 0
	end
	asynci=0
	while asynci<asyncn
		asynce=asyncev+asynci*12
		load4 asynce as asyncm
		load asynce+4 as asyncd
		asyncfd=asyncd&0xffffffff
		load asyncio+16 as asyncc
		if asyncfd<asyncc
			load asyncio+8 as asynct
			load asynct+asyncfd*8 as asyncr
			if asyncr
				load asyncr+8 as asyncg
				if asyncg==asyncd>>32
					if asyncm&0x2019
						call asyncready asyncr 40
					end
					if asyncm&28
						call asyncready asyncr 56
					end
				end
			end
		end
		asynci+=1
	end
	ret asyncn
end

# ask the events of one list of the file again, in their order, until
# one has to go on waiting
fn asyncready asyncr asynco
	label asyncnext
	load asyncr+asynco as asynch
	if asynch
		call asynctry asynch as asyncd
		jeq asyncd 1 asyncnext
	end
end

# take the event out of the list it waits in
fn asyncunlist asynch
	load asynch+64 as asyncr
	load asynch+72 as asynck
	asynco=40
	if asynck>2
		asynco=56
	end
	asyncp=0
	load asyncr+asynco as asyncx
	while asyncx!=asynch
		asyncp=asyncx
		load asyncx+96 as asyncx
	end
	load asynch+96 as asyncn
	if asyncp
		store asyncp+96 asyncn
	else
		store asyncr+asynco asyncn
	end
	ifz asyncn
		store asyncr+asynco+8 asyncp
	end
	call asyncdisarm asynch
	load asyncq+112 as asyncx
	store asyncq+112 asyncx-1
end

# what asynccancel calls for an event that waits: it waits no longer,
# and a socket that was connecting is closed
fn asyncopoff asynch
	call asyncunlist asynch
	load asynch+72 as asynck
	if asynck==5
		load asynch+64 as asyncr
		load asyncr as asyncfd
		call asyncclose asyncfd
	end
end

# write to the file of the record asyncr, with the result of write, and
# without the signal that the kernel sends a process that writes where
# nobody reads any more (SIGPIPE), which would end the program before
# the event could say -32. A socket is written with sendto and the flag
# that leaves the signal out; that it is none is found once, by the
# error. For a pipe the signal is blocked for this thread around the
# write, and one that the write made is taken back, unless the program
# had blocked it itself. A plain file has no such signal.
fn asyncput asyncr asyncfd asyncp asyncn
	load asyncr+16 as asyncf
	ifz asyncf&2
		sys asyncsendto asyncfd asyncp asyncn 0x4000 0 0 as asyncx
		if asyncx!=-88
			ret asyncx
		end
		asyncf|=2
		store asyncr+16 asyncf
	end
	ifz asyncf&1
		sys write asyncfd asyncp asyncn as asyncx
		ret asyncx
	end
	local asyncm 32
	store asyncm 4096
	sys asyncsigmask 0 asyncm asyncm+8 8
	sys write asyncfd asyncp asyncn as asyncx
	if asyncx==-32
		load asyncm+8 as asynco
		ifz asynco&4096
			store asyncm+16 0
			store asyncm+24 0
			sys asyncsigwait asyncm 0 asyncm+16 8
		end
	end
	sys asyncsigmask 2 asyncm+8 0 8
	ret asyncx
end

# ask the kernel to do the work of the event: 0 if the kernel said "not
# now", else the event is done, with the result of the kernel, and out
# of the list it waited in: 1, or 2 if its file is closed as well, a
# socket that could not connect. The event may be free afterwards.
fn asynctry asynch
	asyncx=-22
	load asynch+64 as asyncr
	load asyncr as asyncfd
	load asynch+72 as asynck
	load asynch+80 as asyncp
	load asynch+88 as asyncn
	if asynck==1
		sys read asyncfd asyncp asyncn as asyncx
	end
	if asynck==2
		sys asyncaccept4 asyncfd 0 0 0x80800 as asyncx
	end
	if asynck==3
		call asyncput asyncr asyncfd asyncp asyncn as asyncx
	end
	if asynck==4
		load asynch+104 as asyncd
		asyncx=asyncn
		while asyncd<asyncn
			call asyncput asyncr asyncfd asyncp+asyncd asyncn-asyncd as asyncx
			if asyncx>-4096
				store asynch+104 asyncd
				jmp asyncout
			end
			asyncd+=asyncx
			asyncx=asyncn
		end
	end
	if asynck==5
		load asynch+104 as asyncd
		if asyncd
			local asyncv 16
			store asyncv 0
			store asyncv+8 4
			sys asyncgetsockopt asyncfd 1 4 asyncv asyncv+8 as asyncx
			ifz asyncx
				load4 asyncv as asyncx
				asyncx=0-asyncx
			end
		else
			store asynch+104 1
			local asynca 16
			call asyncaddr asynca asyncp asyncn
			sys connect asyncfd asynca 16 as asyncx
			if asyncx==-115
				ret 0
			end
		end
		if asyncx
			if asyncd
				call asyncunlist asynch
			end
			call asyncclose asyncfd
			call asyncfinish asynch asyncx
			ret 2
		end
		asyncx=asyncfd
	end
	label asyncout
	if asyncx==-11
		ret 0
	end
	load asynch+56 as asyncd
	if asyncd
		call asyncunlist asynch
	end
	call asyncfinish asynch asyncx
	ret 1
end

# the epoll descriptor plus 1, made at the first call, from when on the
# thread sleeps in asyncpoll; or the error of the kernel, negated
fn asyncepoll
	load asyncio as asyncep
	ifz asyncep
		sys asyncepollcreate 0x80000 as asyncep
		if asyncep>-4096
			ret asyncep
		end
		asyncep+=1
		store asyncio asyncep
		ref asyncpoll as asyncf
		store asyncq+104 asyncf
		ref asynctick as asyncf
		store asyncq+24 asyncf
		ref asyncioend as asyncf
		store asyncq+144 asyncf
	end
	ret asyncep
end

# what asyncstop calls: forget every descriptor, which the program still
# holds and closes, and give back the table and the epoll object. The
# next operation finds everything zero again.
fn asyncioend
	load asyncio+8 as asynct
	load asyncio+16 as asyncc
	asynci=0
	while asynci<asyncc
		load asynct+asynci*8 as asyncr
		if asyncr
			call asyncfree asyncr
		end
		asynci+=1
	end
	if asynct
		free asynct
	end
	load asyncio as asyncep
	sys close asyncep-1
	store asyncio 0
	store asyncio+8 0
	store asyncio+16 0
	store asyncq+104 0
end

# the record of the descriptor, made and registered if the library sees
# the descriptor for the first time, which also makes it non-blocking;
# or an error of the kernel, negated
fn asyncfile asyncfd
	if asyncfd>0x7fffffff
		ret -9
	end
	load asyncio+16 as asyncc
	if asyncfd>=asyncc
		asyncn=asyncc*2+64
		while asyncfd>=asyncn
			asyncn*=2
		end
		alloc asyncn*8 as asynct
		ifz asynct
			ret -12
		end
		load asyncio+8 as asynco
		asynci=0
		while asynci<asyncc
			load asynco+asynci*8 as asyncx
			store asynct+asynci*8 asyncx
			asynci+=1
		end
		if asynco
			free asynco
		end
		store asyncio+8 asynct
		store asyncio+16 asyncn
	end
	load asyncio+8 as asynct
	load asynct+asyncfd*8 as asyncr
	if asyncr
		ret asyncr
	end
	call asyncepoll as asyncep
	if asyncep>-4096
		ret asyncep
	end
	sys asyncfcntl asyncfd 3 as asyncx
	if asyncx>-4096
		ret asyncx
	end
	ifz asyncx&0x800
		sys asyncfcntl asyncfd 4 asyncx|0x800
	end
	call asyncget 128 as asyncr
	ifz asyncr
		ret -12
	end
	load asyncio+24 as asyncg
	asyncg+=1
	store asyncio+24 asyncg
	store asyncr asyncfd
	store asyncr+8 asyncg&0xffffffff
	store asyncr+40 0
	store asyncr+48 0
	store asyncr+56 0
	store asyncr+64 0
	local asynce 16
	store4 asynce 0x80002005
	store asynce+4 (asyncg<<32)|asyncfd
	sys asyncepollctl asyncep-1 1 asyncfd asynce as asyncx
	store asyncr+16 asyncx==0
	if asyncx
		if asyncx!=-1
			call asyncfree asyncr
			ret asyncx
		end
	end
	store asynct+asyncfd*8 asyncr
	ret asyncr
end

# an event for the work asynck on the descriptor: done at once if the
# kernel does it at once, else waiting in the list of the file, behind
# the events that wait there already. 0 if there is no memory.
# For a connect asyncp and asyncn are address and port.
fn asyncop asyncfd asynck asyncp asyncn
	call async 128 0 as asynch
	ifz asynch
		ret 0
	end
	call asyncfile asyncfd as asyncr
	if asyncr>-4096
		if asynck==5
			sys close asyncfd
		end
		call asyncfinish asynch asyncr
		ret asynch
	end
	store asynch+64 asyncr
	store asynch+72 asynck
	store asynch+80 asyncp
	store asynch+88 asyncn
	store asynch+96 0
	store asynch+104 0
	asynco=40
	if asynck>2
		asynco=56
	end
	load asyncr+asynco as asyncx
	ifz asyncx
		call asynctry asynch as asyncd
		if asyncd
			ret asynch
		end
		load asyncr+16 as asyncd
		ifz asyncd
			call asyncfinish asynch -11
			ret asynch
		end
	end
	load asyncr+asynco+8 as asyncx
	if asyncx
		store asyncx+96 asynch
	else
		store asyncr+asynco asynch
	end
	store asyncr+asynco+8 asynch
	ref asyncopoff as asyncf
	call asyncarm asynch asyncf
	load asyncq+112 as asyncx
	store asyncq+112 asyncx+1
	ret asynch
end

# "call asyncread fd p n as h": an event whose result is what read
# gives: the number of bytes now at p, at most n and 0 at the end of the
# file, or an error of the kernel, negated
fn asyncread asyncfd asyncp asyncn
	tail asyncop asyncfd 1 asyncp asyncn
end

# "call asyncwrite fd p n as h": the same for write: how many of the n
# bytes the kernel took, which may be fewer
fn asyncwrite asyncfd asyncp asyncn
	tail asyncop asyncfd 3 asyncp asyncn
end

# "call asyncwriteall fd p n as h": done when all n bytes are written,
# with the result n, or after an error, with the error
fn asyncwriteall asyncfd asyncp asyncn
	tail asyncop asyncfd 4 asyncp asyncn
end

# "call asyncaccept fd as h": an event whose result is the descriptor of
# the next connection to the listening socket fd, or an error
fn asyncaccept asyncfd
	tail asyncop asyncfd 2 0 0
end

# "call asyncconnect ip port as h": an event whose result is a socket
# connected to that port of the IPv4 address ip, a number (127.0.0.1 is
# 0x7f000001), or an error, after which there is no socket
fn asyncconnect asyncip asyncport
	sys socket 2 0x80801 0 as asyncfd
	if asyncfd>-4096
		call async 64 0 as asynch
		if asynch
			call asyncfinish asynch asyncfd
		end
		ret asynch
	end
	call asyncop asyncfd 5 asyncip asyncport as asynch
	ifz asynch
		sys close asyncfd
		ret 0
	end
	ret asynch
end

# "call asynclisten ip port as fd": a socket that listens on that port
# of the IPv4 address ip (0: every address of the machine); with port 0
# the kernel chooses one, which asyncport tells. The descriptor, or an
# error of the kernel, negated.
fn asynclisten asyncip asyncport
	sys socket 2 0x80801 0 as asyncfd
	if asyncfd>-4096
		ret asyncfd
	end
	local asynca 16
	store asynca 1
	sys asyncsetsockopt asyncfd 1 2 asynca 4
	call asyncaddr asynca asyncip asyncport
	sys bind asyncfd asynca 16 as asyncx
	ifz asyncx
		sys listen asyncfd 4096 as asyncx
	end
	if asyncx
		sys close asyncfd
		ret asyncx
	end
	ret asyncfd
end

# write the socket address of an IPv4 address and a port at asynca
fn asyncaddr asynca asyncip asyncport
	store asynca 0
	store asynca+8 0
	store2 asynca 2
	storeb asynca+2 asyncport>>8
	storeb asynca+3 asyncport
	storeb asynca+4 asyncip>>24
	storeb asynca+5 asyncip>>16
	storeb asynca+6 asyncip>>8
	storeb asynca+7 asyncip
end

# the port of the socket fd, or an error of the kernel, negated
fn asyncport asyncfd
	local asynca 24
	store asynca+16 16
	sys asyncgetsockname asyncfd asynca asynca+16 as asyncx
	if asyncx
		ret asyncx
	end
	loadb asynca+2 as asynch
	loadb asynca+3 as asyncl
	ret asynch<<8|asyncl
end

# "call asyncclose fd": close the descriptor, after ending the events
# that wait for it with the result -125. The result is that of close.
fn asyncclose asyncfd
	load asyncio+16 as asyncc
	if asyncfd<asyncc
		load asyncio+8 as asynct
		load asynct+asyncfd*8 as asyncr
		if asyncr
			store asynct+asyncfd*8 0
			# out of epoll while the number still names the file: a copy of the
			# descriptor would keep the registration alive after the close
			load asyncr+16 as asyncx
			if asyncx&1
				load asyncio as asyncep
				sys asyncepollctl asyncep-1 2 asyncfd 0
			end
			asynco=40
			while asynco<72
				label asyncnext
				load asyncr+asynco as asynch
				if asynch
					call asyncunlist asynch
					call asyncfinish asynch -125
					jmp asyncnext
				end
				asynco+=16
			end
			call asyncfree asyncr
		end
	end
	sys close asyncfd as asyncx
	ret asyncx
end

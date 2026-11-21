# tools/perf.aw -- time each example against its C, Rust and assembly
# equivalent.
#
#   build/tools/perf [--cpu N] [--quick] [name ...]   (default: every program)
#
# Run from the top of the repository after make. Needs gcc and rustc.
#
# The AIL program is build/<name>; the others are built from bench/ into
# build/perf/ with the flags below. A language without a source for a
# program is left out of its row. Every binary must give the expected
# output and exit status before anything is timed. A run is the child
# process of lib/proc.aw (fork, dup2, execve) and the wait for it, with
# stdin from a file and stdout to /dev/null, on one CPU, the languages in
# a shuffled order in every round (tools/lib/rng.aw from the seed 77); the
# figure is the median, with the quartiles after it.
#
# Startup programs do almost nothing, so their time is the cost of
# starting a process; they are reported apart from the CPU-bound ones,
# for which the ratio to C and its geometric mean are given.
#
# Status 0, or 1 with a line "perf: ..." on stderr.
use "lib/io.aw"
use "lib/bytes.aw"
use "lib/file.aw"
use "lib/proc.aw"
use "tools/lib/rng.aw"
use "tools/lib/fmt.aw"

# ---- the programs: tool-local data

# the name; 0 startup or 1 CPU-bound; what it reads; what it must write;
# the status it must end with
data progs 5 "hello" 4 "echo" 5 "count" 4 "fact" 4 "loop"
data 7 "compute" 5 "sieve" 7 "collatz" 3 "fnv" 5 "isort"
data pkind 0 0 0 0 0 1 1 1 1 1
# 0 nothing, 1 the bytes 0 to 255 sixteen times, 2 the number
# 0x123456789abcdef0 as 8 bytes, 3 16000000 so, 4 500000 so, 5 the bytes 0
# to 255 4096 times
data pinput 0 1 1 0 0 2 3 4 5 2
# 0 nothing, 1 the greeting, 2 its input, 3 the count, 4 the digits,
# 9 whatever the C program writes
data pwant 1 2 3 0 4 9 9 9 9 9
data pstat 0 0 0 120 0 0 0 0 0 0
const nprogs 10
data langs 3 "AIL" 1 "C" 4 "Rust" 3 "asm"
data sgcc "gcc" 0
data so3 "-O3" 0
data srustc "rustc" 0
data so "-O" 0
data sdasho "-o" 0
data sas "as" 0
data sld "ld" 0
data sversion "--version" 0

# the state of the random numbers
buf rs 8
# a line for stdout
buf ob 24
# the input of the program at work, what it must write, what it wrote
buf binp 24
buf bwant 24
buf bgot 24
# the paths of the program at work, each with a NUL byte after it, and
# where each starts: the four executables in the order of langs, the
# sources of C, Rust and assembly, the object file, the input, the output
buf strs 24
buf pa 80
# the arguments of a child
buf av 64
# the times of the rounds, 500 for each language, and the order of a round
buf samp 16000
buf ord 32
# the results: for each program and language 32 bytes, 1 if there is a
# figure, the median as a double, the two quartiles as numbers
buf res 1280
# the programs asked for, in their order, and their number
buf sel 80
var gnsel

fn fail m mn
	call eprint "perf: "
	call eprint m mn
	call eprint "\n"
	sys exit_group 1
end

# three pieces of text and the end; "perf: " is written before it
fn fail3 a an b bn c cn
	call eprint a an
	call eprint b bn
	call eprint c cn
	call eprint "\n"
	sys exit_group 1
end

# 0 is no memory
fn must r
	ifz r
		call fail "out of memory"
	end
end

fn add b p n
	call byadd b p n as r
	call must r
end

fn addn b v
	call byaddn b v as r
	call must r
end

# entry i of a list in which each entry is its length in a byte and then
# its bytes: its address and length
fn item p i
	while i
		loadb p as n
		p+=n+1
		i-=1
	end
	loadb p as n
	ret p+1 n
end

# print the line in ob
fn say
	load ob as p
	load ob+8 as n
	call print p n
	call bycut ob 0
end

# the unsigned decimal number of n bytes at p, and 1; or 0 and 0
fn num p n
	ifz n
		ret 0 0
	end
	v=0
	while n
		loadb p as c
		if c-48>=10
			ret 0 0
		end
		v=v*10+c-48
		p+=1
		n-=1
	end
	ret v 1
end

# 1 if the n bytes at p are the m bytes at q
fn same p n q m
	if n!=m
		ret 0
	end
	while n
		loadb p as c
		loadb q as d
		if c!=d
			ret 0
		end
		p+=1
		q+=1
		n-=1
	end
	ret 1
end

# ---- the files of one program

# add a path of three pieces to strs, with a NUL byte: where it starts
fn path a an b bn c cn
	load strs+8 as o
	call add strs a an
	call add strs b bn
	call add strs c cn
	call byaddb strs 0 as r
	call must r
	ret o
end

# the paths of the program pi into strs and their addresses into pa
fn paths pi
	call item progs pi as p n
	call bycut strs 0
	call path "build/" p n "" as o
	store pa o
	call path "build/perf/" p n ".c.bin" as o
	store pa+8 o
	call path "build/perf/" p n ".rs.bin" as o
	store pa+16 o
	call path "build/perf/" p n ".s.bin" as o
	store pa+24 o
	call path "bench/" p n ".c" as o
	store pa+32 o
	call path "bench/" p n ".rs" as o
	store pa+40 o
	call path "bench/" p n ".s" as o
	store pa+48 o
	call path "build/perf/" p n ".o" as o
	store pa+56 o
	call path "build/perf/" p n ".input" as o
	store pa+64 o
	call path "build/perf/" p n ".out" as o
	store pa+72 o
	load strs as b
	i=0
	while i<80
		load pa+i as o
		store pa+i b+o
		i+=8
	end
end

# 1 if the file at the address p, a path with a NUL byte, can be read
fn exists p
	call strlen p as n
	call fileopen p n 0 0 as fd
	ifslt fd 0
		ret 0
	end
	sys close fd
	ret 1
end

# run the program whose arguments are in av and wait for it: its status.
# i and o are its input and output, or -1
fn run i o
	call procstart av i o -1 as pid
	ifslt pid 0
		call fail "cannot start a process"
	end
	call procwait pid 0 as st
	ret st
end

# the same, and anything but the status 0 ends the measurement
fn tool
	call run -1 -1 as st
	if st
		load av as p
		call strlen p as n
		call eprint "perf: "
		call fail3 "" p n " failed"
	end
end

# build what bench/ has of the program whose paths are in pa: a bit for
# each language that has an executable
fn build
	load pa as p
	call exists p as r
	ifz r
		call strlen p as n
		call eprint "perf: "
		call fail3 "" p n " is missing, run make first"
	end
	mask=1
	load pa+32 as s
	call exists s as r
	if r
		load pa+8 as b
		store av sgcc
		store av+8 so3
		store av+16 sdasho
		store av+24 b
		store av+32 s
		store av+40 0
		call tool
		mask|=2
	end
	load pa+40 as s
	call exists s as r
	if r
		load pa+16 as b
		store av srustc
		store av+8 so
		store av+16 sdasho
		store av+24 b
		store av+32 s
		store av+40 0
		call tool
		mask|=4
	end
	load pa+48 as s
	call exists s as r
	if r
		load pa+24 as b
		load pa+56 as o
		store av sas
		store av+8 sdasho
		store av+16 o
		store av+24 s
		store av+32 0
		call tool
		store av sld
		store av+16 b
		store av+24 o
		call tool
		mask|=8
	end
	ret mask
end

# ---- inputs and expected results

# the input of the program pi into binp and into its file, and what it
# must write into bwant: 1 if any output will do that C gives
fn prepare pi
	call bycut binp 0
	call bycut bwant 0
	loadb pinput+pi as k
	n=0
	if k==1
		n=4096
	end
	if k==5
		n=1048576
	end
	i=0
	while i<n
		call byaddb binp i&255 as r
		call must r
		i+=1
	end
	if (k>1)&(k<5)
		v=0x123456789abcdef0
		if k==3
			v=16000000
		end
		if k==4
			v=500000
		end
		call byneed binp 8 as r
		call must r
		load binp as p
		store p v
		store binp+8 8
	end
	load binp as p
	load binp+8 as n
	load pa+64 as f
	call strlen f as fn
	call filewrite f fn p n as r
	ifslt r 0
		call fail "cannot write to build/perf"
	end
	loadb pwant+pi as k
	if k==1
		call add bwant "hello world\n"
	end
	if k==2
		call add bwant p n
	end
	if k==3
		call add bwant "4096\n"
	end
	if k==4
		call add bwant "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n"
	end
	ret k==9
end

# a signed number into ob
fn addsigned v
	ifslt v 0
		call add ob "-"
		v=0-v
	end
	call addn ob v
end

# every executable of the program pi must end with the status and write
# the output expected of it, C first, whose output is what the others
# must write where none is given
fn check pi mask free
	call item progs pi as np nn
	loadb pstat+pi as want
	load pa+64 as f
	call strlen f as fn
	load pa+72 as g
	call strlen g as gn
	k=0
	while k<4
		# C, Rust, asm, AIL
		l=k+1&3
		if mask>>l&1
			call fileopen f fn 0 0 as i
			call fileopen g gn 0x241 420 as o
			ifslt i|o 0
				call fail "cannot use build/perf"
			end
			load pa+l*8 as b
			store av b
			store av+8 0
			call run i o as st
			sys close i
			sys close o
			call item langs l as lp ln
			if st!=want
				call eprint "perf: "
				call eprint np nn
				call eprint " "
				call eprint lp ln
				call eprint ": exit status "
				call bycut ob 0
				call addsigned st
				call add ob ", expected "
				call addn ob want
				call add ob "\n"
				load ob as p
				load ob+8 as n
				call eprint p n
				sys exit_group 1
			end
			call bycut bgot 0
			call fileread g gn bgot as r
			load bgot as p
			load bgot+8 as n
			if free
				free=0
				call bycut bwant 0
				call add bwant p n
			end
			load bwant as q
			load bwant+8 as m
			call same p n q m as r
			ifz r
				call eprint "perf: "
				call eprint np nn
				call eprint " "
				call eprint lp ln
				call eprint ": wrong output\n"
				sys exit_group 1
			end
		end
		k+=1
	end
end

# ---- timing

# sort the n numbers at a
fn sort a n
	i=1
	while i<n
		load a+i*8 as v
		j=i
		while j
			load a+j*8-8 as w
			jle w v put
			store a+j*8 w
			j-=1
		end
		label put
		store a+j*8 v
		i+=1
	end
end

# time the executables of the program pi: the rounds before the timed
# ones, then the timed ones, every language once a round in an order
# shuffled anew
fn measure pi mask quick
	call item progs pi as np nn
	loadb pstat+pi as want
	loadb pkind+pi as kind
	warm=25
	rounds=500
	if kind
		warm=2
		rounds=15
	end
	if quick
		warm=5
		rounds=50
		if kind
			warm=1
			rounds=3
		end
	end
	load pa+64 as f
	call strlen f as fn
	call fileopen f fn 0 0 as src
	call fileopen "/dev/null" 1 0 as null
	ifslt src|null 0
		call fail "cannot use build/perf"
	end
	i=0
	while i<warm+rounds
		n=0
		l=0
		while l<4
			if mask>>l&1
				store ord+n*8 l
				n+=1
			end
			l+=1
		end
		call rngshuffle rs ord n
		k=0
		while k<n
			load ord+k*8 as l
			sys lseek src 0 0
			load pa+l*8 as b
			store av b
			store av+8 0
			call procnow as start
			call procstart av src null -1 as pid
			call procwait pid 0 as st
			call procnow as t
			if st!=want
				call item langs l as lp ln
				call eprint "perf: "
				call eprint np nn
				call fail3 " " lp ln ": failed while timed"
			end
			if i>=warm
				store samp+l*4000+(i-warm)*8 t-start
			end
			k+=1
		end
		i+=1
	end
	sys close src
	sys close null
	# the median, the mean of the middle two of an even number, and the
	# numbers a quarter and three quarters of the way
	l=0
	while l<4
		if mask>>l&1
			a=samp+l*4000
			call sort a rounds
			load a+rounds/2*8 as v
			if rounds&1
				itof v as m
			else
				load a+rounds/2*8-8 as w
				itof v+w as m
				itof 2 as w
				fdiv m w as m
			end
			r=res+pi*128+l*32
			store r 1
			store r+8 m
			load a+rounds/4*8 as v
			store r+16 v
			load a+rounds*3/4*8 as v
			store r+24 v
		end
		l+=1
	end
end

# ---- the report

# the first line of what the program p with the argument --version
# writes, into ob
fn version p
	store av p
	store av+8 sversion
	store av+16 0
	call fileopen "build/perf/version.txt" 0x241 420 as o
	ifslt o 0
		call fail "cannot use build/perf"
	end
	call run -1 o as st
	sys close o
	if st
		call strlen p as n
		call eprint "perf: "
		call fail3 "cannot run " p n ""
	end
	call bycut bgot 0
	call fileread "build/perf/version.txt" bgot as r
	call fileunlink "build/perf/version.txt"
	load bgot as q
	load bgot+8 as n
	i=0
	while i<n
		loadb q+i as c
		jeq c 10 eol
		jeq c 13 eol
		i+=1
	end
	label eol
	call add ob q i
end

# the model of the CPU from /proc/cpuinfo into ob
fn cpumodel
	call bycut bgot 0
	call fileread "/proc/cpuinfo" bgot as r
	load bgot as p
	load bgot+8 as n
	e=p+n
	while p<e
		q=p
		while q<e
			loadb q as c
			jeq c 10 eol
			q+=1
		end
		label eol
		if q-p>=10
			call same p 10 "model name" as r
			if r
				# what follows the colon, without the white space around it
				while p<q
					loadb p as c
					p+=1
					jeq c 58 colon
				end
				label colon
				while p<q
					loadb p as c
					jz (c==32)|(c==9) lead
					p+=1
				end
				label lead
				while q>p
					loadb q-1 as c
					jz (c==32)|(c==9)|(c==13) trail
					q-=1
				end
				label trail
				call add ob p q-p
				ret 0
			end
		end
		p=q+1
	end
	call add ob "unknown"
end

# the number v divided by scale, with two digits after the point, into ob
fn cell2 x scale
	itof scale as s
	fdiv x s as x
	call fmtfix ob x 2 as r
	call must r
end

# x^(1/n) for a double x above 0: Newton's steps from above, to the last
# digit or the one before it
fn froot x n
	if n==1
		ret x
	end
	itof 1 as y
	flt y x as r
	if r
		y=x
	end
	itof n as fn
	itof n-1 as fm
	k=0
	while k<200
		p=y
		i=2
		while i<n
			fmul p y as p
			i+=1
		end
		fdiv x p as t
		fmul fm y as u
		fadd u t as u
		fdiv u fn as u
		flt u y as r
		ifz r
			ret y
		end
		y=u
		k+=1
	end
	ret y
end

# the table of the programs of one kind
fn table kind unit un scale
	local ratios 80
	any=0
	k=0
	while k<gnsel
		load sel+k*8 as pi
		loadb pkind+pi as c
		any|=c==kind
		k+=1
	end
	ifz any
		ret 0
	end
	if kind
		call add ob "\nCPU-bound"
	else
		call add ob "\nStartup"
	end
	call add ob ", median elapsed "
	call add ob unit un
	call add ob " (first and third quartile)\n\n| program | AIL | C | Rust | asm |"
	if kind
		call add ob " AIL / C |"
	end
	call add ob "\n|---|---:|---:|---:|---:|"
	if kind
		call add ob "---:|"
	end
	call add ob "\n"
	call say
	nr=0
	k=0
	while k<gnsel
		load sel+k*8 as pi
		loadb pkind+pi as c
		if c==kind
			call item progs pi as p n
			call add ob "| "
			call add ob p n
			call add ob " | "
			l=0
			while l<4
				if l
					call add ob " | "
				end
				r=res+pi*128+l*32
				load r as c
				if c
					load r+8 as m
					load r+16 as lo
					load r+24 as hi
					call cell2 m scale
					call add ob " ("
					itof lo as lo
					call cell2 lo scale
					call add ob ", "
					itof hi as hi
					call cell2 hi scale
					call add ob ")"
				end
				l+=1
			end
			call add ob " |"
			if kind
				r=res+pi*128
				load r+32 as c
				if c
					load r+8 as m
					load r+40 as d
					fdiv m d as q
					store ratios+nr*8 q
					nr+=1
					call add ob " "
					call fmtfix ob q 3 as c
					call must c
					# marked when more than a tenth slower than C
					itof 11 as m
					itof 10 as d
					fdiv m d as m
					flt m q as c
					if c
						call add ob " slow"
					end
				end
				call add ob " |"
			end
			call add ob "\n"
			call say
		end
		k+=1
	end
	if nr
		itof 1 as g
		k=0
		while k<nr
			load ratios+k*8 as q
			fmul g q as g
			k+=1
		end
		call froot g nr as g
		call add ob "\nGeometric mean of AIL / C over "
		call addn ob nr
		call add ob " CPU-bound program"
		if nr!=1
			call add ob "s"
		end
		call add ob ": "
		call fmtfix ob g 3 as c
		call must c
		call add ob "\n"
		call say
	end
end

fn main
	call argc as n
	quick=0
	cpu=2
	gnsel=0
	i=1
	while i<n
		call argv i as p m
		i+=1
		call same p m "--quick" as r
		if r
			quick=1
		else
			call same p m "--cpu" as r
			if r
				call argv i as p m
				i+=1
				call num p m as cpu r
				ifz r
					call fail "usage: perf [--cpu N] [--quick] [name ...]"
				end
			else
				# the program of that name, once
				k=0
				while k<nprogs
					call item progs k as q qn
					call same p m q qn as r
					jnz r known
					k+=1
				end
				call eprint "perf: "
				call fail3 "unknown program " p m ""
				label known
				j=0
				while j<gnsel
					load sel+j*8 as r
					jeq r k dup
					j+=1
				end
				store sel+gnsel*8 k
				gnsel+=1
				label dup
			end
		end
	end
	ifz gnsel
		while gnsel<nprogs
			store sel+gnsel*8 gnsel
			gnsel+=1
		end
	end
	call filemkdir "build" 493
	call filemkdir "build/perf" 493
	call procpin cpu as cpu
	ifslt cpu 0
		call fail "cannot bind the process to a CPU"
	end
	call add ob "CPU: "
	call cpumodel
	call add ob ", pinned to CPU "
	call addn ob cpu
	call add ob "\nC: `gcc -O3`, "
	call version sgcc
	call add ob "\nRust: `rustc -O`, "
	call version srustc
	call add ob "\nasm: GNU as and ld; AIL: build/ailc\n"
	call say
	call rngseed rs 77
	k=0
	while k<gnsel
		load sel+k*8 as pi
		call paths pi
		call build as mask
		call prepare pi as free
		call check pi mask free
		call measure pi mask quick
		k+=1
	end
	call table 0 "in microseconds" 1000
	call table 1 "in milliseconds" 1000000
end

call main

# tools/randvars.aw -- check generated code with random programs whose
# result is computed here.
#
#   build/tools/randvars <compiler> <count> <seed> [top|async|asyncs]
#   build/tools/randvars dump <directory> <count> <seed> [top|async|asyncs]
#
# Each program is arithmetic on up to 40 variables with nested loops and
# blocks, in a function or (with "top") at top level, or (with "async")
# in an async function, a task of lib/async/task.aw that gives the thread
# back before every third statement and so goes on in the middle of its
# loops and blocks with its variables in its record; with "asyncs" the
# wait is before every twelfth statement, so that there are variables no
# wait falls between, which have registers. It is written three
# times from one tree: with statements ("add a b as x", labels and jumps);
# line for line the same with each statement spelled as an expression
# ("x=a+b", "jz a<b l"); and with nested expressions, "x+=e", "while" and
# "if" on a comparison. The same tree is run here, with 64-bit wrapping,
# by a function that shares nothing with the three that write, to get the
# exit status that all must give. The first two must also compile to the
# same file, byte for byte: a statement and the expression that says the
# same are one thing to the compiler. A program that fails is kept as
# build/randvars/seed<seed>[-top]-<n>-<form>.aw. make test runs it with a
# fixed seed in both modes.
#
# One line on stdout for each failure, or one "ok" line; status 1 after a
# failure, else 0. A program gets 10 seconds to run. The compiler and the
# programs are run in a directory of their own under TMPDIR, or /tmp.
#
# With "dump" nothing is compiled: program n is written to
# <directory>/<n>.txt, its three forms with a line "--" after each, then
# its status and the number of variables it needs.
#
# The random numbers are those of tools/lib/rng.aw, splitmix64, so a seed
# gives the same programs on every machine. "One in a hundred" below is a
# number below 100 from there. This tool computes the expected status
# with code that the compiler under test compiled; tests/randvars.sh runs
# programs whose status the Python script computed that this was ported
# from.
use "lib/std/io.aw"
use "lib/std/bytes.aw"
use "lib/std/file.aw"
use "lib/std/proc.aw"
use "tools/lib/rng.aw"

# the number of names v0, v1, ... of the program and of its counters c0,
# c1, ...; the buffer that the writing functions add to, whether they
# spell statements as expressions, and the number of the last label
var gnn gncnt gob gflat gnlab
# gasy = 1 for programs in an async function; gny counts the statements
# written, of which every gper-th is behind a wait
var gasy gny gper

# the state of the random numbers
buf rs 8
# the tree, in cells of 40 bytes; cell 0 is not used, so that 0 is the
# empty list. A value is a number with its kind in the low three bits:
# 0 a variable (0 to 39 the names v, 40 to 45 the parameters p), 1 a
# constant (its place in the list below), 2 an operation (a cell: the
# operator, 0 to 15 as in the list of names, and two values), 3 a
# temporary t, 4 a counter c. A statement is a cell: its kind, three
# fields and the next statement of its block.
#   1 set:  the variable, the value
#   2 loop: the number of rounds, the number of the counter, the body
#   3 if:   the value, the block, the block after else or -1
buf cells 24
# the values of the variables when the tree is run
buf env 368
# the three sources
buf bold 24
buf bflat 24
buf bnew 24
# what the compiler wrote for the first form and for the one at work,
# and what it said
buf xold 24
buf xcur 24
buf xerr 24
# a line for stdout, the paths of the files in the directory of the run
# (each with a NUL byte after it), and the arguments of a child
buf msg 24
buf tailb 24
buf tdir 24
buf psrc 24
buf pexe 24
buf perr 24
buf kept 24
buf kept2 24
buf av 16

data names 3 "mul" 3 "div" 3 "mod" 3 "add" 3 "sub" 3 "shl" 3 "shr" 3 "and" 3 "xor" 2 "or"
data 2 "eq" 2 "ne" 2 "lt" 2 "le" 2 "gt" 2 "ge"
data syms 1 "*" 1 "/" 1 "%" 1 "+" 1 "-" 2 "<<" 2 ">>" 1 "&" 1 "^" 1 "|"
data 2 "==" 2 "!=" 1 "<" 2 "<=" 1 ">" 2 ">="
# how tightly each binds, the comparison with the opposite result, and
# the operators that are no comparison in the order they are drawn in
data prec 6 6 6 5 5 4 4 3 2 1 0 0 0 0 0 0
data inv 11 10 15 14 13 12
data arith 0 3 4 5 6 7 8 9 1 2
# the constants from the tenth on; the first ten are the digits
data consts 3 "255" 4 "4096" 2 "-1" 11 "0x100000000" 18 "0xffffffffffffffff" 2 "63" 2 "64"
data digits "0123456789"
# the variables in the order of their names as strings: p0 to p5, then
# v0, v1, v10, ..., v19, v2, v20, ...
data order 40 41 42 43 44 45 0 1 10 11 12 13 14 15 16 17 18 19 2 20 21 22 23 24 25 26 27 28 29
data 3 30 31 32 33 34 35 36 37 38 39 4 5 6 7 8 9
data forms 10 "statements" 4 "flat" 11 "expressions"

fn oom
	call die "randvars: out of memory\n"
end

# 0 is no memory
fn must r
	ifz r
		call oom
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

fn additem b p i
	call item p i as q n
	call add b q n
end

# a new cell with the four fields and no next: its number
fn cell a b c d
	call byneed cells 40 as r
	call must r
	load cells as p
	load cells+8 as n
	store p+n a
	store p+n+8 b
	store p+n+16 c
	store p+n+24 d
	store p+n+32 0
	store cells+8 n+40
	ret n/40
end

# the address of the cell i, good until the next new cell
fn cp i
	load cells as p
	ret p+i*40
end

# the text of the value r, which is no operation, into the buffer b
fn pname b r
	t=r&7
	k=r>>3
	ifz t
		if k<40
			call add b "v"
			call addn b k
		else
			call add b "p"
			call addn b k-40
		end
		ret 0
	end
	if t==1
		if k<10
			call add b digits+k 1
		else
			call additem b consts k-10
		end
		ret 0
	end
	if t==3
		call add b "t"
	else
		call add b "c"
	end
	call addn b k
end

# the number the constant k stands for
fn cval k
	if k<10
		ret k
	end
	if k==10
		ret 255
	end
	if k==11
		ret 4096
	end
	if k==13
		ret 0x100000000
	end
	if k==15
		ret 63
	end
	if k==16
		ret 64
	end
	ret -1
end

# ---- the random tree

# the number of variables in the set mask, and the one at the place i
# when they stand in the order of their names
fn bits mask
	n=0
	while mask
		n+=mask&1
		mask>>=1
	end
	ret n
end
fn nth mask i
	j=0
	while j<46
		loadb order+j as id
		if mask>>id&1
			ifz i
				ret id
			end
			i-=1
		end
		j+=1
	end
end

# a variable that is assigned, four times in five if there is one; else a
# digit six times in thirteen, or one of the seven other constants
fn leaf mask
	if mask
		call rngbelow rs 100 as x
		if x<80
			call bits mask as k
			call rngbelow rs k as i
			call nth mask i as id
			ret id*8
		end
	end
	call rngbelow rs 10 as d
	call rngbelow rs 13 as i
	if i<6
		ret d*8+1
	end
	ret (i+4)*8+1
end

# a value: a leaf, or an operation on two values, at most three deep
fn expr mask depth
	if depth<3
		call rngbelow rs 100 as x
		jlt x 45 lf
		call rngbelow rs 100 as x
		if x<85
			call rngbelow rs 10 as i
			loadb arith+i as o
		else
			call rngbelow rs 6 as i
			o=10+i
		end
		call expr mask depth+1 as a
		call expr mask depth+1 as b
		# a divisor is never zero: or 1
		if o-1<2
			call cell 9 b 9 0 as b
			b=b*8+2
		end
		call cell o a b 0 as c
		ret c*8+2
	end
	label lf
	call leaf mask as r
	ret r
end

# a block of n statements, where the variables of mask are assigned: its
# first statement, and the variables assigned after it
fn block mask depth n
	head=0
	tail=0
	while n
		n-=1
		call rngbelow rs 100 as x
		if (x<72)|(depth>=3)
			call rngbelow rs gnn as dst
			call expr mask 0 as e
			if mask>>dst&1
				call rngbelow rs 100 as x
				if (x<30)&((e&7)==2)
					# the shape of x op= e
					call cp e>>3 as p
					load p as o
					load p+16 as b
					call cell o dst*8 b 0 as e
					e=e*8+2
				end
			end
			call cell 1 dst*8 e 0 as st
			mask|=1<<dst
		else
			if x<88
				k=gncnt
				gncnt+=1
				# what a round assigns anew is its own: a loop may run no round
				call rngbelow rs 6 as m
				call block mask depth+1 m+1 as body mm
				call rngbelow rs 3 as m
				call cell 2 m+1 k body as st
			else
				jz mask skip
				call rngbelow rs 100 as x
				if x<70
					call rngbelow rs 6 as o
					call leaf mask as a
					call leaf mask as b
					call cell o+10 a b 0 as c
					c=c*8+2
				else
					call expr mask 1 as c
				end
				call rngbelow rs 4 as m
				call block mask depth+1 m+1 as a mm
				b=-1
				call rngbelow rs 100 as x
				if x<40
					call rngbelow rs 3 as m
					call block mask depth+1 m+1 as b mm
				end
				call cell 3 c a b as st
			end
		end
		if tail
			call cp tail as p
			store p+32 st
		else
			head=st
		end
		tail=st
		label skip
	end
	ret head mask
end

# ---- running the tree

fn ev e
	t=e&7
	k=e>>3
	ifz t
		load env+k*8 as v
		ret v
	end
	if t==1
		call cval k as v
		ret v
	end
	call cp k as p
	load p as o
	load p+8 as a
	load p+16 as b
	call ev a as x
	call ev b as y
	if o<5
		if o==0
			ret x*y
		end
		if o==1
			ret x/y
		end
		if o==2
			ret x%y
		end
		if o==3
			ret x+y
		end
		ret x-y
	end
	if o<10
		if o==5
			ret x<<(y&63)
		end
		if o==6
			ret x>>(y&63)
		end
		if o==7
			ret x&y
		end
		if o==8
			ret x^y
		end
		ret x|y
	end
	if o==10
		ret x==y
	end
	if o==11
		ret x!=y
	end
	if o==12
		ret x<y
	end
	if o==13
		ret x<=y
	end
	if o==14
		ret x>y
	end
	ret x>=y
end

fn run st
	while st
		call cp st as p
		load p as k
		load p+8 as a
		load p+16 as b
		load p+24 as c
		load p+32 as st
		if k==1
			call ev b as v
			store env+(a>>3)*8 v
		end
		if k==2
			while a
				call run c
				a-=1
			end
		end
		if k==3
			call ev a as v
			if v
				call run b
			else
				if c!=-1
					call run c
				end
			end
		end
	end
end

# ---- the statement form, and with gflat the same lines as expressions

fn o p n
	call add gob p n
end

# the line that computes a and b with the operator op into dst
fn eop op a b dst
	if gflat
		call pname gob dst
		if (dst==a)&(op<10)
			call additem gob syms op
			call o "="
		else
			call o "="
			call pname gob a
			call additem gob syms op
		end
		call pname gob b
	else
		call additem gob names op
		call o " "
		call pname gob a
		call o " "
		call pname gob b
		call o " as "
		call pname gob dst
	end
	call o "\n"
end

# compute the value e with the temporaries from t<k> on: the name or
# number that holds it
fn value e k
	if (e&7)!=2
		ret e
	end
	call cp e>>3 as p
	load p as op
	load p+8 as a
	load p+16 as b
	call value a k as x
	call value b k+1 as y
	call eop op x y k*8+3
	ret k*8+3
end

fn olabel w wn l
	call o w wn
	call o "l"
	call addn gob l
	call o "\n"
end

# in an async function, a wait before every third statement
fn oyield
	if gasy
		gny+=1
		ifz gny%gper
			call o "await asyncyield\n"
		end
	end
end

fn oblock st
	while st
		call oyield
		call cp st as p
		load p as k
		load p+8 as a
		load p+16 as b
		load p+24 as c
		load p+32 as st
		if k==1
			if (b&7)!=2
				if gflat
					call pname gob a
					call o "="
					call pname gob b
				else
					call o "set "
					call pname gob b
					call o " as "
					call pname gob a
				end
				call o "\n"
			else
				call cp b>>3 as p
				load p as op
				load p+8 as x
				load p+16 as y
				call value x 0 as x
				call value y 1 as y
				call eop op x y a
			end
		end
		if k==2
			gnlab+=1
			l=gnlab
			if gflat
				call pname gob b*8+4
				call o "="
				call addn gob a
			else
				call o "set "
				call addn gob a
				call o " as "
				call pname gob b*8+4
			end
			call o "\n"
			call olabel "label " l
			call oblock c
			call eop 4 b*8+4 9 b*8+4
			call o "jnz "
			call pname gob b*8+4
			call olabel " " l
		end
		if k==3
			gnlab+=1
			l=gnlab
			x=0
			y=0
			op=0
			if (a&7)==2
				call cp a>>3 as p
				load p as op
				load p+8 as x
				load p+16 as y
			end
			# a comparison of two plain values, not both numbers (the compiler
			# computes an expression of numbers, and leaves a statement that compares
			# them to run): one statement, or the jump on the expression that says
			# the same
			if ((a&7)==2)&(op>=10)&((x&7)<2)&((y&7)<2)&(((x&7)==0)|((y&7)==0))
				if gflat
					call o "jz "
					call pname gob x
					call additem gob syms op
					call pname gob y
				else
					call o "j"
					loadb inv+op-10 as op
					call additem gob names op
					call o " "
					call pname gob x
					call o " "
					call pname gob y
				end
			else
				call value a 0 as x
				call o "jz "
				call pname gob x
			end
			call olabel " " l
			call oblock b
			if c!=-1
				gnlab+=1
				m=gnlab
				call olabel "jmp " m
				call olabel "label " l
				call oblock c
				call olabel "label " m
			else
				call olabel "label " l
			end
		end
	end
end

# ---- the expression form

# put the byte c at the offset i of the buffer b, moving what follows
fn insert b i c
	call byaddb b 0 as r
	call must r
	load b as p
	load b+8 as n
	n-=1
	while n>i
		loadb p+n-1 as d
		storeb p+n d
		n-=1
	end
	storeb p+i c
end

# the value e as text, as an operand of an operator of the strength s-1
# (0: of none), the right one if right is 1: in parentheses where they
# are needed, a looser operator inside or one of the same strength on the
# right, and fifteen times in a hundred where they are not
fn ntext e s right
	if (e&7)!=2
		call pname gob e
		ret 0
	end
	call cp e>>3 as p
	load p as op
	load p+8 as a
	load p+16 as b
	loadb prec+op as q
	q+=1
	load gob+8 as start
	call ntext a q 0
	call additem gob syms op
	call ntext b q 1
	par=(q<s)|((q==s)&right)
	ifz par
		call rngbelow rs 100 as x
		par=x<15
	end
	if par
		call insert gob start 40
		call o ")"
	end
end

fn nblock st
	while st
		call oyield
		call cp st as p
		load p as k
		load p+8 as a
		load p+16 as b
		load p+24 as c
		load p+32 as st
		if k==1
			call pname gob a
			x=0
			y=0
			op=0
			if (b&7)==2
				call cp b>>3 as p
				load p as op
				load p+8 as x
				load p+16 as y
				if (x==a)&(op<10)
					call rngbelow rs 100 as x
					x=x<70
				else
					x=0
				end
			end
			if x
				call additem gob syms op
				call o "="
				call ntext y 0 0
			else
				call o "="
				call ntext b 0 0
			end
			call o "\n"
		end
		if k==2
			call pname gob b*8+4
			call o "="
			call addn gob a
			call o "\nwhile "
			call pname gob b*8+4
			call o "\n"
			call nblock c
			call pname gob b*8+4
			call o "-=1\nend\n"
		end
		if k==3
			call o "if "
			call ntext a 0 0
			call o "\n"
			call nblock b
			if c!=-1
				call o "else\n"
				call nblock c
			end
			call o "end\n"
		end
	end
end

# ---- one program

# the names of the assigned variables into the buffer b, each after the
# n bytes at p and before the m bytes at q
fn finals b mask p n q m
	j=0
	while j<46
		loadb order+j as id
		if mask>>id&1
			call add b p n
			call pname b id*8
			call add b q m
		end
		j+=1
	end
end

# the three sources of one random program into bold, bflat and bnew: its
# exit status, and how many variables its larger form uses
fn program top
	local args 48
	call bycut cells 0
	call cell 0 0 0 0
	call bycut bold 0
	call bycut bflat 0
	call bycut bnew 0
	call rngbelow rs 38 as gnn
	gnn+=3
	gncnt=0
	np=0
	ifz top
		call rngbelow rs 7 as np
	end
	mask=0
	i=0
	while i<np
		mask|=1<<(40+i)
		i+=1
	end
	call rngbelow rs 36 as n
	call block mask 0 n+5 as body mask
	i=0
	while i<46
		store env+i*8 0
		i+=1
	end
	i=0
	while i<np
		call rngbelow rs 1001 as v
		store args+i*8 v
		store env+320+i*8 v
		i+=1
	end
	call run body
	h=0
	i=0
	while i<46
		if mask>>i&1
			load env+i*8 as v
			h+=v
		end
		i+=1
	end
	# the head of a function, the same in all three
	ifz top
		if gasy
			call add bold "use \"lib/async/task.aw\"\nasync "
		end
		call add bold "fn f "
		i=0
		while i<np
			if i
				call add bold " "
			end
			call add bold "p"
			call addn bold i
			i+=1
		end
		call add bold "\n"
		load bold as p
		load bold+8 as n
		call add bflat p n
		call add bnew p n
	end
	gob=bold
	gflat=0
	gnlab=0
	gny=0
	call oblock body
	gob=bflat
	gflat=1
	gnlab=0
	gny=0
	call oblock body
	gob=bnew
	gny=0
	call nblock body
	call add bold "set 0 as h\n"
	call finals bold mask "add h " " as h\n"
	call add bold "mod h 251 as h\n"
	call add bflat "h=0\n"
	call finals bflat mask "h+=" "\n"
	call add bflat "h%=251\n"
	if mask
		# the names with a + before each, of which the first becomes the
		# parenthesis
		call add bnew "h="
		load bnew+8 as start
		call finals bnew mask "+" ""
		load bnew as p
		storeb p+start 40
		call add bnew ")%251\n"
	else
		call add bnew "h=0\n"
	end
	# the same tail for all three
	call bycut tailb 0
	if top
		call add tailb "sys 60 h\n"
	else
		call add tailb "ret h\nend\n"
		if gasy
			call add tailb "await f "
		else
			call add tailb "call f "
		end
		i=0
		while i<np
			if i
				call add tailb " "
			end
			load args+i*8 as v
			call addn tailb v
			i+=1
		end
		call add tailb " as r\nsys 60 r\n"
	end
	load tailb as p
	load tailb+8 as n
	call add bold p n
	call add bflat p n
	call add bnew p n
	ret h%251 gnn+np+gncnt+5
end

# ---- compiling and running

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

fn usage
	call die "usage: randvars <compiler> <count> <seed> [top|async|asyncs]\n       randvars dump <directory> <count> <seed> [top|async|asyncs]\n"
end

fn failtmp
	call eprint "randvars: cannot use "
	load tdir as p
	load tdir+8 as n
	call eprint p n
	call eprint "\n"
	sys exit_group 1
end

# the path of the file name in the directory of the run into b, with a
# NUL byte after it
fn tpath b name nn
	load tdir as p
	load tdir+8 as n
	call add b p n
	call add b "/"
	call add b name nn
	call byaddb b 0 as r
	call must r
end

# give the n bytes at p to the compiler cc as its input, its output into
# the file of the program and into the buffer out, what it says into
# xerr: its status
fn compile cc p n out
	load psrc as sp
	load psrc+8 as sn
	load pexe as ep
	load pexe+8 as en
	load perr as rp
	load perr+8 as rn
	call filewrite sp sn-1 p n as r
	ifslt r 0
		call failtmp
	end
	call fileopen sp sn-1 0 0 as i
	call fileopen ep en-1 0x241 493 as o
	call fileopen rp rn-1 0x241 420 as e
	ifslt i|o|e 0
		call failtmp
	end
	store av cc
	store av+8 0
	call procstart av i o e as pid
	sys close i
	sys close o
	sys close e
	ifslt pid 0
		call die "randvars: cannot start a process\n"
	end
	call procwait pid 0 as st
	call bycut out 0
	call bycut xerr 0
	call fileread ep en-1 out as r
	ifslt r 0
		call failtmp
	end
	call fileread rp rn-1 xerr as r
	ret st
end

# 1 if the n bytes at p and at q are the same
fn samebytes p q n
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

# keep the n bytes at p as the source of the program i in the form f:
# its path is added to the buffer b
fn keep b seed top i f p n
	call filemkdir "build" 493
	call filemkdir "build/randvars" 493
	load b+8 as start
	call add b "build/randvars/seed"
	call addn b seed
	if top
		call add b "-top"
	end
	if gasy
		call add b "-async"
		if gper!=3
			call add b "s"
		end
	end
	call add b "-"
	call addn b i
	call add b "-"
	call additem b forms f
	call add b ".aw"
	load b as q
	load b+8 as m
	call filewrite q+start m-start p n as r
	ifslt r 0
		call die "randvars: cannot write to build/randvars\n"
	end
end

# a number with its sign into the buffer b
fn addsigned b v
	ifslt v 0
		call add b "-"
		v=0-v
	end
	call addn b v
end

fn say
	load msg as p
	load msg+8 as n
	call print p n
	call bycut msg 0
end

fn main
	call argc as n
	if n<4
		call usage
	end
	call argv 1 as cc ccn
	dump=0
	if ccn==4
		load4 cc as v
		dump=v==0x706d7564
	end
	if n<4+dump
		call usage
	end
	call argv 2+dump as ap an
	call num ap an as count ok
	call argv 3+dump as ap an
	call num ap an as seed ok2
	if (ok==0)|(ok2==0)
		call usage
	end
	top=0
	if n>4+dump
		top=1
		call argv 4+dump as ap an
		if an==5
			load4 ap as v
			loadb ap+4 as c
			if (v==0x6e797361)&(c==99)
				top=0
				gasy=1
				gper=3
			end
		end
		if an==6
			load4 ap as v
			load2 ap+4 as c
			if (v==0x6e797361)&(c==0x7363)
				top=0
				gasy=1
				gper=12
			end
		end
	end
	call rngseed rs seed
	if dump
		call argv 2 as dp dn
		i=0
		while i<count
			call program top as want nv
			call bycut kept 0
			call add kept dp dn
			call add kept "/"
			call addn kept i
			call add kept ".txt"
			call bycut xcur 0
			load bold as p
			load bold+8 as m
			call add xcur p m
			call add xcur "--\n"
			load bflat as p
			load bflat+8 as m
			call add xcur p m
			call add xcur "--\n"
			load bnew as p
			load bnew+8 as m
			call add xcur p m
			call add xcur "--\n"
			call addn xcur want
			call add xcur " "
			call addn xcur nv
			call add xcur "\n"
			load kept as p
			load kept+8 as m
			load xcur as q
			load xcur+8 as qn
			call filewrite p m q qn as r
			ifslt r 0
				call die "randvars: cannot write to the directory\n"
			end
			i+=1
		end
		ret 0
	end
	# a directory of this run for the source, the program and what the
	# compiler says
	call procvar "TMPDIR" as p m
	ifz m
		call add tdir "/tmp"
	else
		call add tdir p m
	end
	call add tdir "/randvars-"
	sys getpid as pid
	call addn tdir pid
	load tdir as p
	load tdir+8 as m
	call filemkdir p m 448 as r
	ifslt r 0
		call failtmp
	end
	call tpath psrc "src.aw"
	call tpath pexe "prog"
	call tpath perr "err"
	bad=0
	done=0
	i=0
	while i<count
		call program top as want nv
		# too many variables for a scope
		jgt nv 60 next
		done+=1
		f=0
		while f<3
			src=bold
			out=xold
			if f
				out=xcur
				src=bflat
				if f==2
					src=bnew
				end
			end
			load src as p
			load src+8 as m
			call compile cc p m out as st
			if (f==1)&(st==0)
				load xold as q
				load xold+8 as qn
				load xcur as r
				load xcur+8 as rn
				same=0
				if qn==rn
					call samebytes q r qn as same
				end
				ifz same
					call bycut kept 0
					call bycut kept2 0
					load bold as q
					load bold+8 as qn
					call keep kept seed top i 0 q qn
					call keep kept2 seed top i 1 p m
					call add msg "FAIL randvars "
					call addn msg i
					call add msg ": statements and their expressions give other bytes (kept as "
					load kept as q
					load kept+8 as qn
					call add msg q qn
					call add msg ", "
					load kept2 as q
					load kept2+8 as qn
					call add msg q qn
					call add msg ")\n"
					call say
					bad+=1
				end
			end
			if st
				call bycut kept 0
				call keep kept seed top i f p m
				call add msg "FAIL randvars "
				call addn msg i
				call add msg " as "
				call additem msg forms f
				call add msg ": does not compile: "
				# what the compiler said, without the white space around it
				load xerr as q
				load xerr+8 as qn
				while qn
					loadb q+qn-1 as c
					jz (c-9<5)|(c-28<5) cut
					qn-=1
				end
				label cut
				while qn
					loadb q as c
					jz (c-9<5)|(c-28<5) cut2
					q+=1
					qn-=1
				end
				label cut2
				call add msg q qn
				call add msg " (kept as "
				load kept as q
				load kept+8 as qn
				call add msg q qn
				call add msg ")\n"
				call say
				bad+=1
			else
				load pexe as q
				store av q
				store av+8 0
				call procstart av -1 -1 -1 as pid
				ifslt pid 0
					call die "randvars: cannot start a process\n"
				end
				call procwait pid 10000 as got
				if got!=want
					call bycut kept 0
					call keep kept seed top i f p m
					call add msg "FAIL randvars "
					call addn msg i
					call add msg " as "
					call additem msg forms f
					call add msg ": status "
					if got==-1000
						call add msg "deadline"
					else
						call addsigned msg got
					end
					call add msg ", expected "
					call addn msg want
					call add msg " (kept as "
					load kept as q
					load kept+8 as qn
					call add msg q qn
					call add msg ")\n"
					call say
					bad+=1
				end
			end
			f+=1
		end
		label next
		i+=1
	end
	ifz bad
		call add msg "ok   randvars "
		call addn msg count
		call add msg " programs, seed "
		call addn msg seed
		if top
			call add msg ", top level"
		end
		if gasy
			call add msg ", async"
			if gper!=3
				call add msg " with few waits"
			end
		end
		call add msg " ("
		call addn msg done
		call add msg " run, as statements, the same bytes line by line as expressions, and nested)\n"
		call say
	end
	load psrc as p
	load psrc+8 as m
	call fileunlink p m-1
	load pexe as p
	load pexe+8 as m
	call fileunlink p m-1
	load perr as p
	load perr+8 as m
	call fileunlink p m-1
	load tdir as p
	load tdir+8 as m
	call filermdir p m
	ret bad!=0
end

call main as x
sys exit x

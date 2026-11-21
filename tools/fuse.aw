# tools/fuse.aw -- rewrite an AIL source to use compare-and-jump statements
# and if blocks.
#
#   build/tools/fuse in.aw out.aw
#
# A comparison followed by jz or jnz on its result becomes one jump when
# the result is not read afterwards on any way. A conditional jump forward
# to a label that nothing else jumps to becomes a block, where blocks
# nest. On stderr: "fused N blocks M". Status 0, or 1 with a message when
# a file cannot be read or written or a label or jump has no name.
#
# The source is bytes and lines end with LF. A line with a CR before the
# LF matches no pattern and stays as it is, CR included; so does a line
# with a comment or a string where a jump would become a block.
use "lib/io.aw"
use "lib/bytes.aw"
use "lib/file.aw"
use "tools/lib/scan.aw"
use "tools/lib/flow.aw"

# the lines (gltab, gnl of them) are 40 bytes each: the address and the
# length of the text, the index of the first word in gwtab and the number
# of words, and 1 if the line is deleted. A word is its number in the
# table of tools/lib/scan.aw; gnw of them are in gwtab.
var gltab gnl gwtab gnw
# the scope at work: its line numbers (gsc, gm of them), and for each word
# number below gnid the position of the label of that name (gpos: mark and
# position) and the jumps to it (gref: mark and count), valid when the
# mark is gstamp; gflag has a byte for each word, 1 for the name of a var
var gsc gm gpos gref gflag gnid gstamp

buf text 24
buf scr 24
buf out 24

# the words with a meaning, in the order of their numbers
const klabel 1
const kfn 2
const kend 3
const kelse 10
const kas 11
const kjmp 12
const kjz 13
const kjnz 14
const kcall 15
const ktail 16
const kref 17
const kret 18
const kcmp 19
const kjcc 29
const kifcc 39
const kif 49
const kifz 50
const kkeep 51
const klast 72
data words 5 "label" 2 "fn" 3 "end" 3 "buf" 4 "data" 3 "var" 5 "const" 3 "use" 5 "local" 4 "else"
data 2 "as" 3 "jmp" 2 "jz" 3 "jnz" 4 "call" 4 "tail" 3 "ref" 3 "ret"
data 2 "eq" 2 "ne" 2 "lt" 2 "le" 2 "gt" 2 "ge" 3 "slt" 3 "sle" 3 "sgt" 3 "sge"
data 3 "jeq" 3 "jne" 3 "jlt" 3 "jle" 3 "jgt" 3 "jge" 4 "jslt" 4 "jsle" 4 "jsgt" 4 "jsge"
data 4 "ifeq" 4 "ifne" 4 "iflt" 4 "ifle" 4 "ifgt" 4 "ifge" 5 "ifslt" 5 "ifsle" 5 "ifsgt" 5 "ifsge"
data 2 "if" 3 "ifz"
# labels that stay labels: the states of the compiler this tool was
# written for
data 4 "next" 6 "tokend" 3 "arg" 3 "num" 3 "str" 5 "ident" 7 "capture" 6 "bufdef" 6 "vardef"
data 8 "constdef" 8 "localdef" 6 "usedef" 4 "uend" 7 "datadef" 6 "labdef" 7 "jtarget"
data 5 "fndef" 5 "fnend" 6 "blkend" 7 "elsedef" 6 "atname" 3 "fin"
data 0
# the comparison with the opposite result, by its place among the ten
data inv 1 0 5 4 3 2 9 8 7 6
data quoted 34 "s" 34
data endtext "end"

fn oom
	call die "fuse: out of memory\n"
end

# 0 is no memory
fn must r
	ifz r
		call oom
	end
end

fn failpath m ml p pl
	call eprint "fuse: "
	call eprint m ml
	call eprint p pl
	call eprint "\n"
	sys exit_group 1
end

# the word in scr, if any, is the next word of the line
fn flush
	load scr as p
	load scr+8 as n
	if n
		call scintern p n as k
		call must k
		store gwtab+gnw*8 k
		gnw+=1
		call bycut scr 0
	end
end

# the words of the line l, taken anew from its text: every string is the
# word "s" or a part of one, a # outside a string ends the line
fn retok l
	load l as p
	load l+8 as n
	e=p+n
	store l+16 gnw
	call bycut scr 0
	while p<e
		loadb p as c
		q=0
		if c==34
			call scstr p e as q
		end
		if q
			call byadd scr quoted 3 as k
			call must k
			p=q
		else
			jeq c 35 done
			call scspace c as s
			if s
				call flush
			else
				call byaddb scr c as k
				call must k
			end
			p+=1
		end
	end
	label done
	call flush
	load l+16 as s
	store l+24 gnw-s
end

# the index of the word "as" of the line with c words at w, or c: the
# values of a statement are the words from 1 to there
fn opsend w c
	i=1
	while i<c
		load w+i*8 as k
		if k==kas
			ret i
		end
		i+=1
	end
	ret c
end

# what the line l is, and the name it defines or jumps to: 0 nothing,
# 1 a label, 2 a definition or else, 3 end, 4 jmp, 5 a conditional jump,
# 6 ret or tail, 7 any other statement
fn linfo l
	load l+24 as c
	ifz c
		ret 0 0
	end
	load l+16 as w
	w=gwtab+w*8
	load w as k
	if k==klabel
		jlt c 2 bad
		load w+8 as t
		ret 1 t
	end
	if k==kend
		ret 3 0
	end
	if k-kfn<9
		ret 2 0
	end
	call opsend w c as m
	if (k==kjmp)|(k==kjz)|(k==kjnz)|(k-kjcc<10)
		jeq m 1 bad
		load w+m*8-8 as t
		ret 4+(k!=kjmp) t
	end
	if (k==kret)|(k==ktail)
		ret 6 0
	end
	ret 7 0
	label bad
	call die "fuse: a label or a jump without a name\n"
end

# 1 if the line l reads the variable v: it is one of its values and a name
fn lreads l v
	load l+24 as c
	ifz c
		ret 0
	end
	load l+16 as w
	w=gwtab+w*8
	load w as k
	if (k-klabel<10)|(k==kjmp)
		ret 0
	end
	call opsend w c as e
	i=1
	if (k==kjz)|(k==kjnz)|(k-kjcc<10)
		e-=1
	end
	if (k==kcall)|(k==ktail)|(k==kref)
		i=2
	end
	while i<e
		load w+i*8 as k
		if k==v
			call scatom v as p n
			call scname p n as r
			ret r
		end
		i+=1
	end
end

# 1 if the line l writes the variable v: it stands after as
fn lwrites l v
	load l+24 as c
	ifz c
		ret 0
	end
	load l+16 as w
	w=gwtab+w*8
	load w as k
	if k-klabel<10
		ret 0
	end
	call opsend w c as i
	i+=1
	while i<c
		load w+i*8 as k
		if k==v
			ret 1
		end
		i+=1
	end
end

# the position of the label t in the scope at work, or -1
fn getpos t
	if t<gnid
		p=gpos+t*16
		load p as s
		if s==gstamp
			load p+8 as n
			ret n
		end
	end
	ret -1
end
fn setpos t n
	if t<gnid
		p=gpos+t*16
		store p gstamp
		store p+8 n
	end
end
# the number of jumps to t in the scope at work
fn getref t
	if t<gnid
		p=gref+t*16
		load p as s
		if s==gstamp
			load p+8 as n
			ret n
		end
	end
end
fn addref t
	if t<gnid
		call getref t as n
		p=gref+t*16
		store p gstamp
		store p+8 n+1
	end
end

# the line at the position n of the scope at work
fn line n
	load gsc+n*8 as i
	ret gltab+i*40
end

# the fields of the n bytes at p into o, address and length of each: the
# text between single spaces, of which there are at most six. 0 if a field
# is empty or holds white space, else their number
fn fields p n o
	e=p+n
	k=0
	label nextf
	s=p
	while p<e
		loadb p as c
		jeq c 32 endf
		call scspace c as w
		jnz w no
		p+=1
	end
	label endf
	jeq p s no
	jeq k 6 no
	store o+k*16 s
	store o+k*16+8 p-s
	k+=1
	if p<e
		p+=1
		jeq p e no
		jmp nextf
	end
	ret k
	label no
	ret 0
end

# what the walk of tools/lib/flow.aw asks of the position n for the
# variable v
fn step n v
	call line n as l
	call lreads l v as r
	if r
		ret 1 0 0
	end
	call lwrites l v as r
	if r
		ret 0 0 0
	end
	call linfo l as k t
	if (k==6)|(k==3)
		ret 0 0 0
	end
	if k==4
		call getpos t as p
		jeq p -1 fail
		ret 2 p -1
	end
	if k==5
		call getpos t as p
		jeq p -1 fail
		ret 2 n+1 p
	end
	ret 2 n+1 -1
	label fail
	ret 1 0 0
end

# add the n bytes at p to the text, which has room
fn tadd p n
	call byadd text p n as r
	call must r
end

# the lines at the positions n and n+1: "cmp a b as v" and "jz v l" or
# "jnz v l", where v is no var, differs from a and b and is dead after
# both ways, become "jcc a b l". 1 if they did
fn tryfuse n
	local fa 96
	local fb 96
	call line n as la
	call line n+1 as lb
	load la+32 as r
	load lb+32 as s
	jnz r|s no
	load la as p
	load la+8 as c
	call fields p c fa as c
	jne c 5 no
	load lb as p
	load lb+8 as c
	call fields p c fb as c
	jne c 3 no
	load fa as p
	load fa+8 as c
	call scwords1 p c as r
	jz r no
	call scfind p c as k
	jge k-kcmp 10 no
	load fa+48 as p
	load fa+56 as c
	call scfind p c as r
	jne r kas no
	load fa+64 as vp
	load fa+72 as vn
	call scwords1 vp vn as r
	jz r no
	call scfind vp vn as v
	jz v no
	load fb as p
	load fb+8 as c
	call scfind p c as kb
	jz (kb==kjz)|(kb==kjnz) no
	load fb+16 as p
	load fb+24 as c
	call scfind p c as r
	jne r v no
	load fb+32 as p
	load fb+40 as c
	call scwords1 p c as r
	jz r no
	call scfind p c as t
	jz t no
	call getpos t as tp
	jeq tp -1 no
	if v<gnid
		loadb gflag+v as r
		jnz r no
	end
	# v is neither of the two values
	i=16
	while i<48
		load fa+i as p
		load fa+i+8 as c
		if c==vn
			call sceq p vp vn as r
			jnz r no
		end
		i+=16
	end
	ref step as sr
	call fwdead sr gm v n+2 tp as r
	jz r no
	k-=kcmp
	if kb==kjz
		loadb inv+k as k
	end
	load text as p
	load text+8 as c
	store la p+c
	call scatom kjcc+k as q m
	call tadd q m
	i=16
	while i<48
		call tadd " "
		load fa+i as q
		load fa+i+8 as m
		call tadd q m
		i+=16
	end
	call tadd " "
	load fb+32 as q
	load fb+40 as m
	call tadd q m
	load text+8 as m
	store la+8 m-c
	call retok la
	store lb+32 1
	store lb+24 0
	ret 1
	label no
	ret 0
end

# fuse the pairs of the scope of m lines whose line numbers are at base
fn fusescope base m
	gsc=base
	gm=m
	gstamp+=1
	n=0
	while n<m
		call line n as l
		call linfo l as k t
		if k==1
			call setpos t n
		end
		n+=1
	end
	made=0
	n=0
	while n+1<m
		call tryfuse n as r
		made+=r
		n+=1
	end
	ret made
end

# 1 if the jump at the position n to the label t, which is the only jump
# to it, may open a block that the label closes: the label follows within
# 16 lines and is no state of the compiler, the jump has no comment and no
# string, the label line is the label alone, and no line from one to the
# other is empty or a comment
fn iscand n t
	call getref t as r
	jne r 1 no
	call getpos t as tp
	jeq tp -1 no
	jge n tp no
	jgt tp-n 16 no
	jlt t-kkeep 22 no
	call line n as l
	load l as p
	load l+8 as c
	while c
		loadb p as r
		jeq r 35 no
		jeq r 34 no
		p+=1
		c-=1
	end
	call line tp as l
	load l as p
	load l+8 as c
	call scatom t as q m
	jne c m+6 no
	call sceq p "label " as r
	jz r no
	call sceq p+6 q m as r
	jz r no
	i=n
	while i<=tp
		call line i as l
		load l as p
		load l+8 as c
		jz c no
		loadb p as r
		jeq r 35 no
		i+=1
	end
	ret 1
	label no
	ret 0
end

# make blocks in the scope of m lines whose line numbers are at base
fn blockscope base m
	gsc=base
	gm=m
	gstamp+=1
	alloc m*16+16 as cand
	alloc m*16+16 as acc
	call must cand
	call must acc
	n=0
	while n<m
		call line n as l
		call linfo l as k t
		if k==1
			call setpos t n
		end
		if (k==4)|(k==5)
			call addref t
		end
		n+=1
	end
	# the candidates, as jump and label positions, in the order of the jumps
	nc=0
	n=0
	while n<m
		call line n as l
		call linfo l as k t
		if k==5
			call iscand n t as r
			if r
				call getpos t as tp
				store cand+nc*16 n
				store cand+nc*16+8 tp
				nc+=1
			end
		end
		n+=1
	end
	# the shortest first, those of one length in their order
	i=1
	while i<nc
		load cand+i*16 as a
		load cand+i*16+8 as b
		j=i
		while j
			load cand+j*16-16 as c
			load cand+j*16-8 as d
			jle d-c b-a put
			store cand+j*16 c
			store cand+j*16+8 d
			j-=1
		end
		label put
		store cand+j*16 a
		store cand+j*16+8 b
		i+=1
	end
	# take each that lies beside, inside or around every one taken before
	na=0
	i=0
	while i<nc
		load cand+i*16 as a
		load cand+i*16+8 as b
		j=0
		while j<na
			load acc+j*16 as c
			load acc+j*16+8 as d
			jz (b<c)|(d<a)|((a<c)&(d<b))|((c<a)&(b<d)) skip
			j+=1
		end
		store acc+na*16 a
		store acc+na*16+8 b
		na+=1
		label skip
		i+=1
	end
	# the jump becomes if with the opposite test, without its label; the
	# label becomes end
	i=0
	while i<na
		load acc+i*16 as a
		load acc+i*16+8 as b
		call line a as l
		load l+16 as w
		w=gwtab+w*8
		load l+24 as c
		load w as k
		if k==kjz
			k=kif
		else
			if k==kjnz
				k=kifz
			else
				loadb inv+k-kjcc as k
				k+=kifcc
			end
		end
		load text as p
		load text+8 as d
		store l p+d
		call scatom k as q r
		call tadd q r
		j=1
		while j+1<c
			call tadd " "
			load w+j*8 as k
			call scatom k as q r
			call tadd q r
			j+=1
		end
		load text+8 as r
		store l+8 r-d
		call line b as l
		store l endtext
		store l+8 3
		i+=1
	end
	free cand
	free acc
	ret na
end

# the scopes of the lines as they are now, into idx and tab: their number
fn scopes idx tab
	alloc gnl+8 as kinds
	call must kinds
	i=0
	while i<gnl
		l=gltab+i*40
		load l+24 as c
		k=0
		if c
			load l+16 as w
			load gwtab+w*8 as w
			if w==kfn
				k=1
			end
			if w==kend
				k=3
			end
		end
		storeb kinds+i k
		i+=1
	end
	call fwscopes kinds gnl idx tab as n
	call must n
	free kinds
	ret n
end

fn main
	call argc as n
	if n!=3
		call die "usage: fuse in.aw out.aw\n"
	end
	call argv 1 as ip il
	call argv 2 as op ol
	call sclist words as r
	call must r
	call sccount as r
	if r!=klast
		call die "fuse: the table of words is not as numbered\n"
	end
	call fileread ip il text as n
	ifslt n 0
		call failpath "cannot read " ip il
	end
	# the lines made here are never longer together than twice the source
	call byneed text n*2+64 as r
	call must r
	load text as p
	e=p+n
	gnl=1
	q=p
	while q<e
		loadb q as c
		gnl+=c==10
		q+=1
	end
	alloc gnl*40+40 as gltab
	alloc (n*3+gnl+64)*8 as gwtab
	call must gltab
	call must gwtab
	l=gltab
	while 1
		q=p
		while q<e
			loadb q as c
			jeq c 10 eol
			q+=1
		end
		label eol
		store l p
		store l+8 q-p
		store l+32 0
		call retok l
		l+=40
		jeq q e split
		p=q+1
	end
	label split
	call sccount as gnid
	gnid+=1
	alloc gnid*16 as gpos
	alloc gnid*16 as gref
	alloc gnid as gflag
	call must gpos
	call must gref
	call must gflag
	# the names of the vars: the words after "var " up to a #
	i=0
	while i<gnl
		l=gltab+i*40
		load l as p
		load l+8 as c
		if c>=4
			call sceq p "var " as r
			if r
				e=p+c
				p+=3
				while p<e
					loadb p as c
					jeq c 35 vend
					call scspace c as r
					if r
						p+=1
					else
						q=p
						while q<e
							loadb q as c
							jeq c 35 wend
							call scspace c as r
							jnz r wend
							q+=1
						end
						label wend
						call scfind p q-p as k
						if k
							if k<gnid
								storeb gflag+k 1
							end
						end
						p=q
					end
				end
				label vend
			end
		end
		i+=1
	end
	alloc gnl*8+8 as idx
	alloc gnl*16+32 as tab
	call must idx
	call must tab
	call fwroom gnl as r
	call must r
	call scopes idx tab as ns
	fused=0
	i=0
	while i<ns
		load tab+i*16 as a
		load tab+i*16+8 as m
		call fusescope idx+a*8 m as r
		fused+=r
		i+=1
	end
	# the deleted lines go
	j=0
	i=0
	while i<gnl
		l=gltab+i*40
		load l+32 as r
		ifz r
			q=gltab+j*40
			call bycopy q l 40
			j+=1
		end
		i+=1
	end
	gnl=j
	call scopes idx tab as ns
	blocks=0
	i=0
	while i<ns
		load tab+i*16 as a
		load tab+i*16+8 as m
		call blockscope idx+a*8 m as r
		blocks+=r
		i+=1
	end
	i=0
	while i<gnl
		l=gltab+i*40
		load l as p
		load l+8 as c
		if i
			call byaddb out 10 as r
			call must r
		end
		call byadd out p c as r
		call must r
		i+=1
	end
	load out as p
	load out+8 as c
	call filewrite op ol p c as r
	ifslt r 0
		call failpath "cannot write " op ol
	end
	call eprint "fused "
	call byfree out
	call byaddn out fused
	call byadd out " blocks "
	call byaddn out blocks
	call byaddb out 10
	load out as p
	load out+8 as c
	call eprint p c
end

call main

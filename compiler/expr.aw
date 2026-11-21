# ---- expressions
# An argument written with operators or parentheses, and no space in it, is
# an expression. expr parses it into ex, a list of nodes in the order a
# stack machine runs them: both operands of an operator stand before it,
# the right one directly. A node is 32 bytes, a kind and three cells:
#   1 a number: its value
#   2 the address of a global name plus a number: name, length, number
#   4 a variable: its index
#   5 a var: its cell
#   6 an operator: its number, and the node of its left operand
# The operators, by number, with how tightly each binds:
#   0 *  1 /  2 %   (6)     3 +  4 -   (5)     5 <<  6 >>   (4)
#   7 &  (3)     8 ^  (2)     9 |  (1)     10 ==  11 !=  12 <  13 <=  14 >
#   15 >=   (0)
# exv is the stack of values while parsing, 40 bytes each: the node, then
# what is known of the value, four cells as in opd. exs is the stack of
# operators, a byte each, 255 for an open parenthesis.
fn exnode k a b c
	p=nex*32+ex
	store p k
	store p+8 a
	store p+16 b
	store p+24 c
	i=nex
	nex+=1
	ret i
end
fn exvpush i a b c d
	p=nexv*40+exv
	store p i
	p+=8
	store p a
	p+=8
	store p b
	p+=8
	store p c
	store p+8 d
	nexv+=1
end
fn exspush o
	storeb exs+nexs o
	nexs+=1
end
fn exspop
	nexs-=1
	loadb exs+nexs as o
	ret o
end
# the name read last, as a value: a variable, a var, a const, or the
# address of a buffer or of data, which may be declared later
fn exname
	call lvar as r
	if r!=-1
		# its last mention: never earlier than one already noted, since the value
		# of a while is read a second time from the end of its loop
		d=r*8+vlast
		load d as c
		if ip>c
			store d ip
		end
		ifz asg>>r&1
			call eunasg
		end
		call exnode 4 r 0 0 as i
		f=r*32+vk
		load f as a
		load f+8 as b
		load f+16 as c
		load f+24 as d
		call exvpush i a b c d
		ret 0
	end
	call lbuf as r
	if r!=-1
		call gent r as p
		load p+32 as d
		if d==1
			load p+16 as q
			call exnode 5 q 0 0 as i
			call exvpush i 0 0 0 0
			ret 0
		end
		if d==2
			load p+24 as q
			call exnode 1 q 0 0 as i
			call exvpush i 1 q 0 0
			ret 0
		end
	end
	call exnode 2 ns nl 0 as i
	call exvpush i 2 ns nl 0
end
# the value of a o b for two numbers, as the instructions compute it
fn exfold o a b
	if o==0
		a*=b
	end
	if o==1
		a/=b
	end
	if o==2
		a%=b
	end
	if o==3
		a+=b
	end
	if o==4
		a-=b
	end
	if o==5
		b&=63
		a<<=b
	end
	if o==6
		b&=63
		a>>=b
	end
	if o==7
		a&=b
	end
	if o==8
		a^=b
	end
	if o==9
		a|=b
	end
	if o==10
		a=a==b
	end
	if o==11
		a=a!=b
	end
	if o==12
		a=a<b
	end
	if o==13
		a=a<=b
	end
	if o==14
		a=a>b
	end
	if o==15
		a=a>=b
	end
	ret a
end
# apply operator o to the two values on top of exv. Two numbers become one
# number, except a division by zero, which is left to fail when it runs; a
# name and a number become the name with another number, if that fits the
# displacement of an instruction; anything else is an operator node. What
# is known of the result follows the operands through + and -.
fn exred o
	if nexv<2
		call err
	end
	nexv-=1
	r=nexv*40+exv
	l=r-40
	load r as ri
	load l as li
	load l+8 as lk
	load l+16 as la
	load l+24 as lb
	load l+32 as lc
	load r+8 as rk
	load r+16 as ra
	load r+24 as rb
	load r+32 as rc
	# the kinds of the two nodes, when they are the last two of the list
	ln=0
	rn=0
	if li+2==nex
		if ri+1==nex
			load li*32+ex as ln
			load ri*32+ex as rn
		end
	end
	if ln==1
		if rn==1
			if o<=2
				ifz o
					jmp f
				end
				jz ra n
			end
			label f
			call exfold o la ra as v
			nex-=2
			call exnode 1 v 0 0 as i
			nexv-=1
			call exvpush i 1 v 0 0
			ret 0
		end
	end
	# name + number, number + name, name - number
	t=0
	v=0
	if o==3
		if ln==2
			if rn==1
				v=lc+ra
				t=1
			end
		end
		if ln==1
			if rn==2
				v=rc+la
				la=ra
				lb=rb
				t=1
			end
		end
	end
	if o==4
		if ln==2
			if rn==1
				v=lc-ra
				t=1
			end
		end
	end
	if t
		ifz v+0x80000000>>32
			nex-=2
			call exnode 2 la lb v as i
			nexv-=1
			call exvpush i 2 la lb v
			ret 0
		end
	end
	label n
	call exnode 6 o li 0 as i
	# what is known: a name or a number, plus or minus a number
	k=0
	a=0
	b=0
	c=0
	if rk==1
		if o==3
			if lk==1
				k=1
				a=la+ra
			end
			if lk==2
				k=2
				a=la
				b=lb
				c=lc+ra
			end
		end
		if o==4
			if lk==1
				k=1
				a=la-ra
			end
			if lk==2
				k=2
				a=la
				b=lb
				c=lc-ra
			end
		end
	end
	if rk==2
		if o==3
			if lk==1
				k=2
				a=ra
				b=rb
				c=rc+la
			end
		end
	end
	if o<=2
		if o
			exdm=1
		end
	end
	if o==5
		exsh=1
	end
	if o==6
		exsh=1
	end
	nexv-=1
	call exvpush i k a b c
end
# the operator at the cursor, whose first byte is c
fn exop c
	call adv
	if c==42
		ret 0
	end
	if c==47
		ret 1
	end
	if c==37
		ret 2
	end
	if c==43
		ret 3
	end
	if c==45
		ret 4
	end
	if c==38
		ret 7
	end
	if c==94
		ret 8
	end
	if c==124
		ret 9
	end
	call pk as d
	if c==60
		if d==60
			call adv
			ret 5
		end
		if d==61
			call adv
			ret 13
		end
		ret 12
	end
	if c==62
		if d==62
			call adv
			ret 6
		end
		if d==61
			call adv
			ret 15
		end
		ret 14
	end
	if d!=61
		call err
	end
	call adv
	if c==61
		ret 10
	end
	if c==33
		ret 11
	end
	call err
end
# how tightly operator o binds
fn exprec o
	if o<3
		ret 6
	end
	if o<5
		ret 5
	end
	if o<7
		ret 4
	end
	if o>=10
		ret 0
	end
	ret 10-o
end
fn exinit
	nex=0
	nexv=0
	nexs=0
	exdm=0
	exsh=0
end
# parse the expression at the cursor, up to the end of its token, on top of
# the m values that exv has; it leaves one more
fn exparse m
	base=nexs
	label atom
	call pk as c
	if c==40
		call exspush 255
		call adv
		jmp atom
	end
	call low c as d
	if d
		call name
		call exname
		jmp oper
	end
	if c==45
		p=ip+1
		jge p ie bad
		loadb p as d
		call dig d as d
		jnz d num
		jmp bad
	end
	call dig c as d
	ifz d
		label bad
		call err
	end
	label num
	call rdnum as v
	call exnode 1 v 0 0 as i
	call exvpush i 1 v 0 0
	label oper
	call pk as c
	if c==41
		label cl
		jle nexs base bad
		call exspop as o
		if o!=255
			call exred o
			jmp cl
		end
		call adv
		jmp oper
	end
	jeq c 256 dn
	call blank c as d
	jnz d dn
	jeq c 10 dn
	jeq c 13 dn
	jeq c 35 dn
	call exop c as o
	call exprec o as p
	label rd
	if nexs>base
		loadb nexs-1+exs as t
		if t!=255
			call exprec t as q
			if q>=p
				call exspop as t
				call exred t
				jmp rd
			end
		end
	end
	call exspush o
	jmp atom
	label dn
	if nexs>base
		call exspop as o
		jeq o 255 bad
		call exred o
		jmp dn
	end
	m+=1
	jne nexv m bad
end
# 1 if the token at the cursor is an expression: it starts with a
# parenthesis, or has a byte after its first that no name or number has
# and is not the word as
fn excomp
	p=ip
	loadb p as c
	jeq c 40 y
	label a
	p+=1
	jge p ie n
	loadb p as c
	call blank c as d
	jnz d n
	jeq c 10 n
	jeq c 13 n
	jeq c 35 n
	jeq c 95 a
	call dig c as d
	jnz d a
	call low c as d
	jnz d a
	# "as" before a byte that separates nothing is still as, and its error
	if p-ip==2
		load2 ip as d
		jeq d 0x7361 n
	end
	label y
	ret 1
	label n
	ret 0
end
# mov <register g>, v, in its shortest form
fn movi g v
	b=g>>3
	l=g&7
	ifz v>>32
		if b
			call eb 65
		end
		call eb l|184
		immpos=op
		call e4 v
		ret 0
	end
	call eb b|72
	if v>=0xffffffff80000000
		call eb 199
		call eb l|192
		call e4 v
		ret 0
	end
	call eb l|184
	store op v
	op+=8
end
# lea <register g>, [rip+rel32], with the rel32 zero and its address in
# immpos
fn lear g
	call eb g>>3<<2|72
	call eb 141
	call eb (g&7)<<3|5
	immpos=op
	call e4 0
end
# ---- code for expressions
# The nodes of ex are run as on a stack machine, but the stack is kept by
# the compiler: exv, used again now that parsing is over, has an entry of
# 40 bytes for each value that waits, a kind and three cells. A value that
# needs no instruction yet stays what its node was, kind 1 a number, 2 a
# global name and a number, 4 a variable, 5 a var, and is used where it is
# when its operator comes; a computed value is kind 7, in a register, or 8,
# pushed. Registers come from xfree, the scratch
# registers that hold no value of the statement, rcx and rdx apart: a shift
# counts in rcx and a division needs rdx, so those two never hold a value
# that waits. When none is free, the lowest value that is in a register is
# pushed; xspl is the entry below which none is in a register, so pushed
# values are the lowest and come back in order.
fn rexw r b
	call eb r>>3<<2|b>>3|72
end
# ModRM for two registers: r in the reg field, b in the r/m field
fn modrr r b
	call eb (r&7)<<3|b&7|192
end
# <o> d, s for an instruction of the form "r/m64, r64"
fn orr o d s
	call rexw s d
	call eb o
	call modrr s d
end
# instruction n of the group 81/83 on register d with the number v, which
# fits 32 bits signed: 0 add, 1 or, 4 and, 5 sub, 6 xor, 7 cmp; in the
# shortest form, as an assembler writes it
fn ori n d v
	call rexw 0 d
	ifz v+128>>8
		call eb 131
		call modrr n d
		call eb v
		ret 0
	end
	ifz d
		# rax has a form without ModRM
		call eb n*8+5
		call e4 v
		ret 0
	end
	call eb 129
	call modrr n d
	call e4 v
end
fn epush r
	if r>=8
		call eb 65
	end
	call eb (r&7)+80
	pushed+=8
end
fn epop r
	if r>=8
		call eb 65
	end
	call eb (r&7)+88
	pushed-=8
end
# setcc d8 with the condition byte c, then movzx d32, d8
fn esetcc d c
	if d>=4
		call eb d>>3|64
	end
	call eb 15
	call eb c
	call modrr 0 d
	if d>=4
		call eb (d>>3)*5|64
	end
	call eb 15
	call eb 182
	call modrr d d
end
fn xpush k a b c
	p=nxs*40+exv
	store p k
	store p+8 a
	store p+16 b
	store p+24 c
	nxs+=1
end
# register r is free again
fn xrel r
	xfree|=1<<r
end
# a free register, the preferred one if it is free; with none free, the
# lowest waiting value that is in a register is pushed and gives its own
fn xalloc
	r=xpref
	if r<16
		jnz xfree>>r&1 t
	end
	i=0
	label a
	if i<13
		loadb i+xord as r
		jnz xfree>>r&1 t
		i+=1
		jmp a
	end
	label s
	jge xspl nxs bad
	p=xspl*40+exv
	load p as k
	xspl+=1
	jne k 7 s
	store p 8
	load p+8 as r
	call epush r
	ret r
	label bad
	call err
	label t
	xfree^=1<<r
	ret r
end
# take register x: if a waiting value is in it, that value moves
fn xtake x
	if xfree>>x&1
		xfree^=1<<x
		ret 0
	end
	i=0
	label a
	jge i nxs n
	p=i*40+exv
	load p as k
	q=p+8
	load q as r
	i+=1
	jne k 7 a
	jne r x a
	call xalloc as t
	if t!=x
		call mrr t x
		store q t
	end
	label n
end
# load the value k a b c into register r
fn xld k a b c r
	if k==1
		call movi r a
		ret 0
	end
	if k==4
		call vmov a r 139
		ret 0
	end
	if k==5
		call emem r 1 a 139
		ret 0
	end
	if k==7
		if a!=r
			call mrr r a
		end
		ret 0
	end
	ns=a
	nl=b
	call lear r
	call addref 0
	if c
		call ori 0 r c
	end
end
# how the value k a b c can be the second operand of an instruction, as
# three results: 0, a register, and 1 if it was taken for this and is to be
# freed; or 1 and a number that fits 32 bits signed; or 2 and memory, as
# emem takes it, kind then place
fn xsrc k a b c
	if k==7
		ret 0 a 1
	end
	if k==1
		ifz a+0x80000000>>32
			ret 1 a 0
		end
	end
	if k==4
		call vplace a as kk pp
		ifz kk
			ret 0 pp 0
		end
		if kk<3
			ret 2 kk pp
		end
	end
	if k==5
		ret 2 1 a
	end
	call xalloc as r
	call xld k a b c r
	ret 0 r 1
end
# take the two operands of an operator off the stack into xlk.. and xrk..;
# one that was pushed comes back into a register, the right one first
fn xpop2
	nxs-=1
	p=nxs*40+exv
	load p as c
	xrk=c
	load p+8 as c
	xra=c
	load p+16 as c
	xrb=c
	load p+24 as c
	xrc=c
	nxs-=1
	p-=40
	load p as c
	xlk=c
	load p+8 as c
	xla=c
	load p+16 as c
	xlb=c
	load p+24 as c
	xlc=c
	if xspl>nxs
		xspl=nxs
	end
	if xrk==8
		call xalloc as r
		call epop r
		xrk=7
		xra=r
	end
	if xlk==8
		call xalloc as r
		call epop r
		xlk=7
		xla=r
	end
end
# the result is being made in the register of the variable assigned: it is
# no longer free for anything else
fn xtarget
	xtin=1
	m=1<<xtr
	xfree=(xfree|m)^m
end
# the two operands change places
fn xswap
	k=xlk
	a=xla
	b=xlb
	c=xlc
	xlk=xrk
	xla=xra
	xlb=xrb
	xlc=xrc
	xrk=k
	xra=a
	xrb=b
	xrc=c
end
# the register that an operator computes in: that of its left operand if
# it is a computed value, or of its right one if the operands may change
# places (m = 1), else a new one with the left operand loaded
fn xdst m
	if xlast
		if xtr<16
			# The last operator of an assignment computes in the register of the
			# variable where it can: at once if its left operand is in that register,
			# or its right one and the two may change places; else after loading the
			# left operand there, unless the right one is in it.
			call xint xlk xla as c
			if m
				ifz c
					call xint xrk xra as c
					if c
						call xswap
					end
				end
			end
			if c
				call xtarget
				ret xtr
			end
			if xlk!=7
				call xint xrk xra as c
				if xrk==7
					c=xra==xtr
				end
				ifz c
					call xld xlk xla xlb xlc xtr
					call xtarget
					ret xtr
				end
			end
		end
	end
	if xlk==7
		ret xla
	end
	if m
		if xrk==7
			call xswap
			ret xla
		end
	end
	call xalloc as d
	call xld xlk xla xlb xlc d
	ret d
end
# a variable that has a register times a number that fits 32 bits, in
# either order, is one imul into a new register; 16 if it is not that
fn xmuli
	k=xlk
	a=xla
	v=xra
	if k==1
		if xrk==4
			k=4
			a=xra
			v=xla
			jmp t
		end
	end
	jne k 4 n
	jne xrk 1 n
	label t
	jnz v+0x80000000>>32 n
	call vplace a as kk pp
	jnz kk n
	d=16
	if xlast
		if xtr<16
			d=xtr
			call xtarget
		end
	end
	if d==16
		call xalloc as d
	end
	call rexw d pp
	ifz v+128>>8
		call eb 107
		call modrr d pp
		call eb v
		ret d
	end
	call eb 105
	call modrr d pp
	call e4 v
	ret d
	label n
	ret 16
end
# + - & ^ | and *: instruction o of xopc on the register of the left
# operand, with the right one where it is
fn xarith o
	m=0
	if o!=4
		m=1
	end
	ifz o
		call xmuli as d
		if d!=16
			call xpush 7 d 0 0
			ret 0
		end
	end
	call xdst m as d
	call xsrc xrk xra xrb xrc as s x y
	p=o*3+xopc
	ifz o
		ifz s
			call rexw d x
			call eb 15
			call eb 175
			call modrr d x
		end
		if s==1
			call rexw d d
			ifz x+128>>8
				call eb 107
				call modrr d d
				call eb x
			else
				call eb 105
				call modrr d d
				call e4 x
			end
		end
		if s==2
			call emem d x y 175
		end
		jmp f
	end
	ifz s
		loadb p as c
		call orr c d x
	end
	if s==1
		loadb p+2 as c
		call ori c d x
	end
	if s==2
		loadb p+1 as c
		call emem d x y c
	end
	label f
	ifz s
		if y
			call xrel x
		end
	end
	if o
		# the zero flag now says whether the result is zero
		xflg=d
		xflgpos=op
	end
	call xpush 7 d 0 0
end
# << and >>: by a number, or by the count moved to rcx
fn xshift o
	call xdst 0 as d
	loadb o*3+xopc+2 as n
	if xrk==1
		c=xra&63
		if c
			call rexw 0 d
			if c==1
				call eb 209
				call modrr n d
			else
				call eb 193
				call modrr n d
				call eb c
			end
			xflg=d
			xflgpos=op
		end
		jmp f
	end
	if xrk==7
		call mrr 1 xra
		call xrel xra
	else
		call xld xrk xra xrb xrc 1
	end
	call rexw 0 d
	call eb 211
	call modrr n d
	label f
	call xpush 7 d 0 0
end
# / and %: by a power of two a shift or a mask; else the left operand goes
# to rax, rdx is cleared, and the quotient is in rax, the remainder in rdx
fn xdiv o
	if xrk==1
		if xra
			c=xra-1
			ifz c&xra
				if o==2
					xra=c
					tail xarith 7
				end
				n=0
				c=xra
				label l
				c>>=1
				if c
					n+=1
					jmp l
				end
				xra=n
				tail xshift 6
			end
		end
	end
	h=0
	if xrk==7
		ifz xra
			call xalloc as t
			call mrr t 0
			xra=t
			h=1
		end
	end
	if xlk==7
		ifz xla
			h=1
		end
	end
	ifz h
		call xtake 0
	end
	h=0
	if xlk==7
		ifz xla
			h=1
		end
	end
	ifz h
		call xld xlk xla xlb xlc 0
		if xlk==7
			call xrel xla
		end
	end
	call xsrc xrk xra xrb xrc as s x y
	if s==1
		call xalloc as t
		call movi t x
		s=0
		x=t
		y=1
	end
	call eb 49
	call eb 210
	ifz s
		call rexw 0 x
		call eb 247
		call modrr 6 x
		if y
			call xrel x
		end
	else
		call emem 6 x y 247
	end
	if o==2
		call mrr 0 2
	end
	call xpush 7 0 0 0
end
# cmp <left operand>, <right operand>. The left one is compared in the
# register of its variable if it is one that has a register, else in a
# register of its own: xcl is the register and xct says whether it was
# taken for this. The results say where the right one was, as xsrc does.
fn xcmp
	l=16
	t=1
	if xlk==7
		l=xla
	end
	if xlk==4
		call vplace xla as kk pp
		ifz kk
			l=pp
			t=0
		end
	end
	if l==16
		call xalloc as l
		call xld xlk xla xlb xlc l
	end
	xcl=l
	xct=t
	call xsrc xrk xra xrb xrc as s x y
	ifz s
		call orr 57 l x
	end
	if s==1
		call ori 7 l x
	end
	if s==2
		call emem l x y 59
	end
	ret s x y
end
# a comparison as a value: 1 or 0, in a register that one of the operands
# had for itself, or in a new one
fn xcmpv o
	call xcmp as s x y
	d=16
	if xct
		d=xcl
	end
	ifz s
		if y
			if d==16
				d=x
			else
				call xrel x
			end
		end
	end
	if d==16
		call xalloc as d
	end
	loadb o*3+xopc+2 as c
	call esetcc d c
	call xpush 7 d 0 0
end
fn xop o
	call xpop2
	if o>=10
		tail xcmpv o
	end
	if o<3
		if o
			tail xdiv o
		end
	end
	if o==5
		tail xshift o
	end
	if o==6
		tail xshift o
	end
	tail xarith o
end
# compute the nodes i up to h of ex, which are one expression: its value
# is left on the stack
fn xgen i h
	while i<h
		call ochk
		p=i*32+ex
		load p as k
		load p+8 as a
		load p+16 as b
		load p+24 as c
		if k==6
			xlast=i+1==h
			call xop a
		else
			call xpush k a b c
		end
		i+=1
	end
end
# the value on top of the stack, the result, into register g
fn xfin g
	nxs-=1
	p=nxs*40+exv
	load p as k
	load p+8 as a
	load p+16 as b
	load p+24 as c
	call xld k a b c g
end
# an empty stack, and m the registers that are free; g is the one to
# prefer, 16 for none
fn xinit m g
	xfree=m
	xpref=g
	nxs=0
	xspl=0
	xtr=16
	xtin=0
end
# 1 if variable i lives in register r
fn xinreg i r
	call vplace i as kk pp
	ifz kk
		ret pp==r
	end
	ret 0
end
# 1 if the value k a is a variable that lives in the register of the
# variable being assigned
fn xint k a
	if k==4
		if xtr<16
			tail xinreg a xtr
		end
	end
	ret 0
end
# the expression parsed last is the next value of the statement: compute it
# into the register of its position, note what is known of it, count it.
# The registers that hold earlier values of the statement are not free; a
# division needs rax and rdx and a shift rcx, which are pushed around the
# computation when they hold one.
fn exarg
	call aidx as t
	call areg t as g
	call opdp as p
	call cp4 exv+8 p
	n=ai
	s8=0
	loadb cur+2 as c
	if c&4
		if n
			n-=1
			s8=exsh
		end
	end
	m=0x0fc1
	j=0
	label a
	if j<n
		if j<6
			call areg j as r
			b=1<<r
			m=(m|b)^b
			j+=1
			jmp a
		end
	end
	s0=0
	s3=0
	if exdm
		if n>=1
			s0=1
			call epush 0
			m|=1
		end
		if n>=4
			s3=1
			call epush 2
		end
	end
	if s8
		call epush 1
	end
	call xinit m g
	call xgen 0 nex
	call xfin g
	if s8
		call epop 1
	end
	if s3
		call epop 2
	end
	if s0
		call epop 0
	end
	call anext
end
# ---- loads and stores
# A load or store that is compiled like an expression (kinds 4 and 5 of
# xclass) addresses memory as [base + index + number]: xaddr computes the
# address expression into that form, and xmins writes the instruction.
# REX for an instruction with a memory operand: w for 64 bits, g the
# register in the reg field, b the base, x the index (16 for none); written
# only if it says something, or if f is set
fn erexm w g b x f
	v=w<<3|g>>3<<2
	if x<16
		v|=x>>3<<1
	end
	v|=b>>3
	if v|f
		call eb v|64
	end
end
# ModRM, SIB and displacement of [b + x + d], with g in the reg field; the
# index x counts 1, 2, 4 or 8 times, by xms
fn emodm g b x d
	g=(g&7)<<3
	b&=7
	m=0
	n=0
	if d
		m=128
		n=4
		ifz d+128>>8
			m=64
			n=1
		end
	else
		# rbp and r13 cannot be a base without a displacement
		if b==5
			m=64
			n=1
		end
	end
	s=0
	if x!=16
		s=1
	end
	if b==4
		s=1
	end
	m|=g
	if s
		call eb m|4
		i=4
		if x!=16
			i=x&7|xms<<3
		end
		call eb i<<3|b
	else
		call eb m|b
	end
	if n==1
		call eb d
	end
	if n==4
		call e4 d
	end
end
# the width in bytes of the load or store at cur, from the last letter of
# its name
fn xwidth
	loadb cur-1 as c
	if c==98
		ret 1
	end
	if c==50
		ret 2
	end
	if c==52
		ret 4
	end
	ret 8
end
# Compute the nodes 0 up to e of ex, an address, as base, index and number
# in xmb, xmx and xmd. A number added or subtracted last is the number;
# what is then added last is the index if it is a variable that has a
# register, or such a variable times 2, 4 or 8 or shifted left by 1, 2 or
# 3, which xms says as the power of two; the rest is computed into a
# register, which is that of a variable if the rest is one.
fn xaddr e
	xmx=16
	xmd=0
	xms=0
	h=e
	p=(h-1)*32+ex
	load p as k
	if k==6
		load p+8 as o
		load p-32 as rk
		load p-24 as ra
		if rk==1
			t=0
			v=0
			if o==3
				v=ra
				t=1
			end
			if o==4
				v=0-ra
				t=1
			end
			if t
				ifz v+0x80000000>>32
					xmd=v
					h-=2
				end
			end
		end
	end
	p=(h-1)*32+ex
	load p as k
	load p+8 as o
	if (k==6)&(o==3)&(h>=3)
		q=p-32
		load q as rk
		load q+8 as ra
		if rk==4
			call vplace ra as kk pp
			ifz kk
				xmx=pp
				h-=2
			end
		end
		# variable, number, * or <<: the three nodes before the +
		if (rk==6)&(h>=5)
			load q+16 as li
			load q-32 as nk
			load q-24 as n
			load q-64 as vk0
			load q-56 as vi
			t=4
			if ra==0
				t=(n==2)+(n==4)*2+(n==8)*3
			end
			if ra==5
				t=n
			end
			if (li==h-4)&(nk==1)&(vk0==4)&(t-1<3)
				call vplace vi as kk pp
				ifz kk
					xmx=pp
					xms=t
					h-=4
				end
			end
		end
	end
	call xgen 0 h
	nxs=0
	xspl=0
	load exv as k
	load exv+8 as a
	load exv+16 as b
	load exv+24 as c
	r=16
	if k==7
		r=a
	end
	if k==4
		call vplace a as kk pp
		ifz kk
			r=pp
		end
	end
	if r==16
		call xalloc as r
		if k==2
			# the number that goes with a name is the displacement, if there is none
			ifz xmd
				xmd=c
				c=0
			end
		end
		call xld k a b c r
	end
	xmb=r
end
# the instruction of a load (s = 0) or a store (s = 1) of w bytes between
# register g and the memory that xaddr found
fn xmins w s g
	if w==2
		if s
			call eb 102
		end
	end
	f=0
	if w==1
		if s
			if g>=4
				f=64
			end
		end
	end
	call erexm w==8 g xmb xmx f
	if s
		o=137
		if w==1
			o=136
		end
		call eb o
	else
		o=139
		if w<4
			call eb 15
			o=183
			if w==1
				o=182
			end
		end
		call eb o
	end
	call emodm g xmb xmx xmd
end
# a load is complete, with its name after as
fn xmload
	loadb cur as n
	if ai!=n
		call ecount
	end
	call cp4 exv+8 opd
	call memchk cur
	call xwidth as w
	load caps as f
	load caps+8 as p
	g=0
	kk=1
	ifz f
		asg|=1<<p
		store p*32+vk 0
		call vplace p as kk pp
		ifz kk
			g=pp
		end
	end
	call xinit 0x0fc1 16
	call xaddr nex
	call xmins w 0 g
	if f
		call emem 0 1 p 137
		ret 0
	end
	if kk
		call vmov p 0 137
	end
end
# A store is complete: the address, then the value, which is written from
# its register, or as a number if it fits the instruction. eop is left to
# check the access and to copy nothing of the row.
fn xmstore
	loadb cur as n
	if ai!=n
		ret 0
	end
	call cp4 exv+8 opd
	load exv as e
	e+=1
	call xwidth as w
	call xinit 0x0fc1 16
	# a value that divides needs rax: the address is then kept out of it
	if exdm
		xfree=0x0fc0
	end
	call xaddr e
	if exdm
		xfree|=1
	end
	call xgen e nex
	load exv as k
	load exv+8 as a
	load exv+16 as b
	load exv+24 as c
	if k==1
		t=1
		if w==8
			if a+0x80000000>>32
				t=0
			end
		end
		if t
			if w==2
				call eb 102
			end
			call erexm w==8 0 xmb xmx 0
			o=199
			if w==1
				o=198
			end
			call eb o
			call emodm 0 xmb xmx xmd
			if w==1
				call eb a
			end
			if w==2
				call eb a
				call eb a>>8
			end
			if w>=4
				call e4 a
			end
			jmp x
		end
	end
	r=16
	if k==7
		r=a
	end
	if k==4
		call vplace a as kk pp
		ifz kk
			r=pp
		end
	end
	if r==16
		call xalloc as r
		call xld k a b c r
	end
	call xmins w 1 r
	label x
	loadb cur+3 as c
	xskip=c
end
# The statements that only compute or compare are compiled like
# expressions: their values are parsed into ex, each as an expression, and
# no code is written until the statement is complete. xclass says which
# kind the statement at cur is: 1 it computes and keeps the result with as
# (set, and the sixteen whose operators an expression has: xso is the
# operator, -1 for set), 2 it compares two values and jumps or opens a
# block, 3 it tests one value and does, 4 it is a load, 5 a store. 0 is
# every other statement, and any line with a string, which is compiled the
# old way, by the bytes of its row.
fn xclass
	p=ip
	while p<ie
		loadb p as c
		jeq c 34 z
		jeq c 10 e
		jeq c 35 e
		p+=1
	end
	label e
	load2 cur+1 as f
	loadb cur as n
	loadb cur+3 as l
	if f&128
		if l<=3
			if f&2
				if n==2
					ret 5
				end
			else
				if n==1
					ret 4
				end
			end
		end
	end
	if f==1
		ifz l
			if n==1
				xso=-1
				ret 1
			end
		end
		if n==2
			load xrows as q
			ifz q
				# the rows of the sixteen operators, found once by their names
				sn=ns
				sl=nl
				i=0
				label b
				if i<16
					ns=i*3+exkw
					q=3
					if i>=9
						q=2
					end
					nl=q
					call kw as r
					store i*8+xrows r
					i+=1
					jmp b
				end
				ns=sn
				nl=sl
			end
			i=0
			label a
			if i<16
				load i*8+xrows as q
				if q==cur
					xso=i
					ret 1
				end
				i+=1
				jmp a
			end
		end
		ret 0
	end
	if l==5
		load4 cur+4 as c
		if n==2
			if c==0x0ff83948
				ret 2
			end
		end
		if n==1
			if c==0x0fc08548
				ret 3
			end
		end
	end
	label z
	ret 0
end
# a statement of kind 1 is complete, with its name after as: apply its
# operator and keep the result
fn xcap
	loadb cur as n
	if ai!=n
		call ecount
	end
	if xso!=-1
		call exred xso
	end
	load caps as f
	load caps+8 as p
	call xstore f p
end
# A statement of kind 2 or 3 is complete: compare its values where they
# are, or test its one value, and make eop leave out the cmp or test of the
# row and copy only its jump (xskip). A comparison that is the whole value
# of if, ifz, jz or jnz is not turned into 1 or 0 and tested: the statement
# becomes the one that compares and jumps (ifeq, jlt, ...), or its opposite
# for ifz and jz. The name read last, the label of a jump, is kept.
fn xjcond
	if xst<2
		ret 0
	end
	if xst>3
		ret 0
	end
	loadb cur as n
	if ai!=n
		ret 0
	end
	sn=ns
	sl=nl
	h=nex
	load exv as e
	e+=1
	if xst==3
		h=nex-1
		p=h*32+ex
		load p as k
		load p+8 as o
		if k!=6
			o=0
		end
		if o<10
			call xinit 0x0fc1 16
			call xgen 0 nex
			nxs-=1
			load exv as k
			load exv+8 as a
			load exv+16 as b
			load exv+24 as c
			r=16
			if k==7
				r=a
			end
			if k==4
				call vplace a as kk pp
				ifz kk
					r=pp
				end
			end
			if r==16
				call xalloc as r
				call xld k a b c r
			end
			# no test if the instruction just written left the zero flag of this value
			t=1
			if xflg==r
				if xflgpos==op
					t=0
				end
			end
			if t
				call orr 133 r r
			end
			xskip=3
			jmp x
		end
		# test rax, rax and a jump: 132 if it is taken on zero
		loadb cur+8 as b
		loadb cur+2 as f
		f&=8
		t=b==133
		if f
			t=b==132
		end
		ifz t
			if o<12
				o^=1
			else
				o=27-o
			end
		end
		q=exnm
		if f
			storeb q 105
			q+=1
			storeb q 102
		else
			storeb q 106
		end
		q+=1
		load2 o*3+exkw as c
		store2 q c
		q+=2
		c=exnm
		ns=c
		nl=q-c
		call kw as r
		cur=r
		load p+16 as e
		e+=1
		ai=2
	end
	call xinit 0x0fc1 16
	call xgen 0 e
	call xgen e h
	call xpop2
	call xcmp as s x y
	xskip=3
	label x
	ns=sn
	nl=sl
end
# after the name that starts a line: 0, or 1 for "=", or 2 + an operator
# for the operator and "=", with the cursor behind the "="
fn exasg
	call pk as c
	p=ip+1
	jge p ie n
	loadb p as d
	if c==61
		jeq d 61 n
		call adv
		ret 1
	end
	o=99
	if c==42
		o=0
	end
	if c==47
		o=1
	end
	if c==37
		o=2
	end
	if c==43
		o=3
	end
	if c==45
		o=4
	end
	if c==38
		o=7
	end
	if c==94
		o=8
	end
	if c==124
		o=9
	end
	if o!=99
		jne d 61 n
		ip+=2
		ret o+2
	end
	jne c d n
	p+=1
	jge p ie n
	loadb p as d
	jne d 61 n
	if c==60
		ip+=3
		ret 7
	end
	if c==62
		ip+=3
		ret 8
	end
	label n
	ret 0
end
# "<name>=<expression>", or with operator f before the "=" (-1 for none):
# compute the expression, with the name as its left operand if there is an
# operator, and keep the result as "as <name>" would
fn exasn f
	ts=ns
	tl=nl
	call exinit
	m=0
	if f!=-1
		call exname
		m=1
	end
	call exparse m
	if f!=-1
		call exred f
	end
	call eol
	ns=ts
	nl=tl
	call lbuf as r
	if r!=-1
		call gent r as p
		load p+32 as d
		if d==1
			load p+16 as p
			call xstore 1 p
			ret 0
		end
	end
	o=nv
	call defv as i
	load i*8+vlocal as d
	if d
		call edup
	end
	if infn
		if nv!=o
			# a new variable begins behind the line, after the last mention of every
			# operand, so that it may take the place of one that is done
			d=i*8+vfirst
			load d as c
			store d c+1
		end
	end
	call xstore 0 i
end
# keep the expression in ex, whose value is alone on exv: in the cell i of
# a var (f = 1), or in variable i, which is thereby assigned
fn xstore f i
	q=exv+8
	load q as k0
	q+=8
	load q as k1
	q+=8
	load q as k2
	load q+8 as k3
	if f
		call xinit 0x0fc1 0
		call xgen 0 nex
		call xfin 0
		call emem 0 1 i 137
		ret 0
	end
	asg|=1<<i
	d=i*32+vk
	store d k0
	d+=8
	store d k1
	d+=8
	store d k2
	store d+8 k3
	call vplace i as kk pp
	if kk
		# the variable lives in memory: through rax
		call xinit 0x0fc1 0
		call xgen 0 nex
		call xfin 0
		call vmov i 0 137
		ret 0
	end
	# The variable has a register. If no variable of the expression lives in
	# that register (the variable itself, or one that is done and left it its
	# place), the register is free for the computation and preferred, so that
	# the result is likely to be made in it. Otherwise it holds a value the
	# expression still reads, and only the last operator may write it (xdst).
	j=0
	al=0
	label a
	if j<nex
		d=j*32+ex
		load d as c
		if c==4
			load d+8 as c
			call xinreg c pp as c
			al|=c
		end
		j+=1
		jmp a
	end
	m=0x0fc1
	g=16
	ifz al
		m|=1<<pp
		g=pp
	end
	call xinit m g
	xtr=pp
	call xgen 0 nex
	ifz xtin
		call xfin pp
	end
	xtr=16
end

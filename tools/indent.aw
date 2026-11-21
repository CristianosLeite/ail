# build/tools/indent file.aw ...
# build/tools/indent --check file.aw ...
# build/tools/indent -
#
# Indents AIL sources as docs/language.md says under "Source style": one
# tab for each block a line stands in. The lines between fn (or async
# fn), while or an if in any form and their end are one level deeper;
# else and end stand at the level of the line that opened the block. It
# changes the spaces and tabs at the start of a line and no other byte,
# so the compiler reads what it read before. A line that starts inside a
# string is part of the string and stays as it is, and a line of blanks
# only loses them.
#
# A file is written again only if a line of it changes. With --check
# nothing is written: each line that would change is printed as
# path:line. With - the source is read from stdin and written to stdout.
#
# It does not check the program: an end too many closes nothing, and a
# block without an end stays open to the end of the file.
#
# Status 0, or 1 with a message when a file cannot be read or written,
# and with --check when a line would change.
use "lib/io.aw"
use "lib/bytes.aw"
use "lib/file.aw"

# gcheck: --check was given; gbad: lines that --check printed
var gcheck gbad

# the source as read, and as it is written
buf text 24
buf out 24

# the words that open a block, each with its length before it
data openers 2 "fn" 5 "async" 5 "while" 2 "if" 3 "ifz"
data 4 "ifeq" 4 "ifne" 4 "iflt" 4 "ifle" 4 "ifgt" 4 "ifge"
data 5 "ifslt" 5 "ifsle" 5 "ifsgt" 5 "ifsge" 0

fn oom
	call die "indent: out of memory\n"
end

# 0 is no memory
fn must r
	ifz r
		call oom
	end
end

fn failpath m ml p pl
	call eprint "indent: "
	call eprint m ml
	call eprint p pl
	call eprint "\n"
	sys exit_group 1
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

# whether the line from p to e ends inside a string, s saying whether it
# starts in one: a string may go on over the end of a line, a backslash
# in it takes the next byte along, and a comment has no string
fn strend p e s
	while p<e
		loadb p as c
		if s
			if c==92
				p+=1
			end
			if c==34
				s=0
			end
		else
			if c==35
				ret 0
			end
			if c==34
				s=1
			end
		end
		p+=1
	end
	ret s
end

# what the line from p to e, which starts with no blank, does to the
# depth: 1 it opens a block, 2 it is else, 3 it is end, 0 anything else.
# The first word counts only when a blank, a comment or the end of the
# line follows it, as the compiler has it: if=1 sets a variable
fn kind p e
	q=p
	while q<e
		loadb q as c
		if ((c<97)|(c>122))&((c<48)|(c>57))&(c!=95)
			jmp cut
		end
		q+=1
	end
	label cut
	if q<e
		loadb q as c
		if (c!=32)&(c!=9)&(c!=13)&(c!=35)
			ret 0
		end
	end
	n=q-p
	call same p n "else" as r
	if r
		ret 2
	end
	call same p n "end" as r
	if r
		ret 3
	end
	w=openers
	label next
	loadb w as m
	ifz m
		ret 0
	end
	call same p n w+1 m as r
	if r
		ret 1
	end
	w+=m+1
	jmp next
end

# a line of the file at path that --check found wrong
fn report path pl line
	call print path pl
	call print ":"
	call putn line
	call print "\n"
	gbad+=1
end

# write the n bytes at p into the buffer out, indented: the number of
# lines that changed. With --check each of them is reported
fn indent p n path pl
	e=p+n
	depth=0
	instr=0
	line=0
	changed=0
	while p<e
		line+=1
		# the line is the bytes from p to le, without its LF
		le=p
		while le<e
			loadb le as c
			if c==10
				jmp found
			end
			le+=1
		end
		label found
		if instr
			call byadd out p le-p as r
			call must r
			call strend p le 1 as instr
		else
			b=p
			while b<le
				loadb b as c
				if (c!=32)&(c!=9)
					jmp word
				end
				b+=1
			end
			label word
			call kind b le as k
			if k==3
				if depth
					depth-=1
				end
			end
			d=depth
			if k==2
				if d
					d-=1
				end
			end
			if k==1
				depth+=1
			end
			# a line without a statement or a comment has no indentation
			if b==le
				d=0
			else
				loadb b as c
				if (c==13)&(b+1==le)
					d=0
				end
			end
			# is it right as it stands, d tabs and nothing else
			bad=b-p!=d
			q=p
			while q<b
				loadb q as c
				if c!=9
					bad=1
				end
				q+=1
			end
			if bad
				changed+=1
				if gcheck
					call report path pl line
				end
			end
			while d
				call byaddb out 9 as r
				call must r
				d-=1
			end
			call byadd out b le-b as r
			call must r
			call strend b le 0 as instr
		end
		p=le
		if p<e
			call byaddb out 10 as r
			call must r
			p+=1
		end
	end
	ret changed
end

# stdin to stdout
fn filter
	call filereadfd 0 text as n
	ifslt n 0
		call die "indent: cannot read stdin\n"
	end
	load text as p
	load text+8 as n
	call indent p n "-" as c
	load out as p
	load out+8 as n
	call print p n as r
	ifz r
		call die "indent: cannot write stdout\n"
	end
end

fn onefile path pl
	call bycut text 0
	call bycut out 0
	call fileread path pl text as n
	ifslt n 0
		call failpath "cannot read " path pl
	end
	load text as p
	load text+8 as n
	call indent p n path pl as c
	if gcheck
		ret 0
	end
	if c
		load out as p
		load out+8 as n
		call filewrite path pl p n as r
		ifslt r 0
			call failpath "cannot write " path pl
		end
	end
end

fn usage
	call die "usage: indent [--check] file.aw ... | indent -\n"
end

fn main
	call argc as n
	i=1
	if n>1
		call argv 1 as p l
		call same p l "--check" as r
		if r
			gcheck=1
			i=2
		end
	end
	if i>=n
		call usage
	end
	call argv i as p l
	call same p l "-" as r
	if r
		if (n!=2)|gcheck
			call usage
		end
		call filter
		ret 0
	end
	while i<n
		call argv i as p l
		call onefile p l
		i+=1
	end
	if gbad
		sys exit_group 1
	end
end

call main

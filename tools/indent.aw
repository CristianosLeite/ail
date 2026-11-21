# build/tools/indent file.aw ...
# build/tools/indent --check file.aw ...
# build/tools/indent -
#
# Indents AIL sources as docs/language.md says under "Source style", with
# tools/lib/dent.aw, which fuse and infix use for what they write: one
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
use "tools/lib/dent.aw"

# gcheck: --check was given; gbad: lines that --check printed
var gcheck gbad

# the source as read, and as it is written
buf text 24
buf out 24

fn oom
	call die "indent: out of memory\n"
end

fn failpath m ml p pl
	call eprint "indent: "
	call eprint m ml
	call eprint p pl
	call eprint "\n"
	sys exit_group 1
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
	f=0
	if gcheck
		ref report as f
	end
	call dtindent p n out f path pl as c
	ifslt c 0
		call oom
	end
	ret c
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
		call dtsame p l "--check" as r
		if r
			gcheck=1
			i=2
		end
	end
	if i>=n
		call usage
	end
	call argv i as p l
	call dtsame p l "-" as r
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

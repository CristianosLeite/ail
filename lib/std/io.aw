# lib/std/io.aw -- output, decimal numbers and the arguments of the process.
# Put  use "lib/std/io.aw"  at the top of a program compiled from the top of the
# repository. The line below runs where the use stands, so use it before
# the first call of argc or argv.
#
# Every variable and parameter of this file has a name that starts with
# "io": "as" on the name of a var writes that var in any function, so a
# short name here would be a var of a program that declared one before
# the use, and a variable named like the var below would write it.
var ioargp
args as ioargp

# write the ion bytes at iop to the file iofd, in as many writes as it
# takes:
# 1 if all went out, 0 after an error
fn fdwrite iofd iop ion
	label more
	ifz ion
		ret 1
	end
	sys write iofd iop ion as iow
	jsle iow 0 bad
	iop+=iow
	ion-=iow
	jmp more
	label bad
	ret 0
end

# the same to stdout and to stderr
fn print iop ion
	tail fdwrite 1 iop ion
end
fn eprint iop ion
	tail fdwrite 2 iop ion
end

# write the ion bytes at iop to stderr and end the program with status 1,
# every thread of it
fn die iop ion
	call fdwrite 2 iop ion
	sys exit_group 1
end

# the length of the NUL-terminated string at iop
fn strlen iop
	ioq=iop
	label next
	loadb ioq as ioc
	ifz ioc
		ret ioq-iop
	end
	ioq+=1
	jmp next
end

# print the unsigned number ion in decimal: 1 if it went out, 0 after an error
fn putn ion
	local iodigits 24
	iop=iodigits+24
	label next
	iop-=1
	storeb iop ion%10+48
	ion/=10
	jnz ion next
	call print iop iodigits+24-iop as ior  # not tail: the digits are in this frame
	ret ior
end

# the number of arguments of the process, its own name included
fn argc
	load ioargp as ion
	ret ion
end

# argument ioi as two results, its address and its length, or 0 and 0 if the
# process has no such argument; argument 0 is the name of the program
fn argv ioi
	load ioargp as ion
	ifge ioi ion
		ret 0 0
	end
	load ioargp+8+ioi*8 as ios
	call strlen ios as iol
	ret ios iol
end

# tools/lib/flow.aw -- the lines of a source as scopes, and ways through
# the lines of one scope, for the tools that rewrite. A tool knows what
# its lines mean and says so through a table and a function; this file
# only walks.
#
# Every name of this file starts with "fw"; a program has no var of such
# a name (see lib/std/io.aw).

# the mark of every position (8 bytes each), the positions still to
# visit, the number of positions there is room for, and the current mark
buf fwst 32

# make room for walks over scopes of up to fwm lines: 1, or 0 without
# memory. The room is kept; a later call with more lines replaces it.
fn fwroom fwm
	load fwst+16 as fwc
	if fwc>=fwm
		ret 1
	end
	alloc fwm*8+8 as fwp
	alloc fwm*8+24 as fwq
	if (fwp==0)|(fwq==0)
		ret 0
	end
	store fwst fwp
	store fwst+8 fwq
	store fwst+16 fwm
	store fwst+24 0
	ret 1
end

# The lines of each function and of the top level. fwkinds has a byte for
# each of the fwn lines of the source: 1 for the line that starts a
# function, 2 for one that opens a block, 3 for an end, 0 for any other.
# A function is the lines from its start to the end that closes it, the
# one that finds no block open; a tool that marks no line 2 closes it at
# the first end. A function that is never closed, or in which another
# starts, is no scope and its lines are in none. The top level is the
# lines outside functions and is the last scope.
#
# fwidx gets the line numbers of all scopes, 8 bytes each, with room for
# fwn; fwtab gets 16 bytes for each scope, the index of its first entry
# in fwidx and the number of its lines, with room for fwn+1 scopes.
# Returns the number of scopes, or 0 without memory.
fn fwscopes fwkinds fwn fwidx fwtab
	alloc fwn*8+8 as fwtop
	ifz fwtop
		ret 0
	end
	fwnt=0
	fwo=0
	fwcur=-1
	fwdepth=0
	fwns=0
	fwi=0
	while fwi<fwn
		loadb fwkinds+fwi as fwk
		if fwk==1
			if fwcur!=-1
				fwo=fwcur
			end
			fwcur=fwo
			store fwidx+fwo*8 fwi
			fwo+=1
			fwdepth=0
		else
			if fwcur==-1
				store fwtop+fwnt*8 fwi
				fwnt+=1
			else
				store fwidx+fwo*8 fwi
				fwo+=1
				if fwk==2
					fwdepth+=1
				end
				if fwk==3
					ifz fwdepth
						store fwtab+fwns*16 fwcur
						store fwtab+fwns*16+8 fwo-fwcur
						fwns+=1
						fwcur=-1
					else
						fwdepth-=1
					end
				end
			end
		end
		fwi+=1
	end
	if fwcur!=-1
		fwo=fwcur
	end
	fwi=0
	while fwi<fwnt
		load fwtop+fwi*8 as fwk
		store fwidx+fwo*8+fwi*8 fwk
		fwi+=1
	end
	store fwtab+fwns*16 fwo
	store fwtab+fwns*16+8 fwnt
	free fwtop
	ret fwns+1
end

# Is the value fwv dead at the positions fwa and fwb of a scope of fwm
# lines: does no way from there read it before writing it? A position
# that is not below fwm ends its way, so -1 stands for no position.
# fwroom was called for fwm lines or more.
#
# fwstep is the address of a function of the tool. Called with a position
# and fwv, it returns three values: 1 if the line there reads the value
# or the ways from it are not known (the answer is then 0); 0 if the way
# ends there, the value written or the scope left; 2 and the two
# positions the ways go on to, each of which may be -1.
# Every position is visited once, in no promised order.
fn fwdead fwstep fwm fwv fwa fwb
	load fwst as fwmark
	load fwst+8 as fwstack
	load fwst+24 as fwcur
	fwcur+=1
	store fwst+24 fwcur
	store fwstack fwa
	store fwstack+8 fwb
	fwsp=2
	while fwsp
		fwsp-=1
		load fwstack+fwsp*8 as fwn
		label fwgo
		if fwn<fwm
			load fwmark+fwn*8 as fwr
			if fwr!=fwcur
				store fwmark+fwn*8 fwcur
				callp fwstep fwn fwv as fwr fwx fwy
				if fwr==1
					ret 0
				end
				if fwr==2
					store fwstack+fwsp*8 fwy
					fwsp+=1
					fwn=fwx
					jmp fwgo
				end
			end
		end
	end
	ret 1
end

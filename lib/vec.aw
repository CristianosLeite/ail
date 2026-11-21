# lib/vec.aw -- a vector of 64-bit values that grows.
#
# A vector is 24 bytes that the caller owns, in a buf or a local: the
# address of its values, their number and the number there is room for.
# All zero is an empty vector, so a buf is one as it stands and a local
# is one after three stores of 0. The functions take the address of the
# 24 bytes, here called the vector. A value has an index, from 0.
#
# vecpush and vecreserve may move the values to a new address (an alloc,
# a copy, a free): an address of a value is only good until the next of
# those calls, an index always. vecpush takes twice the room when it has
# none left, at least 512 values; vecreserve takes the room it is asked
# for, in all and not in addition, and after it that many values move
# nothing. Both return 1, or 0 when the kernel has no memory or the room
# would not fit in 64 bits of bytes, and then nothing changed.
#
# vecpop and vecget return a value and 1, or 0 and 0 when there is no
# such value, since a value may be 0. The caller ends the vector with
# vecfree.
#
# Every variable and parameter of this file has a name that starts with
# "vec"; a program has no var of such a name (see lib/io.aw).

# make room for vecn values in all
fn vecreserve vecv vecn
	load vecv+16 as veccap
	if veccap>=vecn
		ret 1
	end
	# bytes that do not fit in 64 bits are no memory
	if vecn>>61
		ret 0
	end
	alloc vecn*8 as vecp
	ifz vecp
		ret 0
	end
	load vecv as vecold
	load vecv+8 as veclen
	veci=0
	while veci<veclen
		load vecold+veci*8 as vecx
		store vecp+veci*8 vecx
		veci+=1
	end
	if vecold
		free vecold
	end
	store vecv vecp
	store vecv+16 vecn
	ret 1
end

# add the value vecx behind the last
fn vecpush vecv vecx
	load vecv+8 as veclen
	load vecv+16 as veccap
	if veclen==veccap
		veccap*=2
		if veccap<512
			veccap=512
		end
		call vecreserve vecv veccap as vecok
		ifz vecok
			ret 0
		end
	end
	load vecv as vecp
	store vecp+veclen*8 vecx
	store vecv+8 veclen+1
	ret 1
end

# take the last value off: the value and 1, or 0 and 0 if there is none
fn vecpop vecv
	load vecv+8 as veclen
	ifz veclen
		ret 0 0
	end
	veclen-=1
	store vecv+8 veclen
	load vecv as vecp
	load vecp+veclen*8 as vecx
	ret vecx 1
end

# the value at the index veci and 1, or 0 and 0 if there is none
fn vecget vecv veci
	load vecv+8 as veclen
	if veci>=veclen
		ret 0 0
	end
	load vecv as vecp
	load vecp+veci*8 as vecx
	ret vecx 1
end

# make vecx the value at the index veci: 1, or 0 if there is none
fn vecset vecv veci vecx
	load vecv+8 as veclen
	if veci>=veclen
		ret 0
	end
	load vecv as vecp
	store vecp+veci*8 vecx
	ret 1
end

# give the values back; the vector is empty and may be used again
fn vecfree vecv
	load vecv as vecp
	if vecp
		free vecp
	end
	store vecv 0
	store vecv+8 0
	store vecv+16 0
end

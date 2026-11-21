# lib/heap.aw -- a heap of 64-bit values that gives the smallest first.
#
# A heap is a vector of lib/vec.aw, which a program uses first: 24 bytes
# that the caller owns, all zero for an empty heap. The values are kept
# so that the one at the index i is not larger than those at 2i+1 and
# 2i+2, in the unsigned order; the smallest is the first. The functions
# take the address of the 24 bytes, here called the heap.
#
# heappush may move the values, as vecpush does, and returns 1, or 0
# when there is no memory, and then nothing changed. heappeek and
# heappop return a value and 1, or 0 and 0 for an empty heap, since a
# value may be 0. Of equal values any may come first. The caller ends
# the heap with heapfree.
#
# Every variable and parameter of this file has a name that starts with
# "heap"; a program has no var of such a name (see lib/io.aw).

# add the value heapx
fn heappush heaph heapx
	call vecpush heaph heapx as heapi
	ifz heapi
		ret 0
	end
	load heaph as heapp
	load heaph+8 as heapi
	heapi-=1
	# the values above it that are larger come down
	while heapi
		heapc=heapi-1>>1
		load heapp+heapc*8 as heapy
		jle heapy heapx put
		store heapp+heapi*8 heapy
		heapi=heapc
	end
	label put
	store heapp+heapi*8 heapx
	ret 1
end

# the smallest value and 1, or 0 and 0 if there is none
fn heappeek heaph
	load heaph+8 as heapn
	ifz heapn
		ret 0 0
	end
	load heaph as heapp
	load heapp as heapx
	ret heapx 1
end

# take the smallest value out: the value and 1, or 0 and 0
fn heappop heaph
	load heaph+8 as heapn
	ifz heapn
		ret 0 0
	end
	load heaph as heapp
	load heapp as heapr
	heapn-=1
	store heaph+8 heapn
	# the last value goes where the first was and down from there
	load heapp+heapn*8 as heapx
	heapi=0
	heapc=1
	while heapc<heapn
		load heapp+heapc*8 as heapy
		if heapc+1<heapn
			load heapp+heapc*8+8 as heapz
			if heapz<heapy
				heapy=heapz
				heapc+=1
			end
		end
		jle heapx heapy put
		store heapp+heapi*8 heapy
		heapi=heapc
		heapc=heapi*2+1
	end
	label put
	store heapp+heapi*8 heapx
	ret heapr 1
end

# give the values back; the heap is empty and may be used again
fn heapfree heaph
	tail vecfree heaph
end

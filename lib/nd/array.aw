# lib/nd/array.aw -- arrays of numbers with a shape, on the model of NumPy.
#
# An array is 176 bytes that the caller owns, in a buf or a local, here
# called the array, and the functions take their address:
#
#     0  the address of the element whose indices are all 0
#     8  the kind of its elements: 1 a double; 0 is no array
#    16  the number of axes, 0 to 8
#    24  the address of the storage the elements are in
#    32  the bytes of that storage
#    40  1 if the storage is the array's, which ndfree then frees
#    48  the length of each axis, 8 words
#   112  the stride of each axis, 8 words: the bytes from one element to
#        the next along it, a signed number
#
# All zero is no array, so a buf is one as it stands. An element is 8
# bytes, and the element with the indices i, j, ... is at the address at
# 0 plus i times the first stride plus j times the second and so on. The
# functions of this file make arrays whose elements lie one behind the
# other, the last index running fastest, which is the order "row-major".
#
# ndnew takes storage with alloc, all zero, and the array owns it; ndwrap
# makes an array of bytes the caller has, which stay the caller's and
# must be there as long as the array is used. Both write the array only
# when all went well: they return 1, or 0 for more than 8 axes, for an
# axis or a number of elements of 2^60 or more, without memory, or for
# bytes that are too few, and the 176 bytes are then as they were. They
# ask nothing of what was in the 176 bytes before, so an array that owns
# storage is ended with ndfree first.
#
# Every variable and parameter of this file has a name that starts with
# "nd"; a program has no var of such a name (see lib/io.aw).

# the number of elements of the ndr axes whose lengths are at nds and 1,
# or 0 and 0 if a length or the number is 2^60 or more
fn ndcount ndr nds
	ndn=1
	ndz=1
	ndi=0
	while ndi<ndr
		load nds+ndi*8 as ndx
		if ndx>>60
			ret 0 0
		end
		ifz ndx
			ndz=0
		else
			if ndn>0x1000000000000000/ndx
				ret 0 0
			end
			ndn*=ndx
		end
		ndi+=1
	end
	if ndn>>60
		ret 0 0
	end
	ret ndn*ndz 1
end

# write the array ndd: ndr axes with the lengths at nds, elements one
# behind the other in the ndb bytes at ndp, owned if ndo
fn ndmake ndd ndp ndb ndo ndr nds
	store ndd ndp
	store ndd+8 1
	store ndd+16 ndr
	store ndd+24 ndp
	store ndd+32 ndb
	store ndd+40 ndo
	ndx=8
	ndi=ndr
	while ndi
		ndi-=1
		load nds+ndi*8 as ndn
		store ndd+48+ndi*8 ndn
		store ndd+112+ndi*8 ndx
		# an axis without elements counts as one of length 1
		if ndn
			ndx*=ndn
		end
	end
	ndi=ndr
	while ndi<8
		store ndd+48+ndi*8 0
		store ndd+112+ndi*8 0
		ndi+=1
	end
end

# make ndd an array of zeros with ndr axes, their lengths at nds
fn ndnew ndd ndr nds
	if ndr>8
		ret 0
	end
	call ndcount ndr nds as ndn ndok
	ifz ndok
		ret 0
	end
	alloc ndn*8 as ndp
	ifz ndp
		ret 0
	end
	call ndmake ndd ndp ndn*8 1 ndr nds
	ret 1
end

# the same with one axis of ndn elements
fn ndvec ndd ndn
	local ndsh 8
	store ndsh ndn
	tail ndnew ndd 1 ndsh
end

# the same with ndn rows of ndm elements
fn ndmat ndd ndn ndm
	local ndsh 16
	store ndsh ndn
	store ndsh+8 ndm
	tail ndnew ndd 2 ndsh
end

# make ndd an array of the ndb bytes at ndp, which stay the caller's
fn ndwrap ndd ndp ndb ndr nds
	if ndr>8
		ret 0
	end
	call ndcount ndr nds as ndn ndok
	ifz ndok
		ret 0
	end
	if ndn*8>ndb
		ret 0
	end
	call ndmake ndd ndp ndb 0 ndr nds
	ret 1
end

# give the storage back if it is the array's; ndd is no array then and
# may be used again
fn ndfree ndd
	load ndd+40 as ndo
	if ndo
		load ndd+24 as ndp
		free ndp
	end
	ndi=0
	while ndi<22
		store ndd+ndi*8 0
		ndi+=1
	end
end

# the number of elements
fn ndsize ndd
	load ndd+8 as ndt
	ifz ndt
		ret 0
	end
	load ndd+16 as ndr
	ndn=1
	ndi=0
	while ndi<ndr
		load ndd+48+ndi*8 as ndx
		ndn*=ndx
		ndi+=1
	end
	ret ndn
end

# the address of the element whose indices are the words at ndx, one for
# each axis, and 1, or 0 and 0 if an index is not below its length
fn ndat ndd ndx
	load ndd+8 as ndt
	ifz ndt
		ret 0 0
	end
	load ndd as ndp
	load ndd+16 as ndr
	ndi=0
	while ndi<ndr
		load ndx+ndi*8 as ndj
		load ndd+48+ndi*8 as ndn
		if ndj>=ndn
			ret 0 0
		end
		load ndd+112+ndi*8 as nds
		ndp+=ndj*nds
		ndi+=1
	end
	ret ndp 1
end

# the element at the indices at ndx and 1, or 0 and 0 if there is none
fn ndget ndd ndx
	call ndat ndd ndx as ndp ndok
	ifz ndok
		ret 0 0
	end
	load ndp as ndv
	ret ndv 1
end

# make ndv the element at the indices at ndx: 1, or 0 if there is none
fn ndset ndd ndx ndv
	call ndat ndd ndx as ndp ndok
	ifz ndok
		ret 0
	end
	store ndp ndv
	ret 1
end

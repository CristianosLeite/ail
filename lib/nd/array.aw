# lib/nd/array.aw -- arrays of numbers with a shape, on the model of NumPy.
#
# An array is 176 bytes that the caller owns, in a buf or a local, here
# called the array, and the functions take their address:
#
#     0  the address of the element whose indices are all 0
#     8  the kind of its elements: 1 doubles, 2 integers of 64 bits
#        with a sign; 0 is no array
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
# A view is an array of elements that another array has: ndslice,
# ndtrans, ndswap and ndreshape write 176 bytes and touch no element.
# The view never owns the storage, which must be there as long as the
# view is used: the caller frees the array it came from last. They take
# the view first and the array it is made of second, and the two may be
# the same 176 bytes, which then keep the storage if they owned it. They
# return 1, or 0 for what cannot be done, and the view is then as it
# was. ndcopy makes an array of its own from any other, the elements one
# behind the other again, and ndfill sets every element.
#
# A walk (ndwalk, ndwarg, ndstep) is how every function of the library
# goes over elements: 384 bytes in a local of the function with the
# lengths of the result, an index for each axis but the last, and for
# up to three arrays the address of the current run of elements along
# the last axis and their strides. An array with fewer axes or with an
# axis of length 1 goes along with a stride of 0 there, which is what
# NumPy calls broadcasting.
#
#     0  the number of axes         8  the length of the last axis
#    16  the indices, 8 words      80  the lengths, 8 words
#   144  for each of three arrays 80 bytes: the address of the run, the
#        stride along the last axis, the strides of all axes
#
# A new array is one of doubles. ndkind says that its elements are read
# as the other kind from now on and changes no bit of them; a view has
# the kind of its array when it is made and keeps its own after.
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

# copy the 176 bytes of nds to ndd, which owns the storage only if it is
# the same array
fn ndcp ndd nds
	if ndd==nds
		ret 0
	end
	ndi=0
	while ndi<22
		load nds+ndi*8 as ndx
		store ndd+ndi*8 ndx
		ndi+=1
	end
	store ndd+40 0
end

# exchange the axes ndi and ndj of ndd
fn ndxch ndd ndi ndj
	load ndd+48+ndi*8 as ndn
	load ndd+48+ndj*8 as ndm
	store ndd+48+ndi*8 ndm
	store ndd+48+ndj*8 ndn
	load ndd+112+ndi*8 as ndn
	load ndd+112+ndj*8 as ndm
	store ndd+112+ndi*8 ndm
	store ndd+112+ndj*8 ndn
end

# make ndd the elements of nds whose index on the axis ndax is ndlo or
# more and below ndhi: every ndst-th of them from ndlo on, or with a
# negative ndst from ndhi-1 on downwards
fn ndslice ndd nds ndax ndlo ndhi ndst
	load nds+8 as ndt
	ifz ndt
		ret 0
	end
	load nds+16 as ndr
	if ndax>=ndr
		ret 0
	end
	load nds+48+ndax*8 as ndn
	if ndhi>ndn
		ret 0
	end
	if ndlo>ndhi
		ret 0
	end
	ifz ndst
		ret 0
	end
	ndab=ndst
	ndf=ndlo
	slt ndst 0 as ndneg
	if ndneg
		ndab=0-ndst
		ndf=ndhi-1
	end
	ndc=(ndhi-ndlo+ndab-1)/ndab
	ifz ndc
		ndf=ndlo
	end
	load nds+112+ndax*8 as ndx
	call ndcp ndd nds
	load ndd as ndp
	store ndd ndp+ndf*ndx
	store ndd+48+ndax*8 ndc
	store ndd+112+ndax*8 ndx*ndst
	ret 1
end

# make ndd the elements of nds with the axes in the reverse order
fn ndtrans ndd nds
	load nds+8 as ndt
	ifz ndt
		ret 0
	end
	call ndcp ndd nds
	load ndd+16 as ndj
	ndi=0
	while ndi+1<ndj
		ndj-=1
		call ndxch ndd ndi ndj
		ndi+=1
	end
	ret 1
end

# make ndd the elements of nds with the axes nda and ndb exchanged
fn ndswap ndd nds nda ndb
	load nds+8 as ndt
	ifz ndt
		ret 0
	end
	load nds+16 as ndr
	if nda>=ndr
		ret 0
	end
	if ndb>=ndr
		ret 0
	end
	call ndcp ndd nds
	call ndxch ndd nda ndb
	ret 1
end

# 1 if the elements lie one behind the other, the last index fastest
fn ndcontig ndd
	load ndd+8 as ndt
	ifz ndt
		ret 0
	end
	call ndsize ndd as ndn
	ifz ndn
		ret 1
	end
	ndx=8
	load ndd+16 as ndi
	while ndi
		ndi-=1
		load ndd+48+ndi*8 as ndn
		if ndn!=1
			load ndd+112+ndi*8 as nds
			if nds!=ndx
				ret 0
			end
		end
		ndx*=ndn
	end
	ret 1
end

# make ndd the elements of nds, which lie one behind the other, with the
# ndr axes whose lengths are at ndsh and give as many elements
fn ndreshape ndd nds ndr ndsh
	if ndr>8
		ret 0
	end
	call ndcontig nds as ndok
	ifz ndok
		ret 0
	end
	call ndcount ndr ndsh as ndn ndok
	ifz ndok
		ret 0
	end
	call ndsize nds as ndm
	if ndn!=ndm
		ret 0
	end
	load nds as ndp
	load nds+8 as ndt
	load nds+24 as ndq
	load nds+32 as ndb
	ndo=0
	if ndd==nds
		load nds+40 as ndo
	end
	call ndmake ndd ndp ndb ndo ndr ndsh
	store ndd+8 ndt
	store ndd+24 ndq
	ret 1
end

# start in ndw a walk with the lengths of the array ndd and no array
fn ndwalk ndw ndd
	load ndd+16 as ndr
	store ndw ndr
	ndi=0
	while ndi<8
		load ndd+48+ndi*8 as ndn
		store ndw+16+ndi*8 0
		store ndw+80+ndi*8 ndn
		ndi+=1
	end
	ndn=1
	if ndr
		load ndd+40+ndr*8 as ndn
	end
	store ndw+8 ndn
	ndi=0
	while ndi<30
		store ndw+144+ndi*8 0
		ndi+=1
	end
end

# make nda the array number ndk, 0 to 2, of the walk ndw: 1, or 0 if
# its lengths do not go with those of the walk
fn ndwarg ndw ndk nda
	load ndw as ndr
	load nda+16 as ndq
	if ndq>ndr
		ret 0
	end
	ndo=ndw+144+ndk*80
	ndx=0
	ndi=ndr-ndq
	while ndi<ndr
		ndj=ndi+ndq-ndr
		load nda+48+ndj*8 as ndn
		load ndw+80+ndi*8 as ndm
		ndx=0
		if ndn==ndm
			load nda+112+ndj*8 as ndx
		else
			if ndn!=1
				ret 0
			end
		end
		store ndo+16+ndi*8 ndx
		ndi+=1
	end
	ndi=0
	while ndi<ndr-ndq
		store ndo+16+ndi*8 0
		ndi+=1
	end
	load nda as ndp
	store ndo ndp
	store ndo+8 ndx
	ret 1
end

# go on to the next run of elements along the last axis: 1, or 0 when
# the walk has been over all of them
fn ndstep ndw
	load ndw as nda
	if nda
		nda-=1
	end
	while nda
		nda-=1
		ndq=ndw+nda*8
		load ndq+16 as ndi
		load ndq+80 as ndn
		ndi+=1
		ndm=1
		if ndi>=ndn
			ndi=0
			ndm=1-ndn
		end
		store ndq+16 ndi
		ndk=0
		while ndk<240
			load ndq+ndk+160 as nds
			load ndw+ndk+144 as ndp
			store ndw+ndk+144 ndp+nds*ndm
			ndk+=80
		end
		if ndi
			ret 1
		end
	end
	ret 0
end

# make every element of ndd the value ndv
fn ndfill ndd ndv
	local ndw 384
	call ndsize ndd as ndn
	ifz ndn
		ret 0
	end
	call ndwalk ndw ndd
	call ndwarg ndw 0 ndd
	load ndw+8 as ndn
	load ndw+152 as nds
	ndgo=1
	while ndgo
		load ndw+144 as ndp
		ndi=ndn
		while ndi
			store ndp ndv
			ndp+=nds
			ndi-=1
		end
		call ndstep ndw as ndgo
	end
end

# make ndd an array of its own with the elements of nds, one behind the
# other; the two may be the same, and what nds owned is then freed
fn ndcopy ndd nds
	local ndw 384
	local ndnw 176
	load nds+8 as ndt
	ifz ndt
		ret 0
	end
	load nds+16 as ndr
	call ndnew ndnw ndr nds+48 as ndok
	ifz ndok
		ret 0
	end
	store ndnw+8 ndt
	call ndsize nds as ndn
	if ndn
		call ndwalk ndw ndnw
		call ndwarg ndw 0 ndnw
		call ndwarg ndw 1 nds
		load ndw+8 as ndn
		load ndw+232 as ndx
		ndgo=1
		while ndgo
			load ndw+144 as ndp
			load ndw+224 as ndq
			ndi=0
			while ndi<ndn
				load ndq as ndv
				store ndp+ndi*8 ndv
				ndq+=ndx
				ndi+=1
			end
			call ndstep ndw as ndgo
		end
	end
	if ndd==nds
		call ndfree nds
	end
	ndi=0
	while ndi<22
		load ndnw+ndi*8 as ndx
		store ndd+ndi*8 ndx
		ndi+=1
	end
	ret 1
end

# the lowest address of an element of ndd and the address behind its
# highest element; the same address twice if it has none
fn ndspan ndd
	load ndd as ndlo
	ndhi=ndlo
	call ndsize ndd as ndn
	ifz ndn
		ret ndlo ndhi
	end
	load ndd+16 as ndr
	ndi=0
	while ndi<ndr
		load ndd+48+ndi*8 as ndn
		load ndd+112+ndi*8 as nds
		ndx=(ndn-1)*nds
		slt ndx 0 as ndneg
		if ndneg
			ndlo+=ndx
		else
			ndhi+=ndx
		end
		ndi+=1
	end
	ret ndlo ndhi+8
end

# 1 if ndd is an array whose elements all lie in its storage, for 176
# bytes that no function of the library wrote
fn ndvalid ndd
	load ndd+8 as ndt
	ifz ndt
		ret 0
	end
	load ndd+16 as ndr
	if ndr>8
		ret 0
	end
	call ndcount ndr ndd+48 as ndn ndok
	ifz ndok
		ret 0
	end
	call ndspan ndd as ndlo ndhi
	load ndd+24 as ndp
	load ndd+32 as ndb
	if ndlo<ndp
		ret 0
	end
	if ndhi-ndp>ndb
		ret 0
	end
	ret 1
end

# read the elements of ndd as the kind ndk from now on, 1 doubles and 2
# integers, with their bits as they are: 1, or 0 for what is no array
# and for another kind
fn ndkind ndd ndk
	load ndd+8 as ndt
	ifz ndt
		ret 0
	end
	if ndk-1>1
		ret 0
	end
	store ndd+8 ndk
	ret 1
end

# lib/nd/reduce.aw -- sums and means of the elements of arrays; needs
# lib/nd/array.aw and lib/nd/elem.aw.
#
# ndsum and ndmean take an array and return a number and 1, or 0 and 0
# for what is no array. ndsumax and ndmeanax take a result first, as the
# functions of lib/nd/elem.aw do, then an array and one of its axes: the
# result has the lengths of the array without that axis, and each of
# its elements is the sum or the mean of the elements that differ only
# in the index of that axis. They return 1, or 0 for other lengths, for
# an axis the array has not got, for a result that shares storage with
# the array, and for what is no array; nothing is written then.
#
# A sum starts from 0 and adds the elements one after the other in the
# order of their indices, the last index fastest, and along an axis from
# the index 0 up. That is the order of a loop in C and not the one of
# NumPy, which adds in pairs: the last digits of a long sum may differ
# from NumPy's. ndsumpw adds in pairs, halves of halves down to runs of
# at most 128 elements. The sum of no element is 0 and the mean of none
# is 0 divided by 0, no number. What is no number stays none through a
# sum, an infinity stays one, and two infinities of both signs give no
# number, as fadd has it.

# the sum of the ndn elements from ndp on with the stride nds, added to
# nda one after the other
fn ndacc nda ndp ndn nds
	while ndn
		load ndp as ndx
		fadd nda ndx as nda
		ndp+=nds
		ndn-=1
	end
	ret nda
end

# the sum of the ndn elements from ndp on with the stride nds, in pairs
fn ndpair ndp ndn nds
	if ndn<=128
		tail ndacc 0 ndp ndn nds
	end
	ndm=ndn>>1
	call ndpair ndp ndm nds as ndx
	call ndpair ndp+ndm*nds ndn-ndm nds as ndy
	fadd ndx ndy as ndx
	ret ndx
end

# the sum of all elements of ndd, with ndk in pairs, and 1, or 0 and 0
fn ndtotal ndd ndk
	local ndw 384
	load ndd+8 as ndt
	ifz ndt
		ret 0 0
	end
	nda=0
	call ndsize ndd as ndn
	ifz ndn
		ret 0 1
	end
	call ndwalk ndw ndd
	call ndwarg ndw 0 ndd
	call ndcontig ndd as ndx
	if ndx
		store ndw 0
		store ndw+8 ndn
		store ndw+152 8
	end
	load ndw+8 as ndn
	load ndw+152 as nds
	ndgo=1
	while ndgo
		load ndw+144 as ndp
		if ndk
			call ndpair ndp ndn nds as ndx
			fadd nda ndx as nda
		else
			call ndacc nda ndp ndn nds as nda
		end
		call ndstep ndw as ndgo
	end
	ret nda 1
end

# the sum of all elements and 1, or 0 and 0 for what is no array
fn ndsum ndd
	tail ndtotal ndd 0
end
fn ndsumpw ndd
	tail ndtotal ndd 1
end

# their mean and 1, or 0 and 0
fn ndmean ndd
	call ndtotal ndd 0 as ndx ndok
	ifz ndok
		ret 0 0
	end
	call ndsize ndd as ndn
	itof ndn as ndn
	fdiv ndx ndn as ndx
	ret ndx 1
end

# make each element of ndo the sum of the elements of ndd along its axis
# ndax
fn ndsumax ndo ndd ndax
	local ndw 384
	local ndv 176
	load ndo+8 as ndt
	load ndd+8 as ndx
	ifz (ndt!=0)&(ndx!=0)
		ret 0
	end
	load ndd+16 as ndr
	load ndo+16 as ndq
	if ndax>=ndr
		ret 0
	end
	if ndq+1!=ndr
		ret 0
	end
	# the result with an axis of length 1 where the array has ndax
	ndi=0
	while ndi<22
		load ndo+ndi*8 as ndx
		store ndv+ndi*8 ndx
		ndi+=1
	end
	store ndv+16 ndr
	ndi=ndr-1
	while ndi>ndax
		load ndv+40+ndi*8 as ndx
		store ndv+48+ndi*8 ndx
		load ndv+104+ndi*8 as ndx
		store ndv+112+ndi*8 ndx
		ndi-=1
	end
	store ndv+48+ndax*8 1
	store ndv+112+ndax*8 0
	call ndwalk ndw ndd
	call ndwarg ndw 0 ndd
	call ndwarg ndw 1 ndv as ndx
	ifz ndx
		ret 0
	end
	# an array of one axis of length 1 gives a result that looks the same
	call ndspan ndo as ndlo ndhi
	call ndspan ndd as ndp ndq
	if (ndp<ndhi)&(ndlo<ndq)
		ret 0
	end
	call ndfill ndo 0
	call ndsize ndd as ndn
	ifz ndn
		ret 1
	end
	load ndw+8 as ndn
	load ndw+152 as nds
	load ndw+232 as ndt
	ndgo=1
	while ndgo
		load ndw+144 as ndp
		load ndw+224 as ndq
		if ndt
			ndi=ndn
			while ndi
				load ndp as ndx
				load ndq as ndy
				fadd ndy ndx as ndy
				store ndq ndy
				ndp+=nds
				ndq+=ndt
				ndi-=1
			end
		else
			load ndq as ndy
			call ndacc ndy ndp ndn nds as ndy
			store ndq ndy
		end
		call ndstep ndw as ndgo
	end
	ret 1
end

# make each element of ndo the mean of the elements of ndd along its
# axis ndax
fn ndmeanax ndo ndd ndax
	local ndk 176
	call ndsumax ndo ndd ndax as ndok
	ifz ndok
		ret 0
	end
	load ndd+48+ndax*8 as ndn
	itof ndn as ndn
	call ndscalar ndk ndn
	tail nddiv ndo ndo ndk
end

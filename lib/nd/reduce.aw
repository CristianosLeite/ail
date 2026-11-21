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
#
# Where doubles lie one behind the other and each is computed alone,
# in the sums of columns and in the product of matrices, two are
# computed at once (padd, pmadd), which gives the same bits. A sum of
# all elements and a dot product add each element to the one before:
# they stay one at a time, with the sum in a floating-point register
# for a whole run (fsum, fdot).
#
# nddot takes two arrays of one axis and the same length and returns the
# sum of the products of their elements and 1, or 0 and 0. ndmatmul takes
# a result and two arrays, all of two axes: n rows of m elements times m
# rows of l give n rows of l, each element the sum over k of the element
# i k of the first times the element k j of the second, added from 0 in
# the order of k. It returns 1, or 0 for other lengths, for a result
# that shares storage with one of the two, and for what is no array.
#
# Arrays of integers are summed and multiplied as integers, wrapping at
# 64 bits, and the result of ndsumax, nddot and ndmatmul is of the kind
# of what it is made of. A mean is always a double: of integers it is
# the sum of the elements as doubles, each as itof gives it, divided by
# their number, and the result of ndmeanax is an array of doubles.

# the sum of the ndn elements from ndp on with the stride nds, added to
# nda one after the other: with ndm 0 doubles, 1 integers, 2 integers
# as doubles
fn ndacc nda ndp ndn nds ndm
	if ndm==1
		while ndn
			load ndp as ndx
			nda+=ndx
			ndp+=nds
			ndn-=1
		end
		ret nda
	end
	if ndm
		while ndn
			load ndp as ndx
			itof ndx as ndx
			fadd nda ndx as nda
			ndp+=nds
			ndn-=1
		end
		ret nda
	end
	fsum nda ndp ndn nds as nda
	ret nda
end

# the sum of the ndn elements from ndp on with the stride nds, in pairs
fn ndpair ndp ndn nds ndm
	if ndn<=128
		tail ndacc 0 ndp ndn nds ndm
	end
	ndh=ndn>>1
	call ndpair ndp ndh nds ndm as ndx
	call ndpair ndp+ndh*nds ndn-ndh nds ndm as ndy
	if ndm==1
		ret ndx+ndy
	end
	fadd ndx ndy as ndx
	ret ndx
end

# the sum of all elements of ndd and 1, or 0 and 0: with ndk in pairs,
# with ndf integers as doubles
fn ndtotal ndd ndk ndf
	local ndw 384
	load ndd+8 as ndt
	ifz ndt
		ret 0 0
	end
	ndm=(ndt-1)*(1+ndf)
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
			call ndpair ndp ndn nds ndm as ndx
			if ndm==1
				nda+=ndx
			else
				fadd nda ndx as nda
			end
		else
			call ndacc nda ndp ndn nds ndm as nda
		end
		call ndstep ndw as ndgo
	end
	ret nda 1
end

# the sum of all elements and 1, or 0 and 0 for what is no array
fn ndsum ndd
	tail ndtotal ndd 0 0
end
fn ndsumpw ndd
	tail ndtotal ndd 1 0
end

# their mean, a double, and 1, or 0 and 0
fn ndmean ndd
	call ndtotal ndd 0 1 as ndx ndok
	ifz ndok
		ret 0 0
	end
	call ndsize ndd as ndn
	itof ndn as ndn
	fdiv ndx ndn as ndx
	ret ndx 1
end

# make each element of ndo the sum of the elements of ndd along its axis
# ndax; with ndf the result is of doubles whatever ndd is of
fn ndaxis ndo ndd ndax ndf
	local ndw 384
	local ndv 176
	load ndo+8 as ndt
	load ndd+8 as ndx
	ifz (ndt!=0)&(ndx!=0)
		ret 0
	end
	if ndt!=1+(ndx-1)*(1-ndf)
		ret 0
	end
	ndm=(ndx-1)*(1+ndf)
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
	# every other axis as long as that of the array: the walk would give
	# the one element of a shorter axis to every index
	ndi=0
	while ndi<ndr
		if ndi!=ndax
			load ndv+48+ndi*8 as ndx
			load ndd+48+ndi*8 as ndy
			if ndx!=ndy
				ret 0
			end
		end
		ndi+=1
	end
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
			if (ndm==0)&(nds==8)&(ndt==8)
				# doubles one behind the other on both sides, two at a
				# time
				nde=ndq+ndn*8
				ndf=nde-8
				ndu=ndp-ndq
				while ndq<ndf
					padd ndq ndq ndq+ndu
					ndq+=16
				end
				if ndq<nde
					load ndq+ndu as ndx
					load ndq as ndy
					fadd ndy ndx as ndy
					store ndq ndy
				end
			else
				ndi=ndn
				while ndi
					load ndp as ndx
					load ndq as ndy
					if ndm==1
						ndy+=ndx
					else
						if ndm
							itof ndx as ndx
						end
						fadd ndy ndx as ndy
					end
					store ndq ndy
					ndp+=nds
					ndq+=ndt
					ndi-=1
				end
			end
		else
			load ndq as ndy
			call ndacc ndy ndp ndn nds ndm as ndy
			store ndq ndy
		end
		call ndstep ndw as ndgo
	end
	ret 1
end
fn ndsumax ndo ndd ndax
	tail ndaxis ndo ndd ndax 0
end

# make each element of ndo, an array of doubles, the mean of the
# elements of ndd along its axis ndax
fn ndmeanax ndo ndd ndax
	local ndk 176
	call ndaxis ndo ndd ndax 1 as ndok
	ifz ndok
		ret 0
	end
	load ndd+48+ndax*8 as ndn
	itof ndn as ndn
	call ndscalar ndk ndn
	tail nddiv ndo ndo ndk
end

# the sum of the products of the elements of nda and ndb, two arrays of
# one axis, the same length and one kind, and 1, or 0 and 0
fn nddot nda ndb
	load nda+8 as ndm
	load ndb+8 as ndy
	ifz (ndm!=0)&(ndm==ndy)
		ret 0 0
	end
	ndm-=1
	load nda+16 as ndx
	load ndb+16 as ndy
	ifz (ndx==1)&(ndy==1)
		ret 0 0
	end
	load nda+48 as ndn
	load ndb+48 as ndx
	if ndn!=ndx
		ret 0 0
	end
	load nda as ndp
	load ndb as ndq
	load nda+112 as nds
	load ndb+112 as ndt
	ndz=0
	if (nds==8)&(ndt==8)
		nde=ndp+ndn*8
		ndu=ndq-ndp
		if ndm
			while ndp<nde
				load ndp as ndx
				load ndp+ndu as ndy
				ndz+=ndx*ndy
				ndp+=8
			end
			ret ndz 1
		end
		fdot 0 ndp ndq ndn as ndz
		ret ndz 1
	end
	while ndn
		load ndp as ndx
		load ndq as ndy
		if ndm
			ndz+=ndx*ndy
		else
			fmul ndx ndy as ndx
			fadd ndz ndx as ndz
		end
		ndp+=nds
		ndq+=ndt
		ndn-=1
	end
	ret ndz 1
end

# add ndx times each of the ndn elements from ndq on, with the stride
# ndt, to the elements from ndp on, with the stride nds; integers if ndm.
# Doubles one behind the other go two at a time, four such pairs a
# round, with ndx twice in ndkk
fn ndaxpy ndp ndn nds ndx ndq ndt ndm
	local ndkk 16
	# no element: the end less 8 would lie before the start, and at an
	# address below 8 behind every address
	ifz ndn
		ret 0
	end
	if (nds==8)&(ndt==8)
		nde=ndp+ndn*8
		ndu=ndq-ndp
		if ndm
			while ndp<nde
				load ndp+ndu as ndy
				load ndp as ndz
				store ndp ndz+ndx*ndy
				ndp+=8
			end
			ret 0
		end
		store ndkk ndx
		store ndkk+8 ndx
		# eight doubles a round while there are eight, then two, then one
		if ndn>=8
			ndf=nde-56
			while ndp<ndf
				pmadd ndp ndp+ndu ndkk
				pmadd ndp+16 ndp+ndu+16 ndkk
				pmadd ndp+32 ndp+ndu+32 ndkk
				pmadd ndp+48 ndp+ndu+48 ndkk
				ndp+=64
			end
		end
		ndf=nde-8
		while ndp<ndf
			pmadd ndp ndp+ndu ndkk
			ndp+=16
		end
		while ndp<nde
			load ndp+ndu as ndy
			load ndp as ndz
			fmul ndx ndy as ndy
			fadd ndz ndy as ndz
			store ndp ndz
			ndp+=8
		end
		ret 0
	end
	while ndn
		load ndq as ndy
		load ndp as ndz
		if ndm
			ndz+=ndx*ndy
		else
			fmul ndx ndy as ndy
			fadd ndz ndy as ndz
		end
		store ndp ndz
		ndp+=nds
		ndq+=ndt
		ndn-=1
	end
	ret 0
end

# 1 if ndo may be made the product of the matrices nda and ndb: three
# arrays of one kind and two axes, lengths that go together, and a
# result apart from both
fn ndmmok ndo nda ndb
	load ndo+8 as ndf
	load nda+8 as ndx
	load ndb+8 as ndy
	ifz (ndf!=0)&(ndx==ndf)&(ndy==ndf)
		ret 0
	end
	load ndo+16 as ndt
	load nda+16 as ndx
	load ndb+16 as ndy
	ifz (ndt==2)&(ndx==2)&(ndy==2)
		ret 0
	end
	load nda+48 as ndn
	load nda+56 as ndm
	load ndb+56 as ndl
	load ndb+48 as ndx
	load ndo+48 as ndy
	load ndo+56 as ndt
	ifz (ndx==ndm)&(ndy==ndn)&(ndt==ndl)
		ret 0
	end
	load ndo+112 as ndso
	load ndo+120 as ndsp
	# two elements of the result at one address
	if (ndn>1)&(ndso==0)|((ndl>1)&(ndsp==0))
		ret 0
	end
	# two elements that share some of their 8 bytes: a stride that is no
	# multiple of 8, on an axis with more than one element. With
	# multiples, elements at two addresses are 8 bytes apart or more
	if (ndn>1)&((ndso&7)!=0)|((ndl>1)&((ndsp&7)!=0))
		ret 0
	end
	# and where some steps along one axis are some along the other: the
	# fewest are each stride divided by what divides both
	if (ndn>1)&(ndl>1)
		ifslt ndso 0
			ndso=0-ndso
		end
		ifslt ndsp 0
			ndsp=0-ndsp
		end
		ndu=ndso
		ndv=ndsp
		while ndv
			ndg=ndu%ndv
			ndu=ndv
			ndv=ndg
		end
		if (ndsp/ndu<ndn)&(ndso/ndu<ndl)
			ret 0
		end
	end
	call ndspan ndo as ndlo ndhi
	call ndspan nda as ndp ndq
	if (ndp<ndhi)&(ndlo<ndq)
		ret 0
	end
	call ndspan ndb as ndp ndq
	if (ndp<ndhi)&(ndlo<ndq)
		ret 0
	end
	ret 1
end

# add to the rows ndlo up to but not ndhi of ndo those of the product of
# nda and ndb, which ndmmok has allowed; 1
fn ndrows ndo nda ndb ndlo ndhi
	load ndo+8 as ndf
	ndf-=1
	load nda+56 as ndm
	load ndb+56 as ndl
	load ndo+112 as ndso
	load ndo+120 as ndsp
	load nda+112 as ndsa
	load nda+120 as ndsk
	load ndb+112 as ndsb
	load ndb+120 as ndsj
	load ndo as ndp
	load nda as ndq
	ndp+=ndlo*ndso
	ndq+=ndlo*ndsa
	ndi=ndlo
	while ndi<ndhi
		load ndb as ndr
		ndu=ndq
		ndk=0
		while ndk<ndm
			load ndu as ndx
			call ndaxpy ndp ndl ndsp ndx ndr ndsj ndf
			ndu+=ndsk
			ndr+=ndsb
			ndk+=1
		end
		ndp+=ndso
		ndq+=ndsa
		ndi+=1
	end
	ret 1
end

# make ndo the product of the matrices nda and ndb
fn ndmatmul ndo nda ndb
	call ndmmok ndo nda ndb as ndok
	ifz ndok
		ret 0
	end
	call ndfill ndo 0
	load ndo+48 as ndn
	tail ndrows ndo nda ndb 0 ndn
end

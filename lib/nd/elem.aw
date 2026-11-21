# lib/nd/elem.aw -- arithmetic on the elements of arrays; needs
# lib/nd/array.aw.
#
# ndadd, ndsub, ndmul and nddiv take three arrays, the result first: each
# element of the result is made of the elements of the two others at the
# same indices. The result is an array the caller made, so the same
# storage serves one operation after another, and its lengths say what
# is computed. An array with fewer axes than the result has its axes
# matched with the last ones of the result, and an axis of length 1
# gives its one element to every index of that axis; ndscalar makes an
# array of one number, without axes, that goes with every result. Any
# other difference in a length is refused. ndput copies the elements of
# one array to another by the same rules.
#
# The result may be one of the two others, the same elements under the
# same indices: each element is then read before it is written. Storage
# that the result shares with another array in any other way is
# refused, also where no element of the two is the same, since only the
# lowest and the highest address of each are compared; a result with a
# stride of 0 on an axis longer than 1, whose elements would be one, is
# refused too. All return 1, or 0 for what is refused, and then no
# element was written. Nothing is allocated.
#
# The elements are doubles: a division by zero gives an infinity or what
# is no number, as fdiv does.

# make ndd an array without axes whose one element is ndx, kept in the
# 176 bytes themselves
fn ndscalar ndd ndx
	ndi=0
	while ndi<22
		store ndd+ndi*8 0
		ndi+=1
	end
	store ndd ndd+48
	store ndd+8 1
	store ndd+24 ndd+48
	store ndd+32 8
	store ndd+48 ndx
end

# 1 if the arrays nda and ndb are the same elements under the same
# indices
fn ndsame nda ndb
	load nda as ndx
	load ndb as ndy
	if ndx!=ndy
		ret 0
	end
	load nda+16 as ndr
	load ndb+16 as ndy
	if ndr!=ndy
		ret 0
	end
	ndi=0
	while ndi<ndr
		load nda+48+ndi*8 as ndx
		load ndb+48+ndi*8 as ndy
		if ndx!=ndy
			ret 0
		end
		load nda+112+ndi*8 as ndx
		load ndb+112+ndi*8 as ndy
		if ndx!=ndy
			ret 0
		end
		ndi+=1
	end
	ret 1
end

# 1 if the array nda may not be read while ndo is written: they share
# addresses and are not the same
fn ndclash ndo nda
	call ndspan ndo as ndlo ndhi
	call ndspan nda as ndp ndq
	if ndp>=ndhi
		ret 0
	end
	if ndlo>=ndq
		ret 0
	end
	call ndsame ndo nda as ndx
	ret 1-ndx
end

# how the array nda goes along a result of ndn elements that lie one
# behind the other: 0 with its one element, 8 with as many that lie so
# too, and 1 if it does neither
fn ndflat nda ndn
	call ndsize nda as ndm
	if ndm==1
		ret 0
	end
	if ndm!=ndn
		ret 1
	end
	call ndcontig nda as ndx
	ret 1+ndx*7
end

# the operation ndk on a run of ndn elements: the result at ndp with the
# stride ndso, the others at ndq and ndr with ndsa and ndsb
fn ndrun ndk ndn ndp ndso ndq ndsa ndr ndsb
	if (ndso==8)&(ndsa==8)&(ndsb==8)
		# all three one behind the other: an end and two distances
		ndn=ndp+ndn*8
		ndq-=ndp
		ndr-=ndp
		if ndk==0
			while ndp<ndn
				load ndp+ndq as ndx
				load ndp+ndr as ndy
				fadd ndx ndy as ndx
				store ndp ndx
				ndp+=8
			end
			ret 0
		end
		if ndk==1
			while ndp<ndn
				load ndp+ndq as ndx
				load ndp+ndr as ndy
				fsub ndx ndy as ndx
				store ndp ndx
				ndp+=8
			end
			ret 0
		end
		if ndk==2
			while ndp<ndn
				load ndp+ndq as ndx
				load ndp+ndr as ndy
				fmul ndx ndy as ndx
				store ndp ndx
				ndp+=8
			end
			ret 0
		end
		if ndk==3
			while ndp<ndn
				load ndp+ndq as ndx
				load ndp+ndr as ndy
				fdiv ndx ndy as ndx
				store ndp ndx
				ndp+=8
			end
			ret 0
		end
		while ndp<ndn
			load ndp+ndq as ndx
			store ndp ndx
			ndp+=8
		end
		ret 0
	end
	while ndn
		load ndq as ndx
		load ndr as ndy
		if ndk==0
			fadd ndx ndy as ndx
		end
		if ndk==1
			fsub ndx ndy as ndx
		end
		if ndk==2
			fmul ndx ndy as ndx
		end
		if ndk==3
			fdiv ndx ndy as ndx
		end
		store ndp ndx
		ndp+=ndso
		ndq+=ndsa
		ndr+=ndsb
		ndn-=1
	end
	ret 0
end

# make each element of ndo the result of the operation ndk on the
# elements of nda and ndb: 0 add, 1 subtract, 2 multiply, 3 divide,
# 4 the element of nda
fn ndelem ndo nda ndb ndk
	local ndw 384
	load ndo+8 as ndt
	load nda+8 as ndx
	load ndb+8 as ndy
	ifz (ndt!=0)&(ndx!=0)&(ndy!=0)
		ret 0
	end
	# two elements of the result at one address
	load ndo+16 as ndr
	ndi=0
	while ndi<ndr
		load ndo+48+ndi*8 as ndn
		load ndo+112+ndi*8 as nds
		if (ndn>1)&(nds==0)
			ret 0
		end
		ndi+=1
	end
	call ndwalk ndw ndo
	call ndwarg ndw 0 ndo
	call ndwarg ndw 1 nda as ndx
	call ndwarg ndw 2 ndb as ndy
	ifz ndx&ndy
		ret 0
	end
	call ndclash ndo nda as ndx
	call ndclash ndo ndb as ndy
	if ndx|ndy
		ret 0
	end
	call ndsize ndo as ndn
	ifz ndn
		ret 1
	end
	# everything one behind the other is one run
	call ndcontig ndo as ndx
	if ndx
		call ndflat nda ndn as ndx
		call ndflat ndb ndn as ndy
		if (ndx!=1)&(ndy!=1)
			store ndw 0
			store ndw+8 ndn
			store ndw+152 8
			store ndw+232 ndx
			store ndw+312 ndy
		end
	end
	load ndw+8 as ndn
	load ndw+152 as nds
	load ndw+232 as ndx
	load ndw+312 as ndy
	ndgo=1
	while ndgo
		load ndw+144 as ndp
		load ndw+224 as ndq
		load ndw+304 as ndr
		call ndrun ndk ndn ndp nds ndq ndx ndr ndy
		call ndstep ndw as ndgo
	end
	ret 1
end

# ndo = nda + ndb, nda - ndb, nda * ndb, nda / ndb, element by element
fn ndadd ndo nda ndb
	tail ndelem ndo nda ndb 0
end
fn ndsub ndo nda ndb
	tail ndelem ndo nda ndb 1
end
fn ndmul ndo nda ndb
	tail ndelem ndo nda ndb 2
end
fn nddiv ndo nda ndb
	tail ndelem ndo nda ndb 3
end

# ndo = nda, element by element
fn ndput ndo nda
	tail ndelem ndo nda nda 4
end

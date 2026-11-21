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
# The three arrays are of one kind. Doubles are computed as fadd, fsub,
# fmul and fdiv do: a division by zero gives an infinity or what is no
# number. Integers wrap at 64 bits, as everywhere in the language; their
# quotient has a sign and is cut off towards 0, a divisor that has a 0
# among its elements is refused before anything is written, and the
# lowest integer divided by -1, which does not fit, stays what it is.
# ndtoi and ndtof are the only functions between the kinds: the result
# is an array of integers made of one of doubles, as ftoi does, or one
# of doubles made of integers, as itof does.

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

# 1 if an element of ndd is 0
fn ndhas0 ndd
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
			load ndp as ndx
			ifz ndx
				ret 1
			end
			ndp+=nds
			ndi-=1
		end
		call ndstep ndw as ndgo
	end
	ret 0
end

# the operation ndk on a run of ndn elements: the result at ndp with the
# stride ndso, the others at ndq and ndr with ndsa and ndsb. 0 to 3 are
# sum, difference, product and quotient of doubles and 8 to 11 those of
# integers, 4 copies, 5 makes an integer of a double and 6 a double of
# an integer
fn ndrun ndk ndn ndp ndso ndq ndsa ndr ndsb
	if ndso==8
		# the result one behind the other: an end, and for each of the
		# two others a distance, or its one element
		nde=ndp+ndn*8
		ndu=ndq-ndp
		ndv=ndr-ndp
		if (ndsa==8)&(ndsb==8)
			if ndk==0
				while ndp<nde
					load ndp+ndu as ndx
					load ndp+ndv as ndy
					fadd ndx ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==1
				while ndp<nde
					load ndp+ndu as ndx
					load ndp+ndv as ndy
					fsub ndx ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==2
				while ndp<nde
					load ndp+ndu as ndx
					load ndp+ndv as ndy
					fmul ndx ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==3
				while ndp<nde
					load ndp+ndu as ndx
					load ndp+ndv as ndy
					fdiv ndx ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==8
				while ndp<nde
					load ndp+ndu as ndx
					load ndp+ndv as ndy
					ndx=ndx+ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==9
				while ndp<nde
					load ndp+ndu as ndx
					load ndp+ndv as ndy
					ndx=ndx-ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==10
				while ndp<nde
					load ndp+ndu as ndx
					load ndp+ndv as ndy
					ndx=ndx*ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==4
				while ndp<nde
					load ndp+ndu as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
		end
		if (ndsa==8)&(ndsb==0)
			load ndr as ndy
			if ndk==0
				while ndp<nde
					load ndp+ndu as ndx
					fadd ndx ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==1
				while ndp<nde
					load ndp+ndu as ndx
					fsub ndx ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==2
				while ndp<nde
					load ndp+ndu as ndx
					fmul ndx ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==3
				while ndp<nde
					load ndp+ndu as ndx
					fdiv ndx ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==8
				while ndp<nde
					load ndp+ndu as ndx
					ndx=ndx+ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==9
				while ndp<nde
					load ndp+ndu as ndx
					ndx=ndx-ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==10
				while ndp<nde
					load ndp+ndu as ndx
					ndx=ndx*ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
		end
		if (ndsa==0)&(ndsb==8)
			load ndq as ndz
			if ndk==0
				while ndp<nde
					load ndp+ndv as ndy
					fadd ndz ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==1
				while ndp<nde
					load ndp+ndv as ndy
					fsub ndz ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==2
				while ndp<nde
					load ndp+ndv as ndy
					fmul ndz ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==3
				while ndp<nde
					load ndp+ndv as ndy
					fdiv ndz ndy as ndx
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==8
				while ndp<nde
					load ndp+ndv as ndy
					ndx=ndz+ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==9
				while ndp<nde
					load ndp+ndv as ndy
					ndx=ndz-ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
			if ndk==10
				while ndp<nde
					load ndp+ndv as ndy
					ndx=ndz*ndy
					store ndp ndx
					ndp+=8
				end
				ret 0
			end
		end
		if (ndsa==0)&(ndk==4)
			load ndq as ndx
			while ndp<nde
				store ndp ndx
				ndp+=8
			end
			ret 0
		end
	end
	if ndk<4
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
	if ndk<8
		while ndn
			load ndq as ndx
			if ndk==5
				ftoi ndx as ndx
			end
			if ndk==6
				itof ndx as ndx
			end
			store ndp ndx
			ndp+=ndso
			ndq+=ndsa
			ndn-=1
		end
		ret 0
	end
	while ndn
		load ndq as ndx
		load ndr as ndy
		if ndk==8
			ndx+=ndy
		end
		if ndk==9
			ndx-=ndy
		end
		if ndk==10
			ndx*=ndy
		end
		if ndk==11
			# the lowest integer by -1 does not fit and stays what it is
			if ndy+1
				sdiv ndx ndy as ndx
			else
				ndx=0-ndx
			end
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
# 4 the element of nda, 5 that as an integer, 6 that as a double
fn ndelem ndo nda ndb ndk
	local ndw 384
	load ndo+8 as ndt
	load nda+8 as ndx
	load ndb+8 as ndy
	ifz (ndt!=0)&(ndx!=0)&(ndy!=0)
		ret 0
	end
	if ndk<5
		ifz (ndt==ndx)&(ndt==ndy)
			ret 0
		end
		if (ndt==2)&(ndk<4)
			ndk+=8
		end
	else
		ifz (ndt==7-ndk)&(ndx==ndk-4)
			ret 0
		end
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
	# an integer is not divided by 0
	if ndk==11
		call ndhas0 ndb as ndx
		if ndx
			ret 0
		end
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

# ndo = nda as integers, each double cut off towards 0, and ndo = nda as
# doubles
fn ndtoi ndo nda
	tail ndelem ndo nda nda 5
end
fn ndtof ndo nda
	tail ndelem ndo nda nda 6
end

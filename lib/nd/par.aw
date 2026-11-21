# lib/nd/par.aw -- the product of matrices in tasks; needs lib/task.aw
# and the three files lib/nd/array.aw, elem.aw and reduce.aw.
#
# ndmatmulp is ndmatmul with a number of tasks: the rows of the result
# are cut into that many runs, as equal as they come, and each run is a
# task of lib/task.aw that computes its rows, which no other task
# touches. The result is the same bits as that of ndmatmul, and what is
# refused is the same. At most 64 tasks are made, and no more than there
# are rows; with 0 or 1 the rows are computed here. How many threads
# run the tasks is the limit of the pool ("call workers n"); the thread
# that calls runs tasks too while it waits for them. A task that there
# is no memory for is computed here, so the function does not fail for
# that.
#
# The three arrays must be there until the function returns, which is
# when every task has ended.

# make ndo the product of the matrices nda and ndb in ndt tasks
fn ndmatmulp ndo nda ndb ndt
	local ndh 512
	call ndmmok ndo nda ndb as ndok
	ifz ndok
		ret 0
	end
	call ndfill ndo 0
	load ndo+48 as ndn
	if ndt>64
		ndt=64
	end
	if ndt>ndn
		ndt=ndn
	end
	if ndt<2
		tail ndrows ndo nda ndb 0 ndn
	end
	ndc=(ndn+ndt-1)/ndt
	ndi=0
	ndlo=0
	while ndlo<ndn
		ndhi=ndlo+ndc
		if ndhi>ndn
			ndhi=ndn
		end
		spawn ndrows ndo nda ndb ndlo ndhi as ndx
		ifz ndx
			call ndrows ndo nda ndb ndlo ndhi
		end
		store ndh+ndi*8 ndx
		ndi+=1
		ndlo=ndhi
	end
	while ndi
		ndi-=1
		load ndh+ndi*8 as ndx
		join ndx as ndy
	end
	ret 1
end

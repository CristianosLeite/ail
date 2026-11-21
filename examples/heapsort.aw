# heapsort: sort the n words at a in place. The words are made a heap
# with the largest first, each at i with its two at 2i+1 and 2i+2 not
# larger; then the first changes places with the last of the heap, which
# is one shorter each time.
use "bench/algo/harness.aw"

# put v where the word i of the heap of n words is, and move it down
fn sift a i n v
	c=i*2+1
	while c<n
		load a+c*8 as x
		if c+1<n
			load a+c*8+8 as y
			if y>x
				x=y
				c+=1
			end
		end
		jle x v put
		store a+i*8 x
		i=c
		c=i*2+1
	end
	label put
	store a+i*8 v
end
fn heapsort a n
	i=n>>1
	while i
		i-=1
		load a+i*8 as v
		call sift a i n v
	end
	while n>1
		n-=1
		load a+n*8 as v
		load a as x
		store a+n*8 x
		call sift a 0 n v
	end
end
ref heapsort as k
call algosort k

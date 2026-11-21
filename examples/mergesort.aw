# mergesort: sort the n words at a, with the n words at t to work in.
# From the bottom up: runs of 1, 2, 4, ... words are merged in pairs from
# one array into the other, and the two change places after each pass.
# Of two equal words the one that came first stays first.
use "bench/algo/harness.aw"
fn mergesort a n t
	e=n*8
	w=8
	s=a
	d=t
	while w<e
		o=0
		while o<e
			m=o+w
			if m>e
				m=e
			end
			h=m+w
			if h>e
				h=e
			end
			i=s+o
			p=s+m
			j=p
			q=s+h
			k=d+o
			while (i<p)&(j<q)
				load i as u
				load j as v
				if v<u
					store k v
					j+=8
				else
					store k u
					i+=8
				end
				k+=8
			end
			while i<p
				load i as u
				store k u
				i+=8
				k+=8
			end
			while j<q
				load j as v
				store k v
				j+=8
				k+=8
			end
			o=h
		end
		x=s
		s=d
		d=x
		w*=2
	end
	if s!=a
		i=0
		while i<e
			load s+i as u
			store a+i u
			i+=8
		end
	end
end
ref mergesort as k
call algosort k

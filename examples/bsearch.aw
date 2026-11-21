# bsearch: binary search in the n words at a, which rise. lower gives
# the first index whose word is at least k, or n if every word is
# smaller; search does that for each of n keys.
use "bench/algo/harness.aw"
fn lower a n k
	l=0
	while l<n
		m=l+n>>1
		load a+m*8 as v
		if v<k
			l=m+1
		else
			n=m
		end
	end
	ret l
end
fn search a n q r
	i=0
	while i<n
		load q+i*8 as k
		call lower a n k as l
		store r+i*8 l
		i+=1
	end
end
ref search as k
call algosearch k

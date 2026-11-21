# hashtab: a hash table with open addressing. A place is 16 bytes, a key
# and its value, and the key 0 is a place that is free; the table has a
# power of two of them, m being that less one. A key goes to the place
# its hash names or to the next that is free, round the end.
use "bench/algo/harness.aw"

# where the key k is in the table t, or the free place where it goes
fn place t m k
	h=k*0x9e3779b97f4a7c15>>32&m
	load t+h*16 as x
	while (x!=0)&(x!=k)
		h=h+1&m
		load t+h*16 as x
	end
	ret t+h*16
end

# give each of the n keys at q its index as value
fn insert t m q n
	i=0
	while i<n
		load q+i*8 as k
		call place t m k as p
		store p k
		store p+8 i
		i+=1
	end
end

# write to r the value of each of the n keys at q, or -1
fn lookup t m q n r
	i=0
	while i<n
		load q+i*8 as k
		call place t m k as p
		load p as x
		v=-1
		if x
			load p+8 as v
		end
		store r+i*8 v
		i+=1
	end
end
ref insert as a
ref lookup as b
call algohash a b b

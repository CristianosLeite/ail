# the four sorts of lib/algo/sort.aw give the words in the unsigned
# order, the same words, and leave the words before and behind alone:
# for no word, one, two, three, 17 and 1000 words that are random,
# rising, falling (and above 2^63), all the same, few and of all 64 bits
use "lib/io.aw"
use "lib/algo/sort.aw"
const guard 0x5a5a5a5a5a5a5a5a
buf in 8000
buf w 8016
buf t 8016
# fill n words at in by the kind k
fn fill n k
	x=k*0x9e3779b97f4a7c15+1
	i=0
	while i<n
		x=x*0x5851f42d4c957f2d+0x14057b7ef767814f
		v=x>>33
		if k==1
			v=i
		end
		if k==2
			v=0-i
		end
		if k==3
			v=7
		end
		if k==4
			v=x>>61
		end
		if k==5
			v=x
		end
		store in+i*8 v
		i+=1
	end
end
# sort a copy of the n words at in the way s; 0 if all is well
fn one s n
	p=w+8
	store w guard
	store p+n*8 guard
	store t guard
	store t+8+n*8 guard
	i=0
	while i<n
		load in+i*8 as v
		store p+i*8 v
		i+=1
	end
	if s==0
		call sortquick p p+n*8
	end
	if s==1
		call sortmerge p n t+8
	end
	if s==2
		call sortheap p n
	end
	if s==3
		call sortins p n
	end
	e=0
	d=0
	u=0
	i=0
	while i<n
		load p+i*8 as v
		load in+i*8 as x
		d+=v-x
		u^=v^x
		if i
			load p+i*8-8 as y
			if y>v
				e=1
			end
		end
		i+=1
	end
	load w as a
	load p+n*8 as b
	load t as c
	load t+8+n*8 as f
	ret e+(d!=0)+(u!=0)+(a!=guard)+(b!=guard)+(c!=guard)+(f!=guard)
end
# every kind for n words, each way
fn count n
	k=0
	while k<6
		call fill n k
		s=0
		while s<4
			call one s n as r
			call putn r
			s+=1
		end
		k+=1
	end
	call print " "
end
call count 0
call count 1
call count 2
call count 3
call count 17
call count 1000
# the words are in the unsigned order: of 0 and the 999 numbers below
# 2^64 the first is 0 and the last 2^64-1 (printed are 999 more than
# the first, and the last)
call fill 1000 2
call one 2 1000 as r
load w+8 as a
load w+8000 as b
call putn a+999
call putn b
call print "\n"

# infinities and what is no number go through the kernels as IEEE 754
# has it: one of them in a sum is the sum, two infinities of both signs
# are no number, and only the row or column that has one is touched
use "lib/std/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
const inf 0x7ff0000000000000
const ninf 0xfff0000000000000
const nonum 0x7ff8000000000000
buf a 176
buf b 176
buf c 176
buf w 176
buf ix 16
# 0 a number, 1 an infinity, 2 minus infinity, 3 no number
fn class x
	if x==inf
		ret 1
	end
	if x==ninf
		ret 2
	end
	ret (x<<1>>53==0x7ff)*3
end
fn classes d
	call ndsize d as n
	load d as p
	i=0
	while i<n
		load p+i*8 as x
		call class x as c
		call putn c
		i+=1
	end
	call print " "
end
call ndmat a 3 3 as r
call ndmat b 3 3 as r
call ndvec c 3 as r
call ndvec w 3 as r
itof 1 as x
call ndfill a x
call ndfill b x
# a: inf in row 0, -inf in row 1, both in column 2; no number at 2 0
store ix 0
store ix+8 2
call ndset a ix inf as s
store ix 1
call ndset a ix ninf as s
store ix 2
store ix+8 0
call ndset a ix nonum as s
call ndsum a as x t
call class x as y
call putn y
call ndmean a as x t
call class x as y
call putn y
call ndsumpw a as x t
call class x as y
call putn y
call print " "
call ndsumax c a 0 as u
call classes c
call ndsumax w a 1 as u
call classes w
call ndmeanax w a 1 as u
call classes w
# inf - inf, inf * 0, inf / inf, 1 / inf, x + nan
call ndsub b a a as v
call classes b
call ndfill b 0
call ndmul b a b as v
call classes b
call nddiv b a a as v
call classes b
itof 1 as o
call ndfill b o
call nddiv b b a as v
call classes b
load b as p
load p+16 as z
load p+40 as e
call putn z==0
call putn e==0x8000000000000000
call print "\n"
call ndfree a
call ndfree b
call ndfree c
call ndfree w
sys exit r+s+t+u+v

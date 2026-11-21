# no element: the sum is 0 and the mean no number; along an axis of
# length 0 every sum is 0 and every mean no number, and along another
# axis there is no result to write
use "lib/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
buf a 176
buf c 176
buf w 176
# 1 if the double x is no number
fn nan x
	ret (x<<1>>53==0x7ff)&(x<<12!=0)
end
call ndmat a 0 3 as r
call ndvec c 3 as r
call ndvec w 0 as r
itof 7 as x
call ndfill c x
call ndsum a as x s
call putn x==0
call ndsumpw a as x t
call putn x==0
call ndmean a as x u
call nan x as y
call putn y
call ndsumax c a 0 as b
load c as p
load p as x
load p+16 as y
call putn (x==0)&(y==0)
call ndmeanax c a 0 as d
load p as x
call nan x as y
load p+16 as x
call nan x as z
call putn y+z
call ndsumax w a 1 as e
call ndmeanax w a 1 as f
call ndsize w as n
call putn n
call print "\n"
call ndfree a
call ndfree c
call ndfree w
sys exit r+s+t+u+b+d+e+f

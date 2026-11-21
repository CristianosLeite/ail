# fdot adds to a start the products of the doubles of two runs, each
# product rounded and then added, in the order of the runs: what a loop
# of fmul and fadd gives
buf a 56
buf b 56
fn slow s p q n
	while n
		load p as x
		load q as y
		fmul x y as x
		fadd s x as s
		p+=8
		q+=8
		n-=1
	end
	ret s
end
fn dots s p q n v1 v2 v3 v4 v5
	fdot s p q n as x
	call slow s p q n as y
	fdot s+v1-v1 p+v2-v2 q+v3-v3 n+v4-v4 as z
	ret (x==y)+(z==y)+v5
end
# 0.1 times 1 to 7, and 1/1 to 1/7
itof 10 as t
i=0
while i<7
	itof i+1 as x
	fdiv x t as y
	store a+i*8 y
	itof 1 as y
	fdiv y x as y
	store b+i*8 y
	i+=1
end
# 1.5 times 4 and 2.25 times 0.5 after 10: 17.125
store a 0x3ff8000000000000
store a+8 0x4002000000000000
store b 0x4010000000000000
store b+8 0x3fe0000000000000
fdot 0x4024000000000000 a b 2 as x
r=x==0x4031200000000000
# a product that is not rounded before it is added would give another
# sum: (1+2^-30)^2 less 1
store a 0x3ff0000000400000
fdot 0xbff0000000000000 a a 1 as x
r+=x==0x3e20000000000000
fdot 0x4000000000000000 a b 0 as x
r+=x==0x4000000000000000
call dots 0 a b 7 1 2 3 4 0 as x
call dots 0x3ff0000000000000 a a 7 1 2 3 4 0 as y
sys exit r+x+y

# fsum adds doubles of a run to a start, one after the other, as a loop
# of fadd does: 1e16 and three times 1 stay 1e16, where 1e16 added last
# gives more. The stride is in bytes and may be negative or 0, and no
# element gives the start.
buf a 64
buf b 16
fn slow s p n d
	while n
		load p as x
		fadd s x as s
		p+=d
		n-=1
	end
	ret s
end
fn sums s p n d v1 v2 v3 v4 v5
	# more variables than registers, the operands as expressions
	fsum s p n d as x
	call slow s p n d as y
	fsum s+v1-v1 p+v2-v2 n+v3-v3 d+v4-v4 as z
	ret (x==y)+(z==y)+v5
end
store a 0x4341c37937e08000
i=1
while i<4
	store a+i*8 0x3ff0000000000000
	i+=1
end
# 0.1, 0.2, 0.3 and no number behind them
store a+32 0x3fb999999999999a
store a+40 0x3fc999999999999a
store a+48 0x3fd3333333333333
store a+56 0x7ff8000000000000
fsum 0 a 4 8 as x
r=x==0x4341c37937e08000
fsum 0 a+24 4 -8 as x
r+=x==0x4341c37937e08002
# 0.1+0.2+0.3 is not 0.3+0.2+0.1
fsum 0 a+32 3 8 as x
fsum 0 a+48 3 -8 as y
r+=(x==0x3fe3333333333334)+(y==0x3fe3333333333333)
# every other element, one element five times, none
fsum 0 a+32 2 16 as x
fsum 0 a+8 5 0 as y
fsum 0x4000000000000000 a 0 8 as z
r+=(x==0x3fd999999999999a)+(y==0x4014000000000000)+(z==0x4000000000000000)
# no number stays none
fsum 0 a+32 4 8 as x
r+=x>>51==0xfff
call sums 0 a 7 8 1 2 3 4 0 as x
call sums 0x3ff0000000000000 a+48 7 -8 1 2 3 4 0 as y
sys exit r+x+y

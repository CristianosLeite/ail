# and of a call through an address, whose address is in the register that shifts use
fn f a b c d e
	ret a+b*2+c*3+d*4+e*5
end
ref f as p
x=1
y=2
callp p x y<<x x+y 32>>y*2-1 20/(y+y) as r
jne r 59 bad
sys exit 0
label bad
sys exit 1

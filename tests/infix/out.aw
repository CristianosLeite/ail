# a source for tests/infix.sh: every rewrite of tools/infix.aw, and what
# it must leave alone
var g
buf b 64
fn f a b
u=(a+b)*2
u-=a                # a comment keeps its line
ret u
end
i=0
s=0
while i<8
p=b+i*8
store p i
load p as v
s+=v
if v<3
s+=1
else
s>>=0
end
i+=1
end
k=5
label down
k-=1
jnz k down
g=s+k
q=s/2
r=s%2
sys write 1 "x" as w
sdiv q+r+w 2 as q
jslt q 0 neg
call f q 3 as z
sys exit z-q
label neg
sys exit 1

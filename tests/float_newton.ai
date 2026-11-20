# the cube root of 27 by Newton's method: x = x - (x*x*x - 27) / (3*x*x)
itof 27 as n
itof 3 as three
itof 10 as x
set 40 as k
label top
fmul x x as xx
fmul xx x as xxx
fsub xxx n as d
fmul three xx as s
fdiv d s as d
fsub x d as x
sub k 1 as k
jnz k top
itof 1000 as m
fmul x m as x
ftoi x as i
sub i 2990 as i
sys exit i

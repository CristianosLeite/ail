# signed division rounds toward zero and the remainder has the sign of the
# dividend: -7 / 2 = -3 remainder -1
sdiv -7 2 as q
smod -7 2 as r
add q 3 as q
add r 1 as r
or q r as x
sdiv 7 -2 as q
smod 7 -2 as r
add q 3 as q
sub r 1 as r
or x q as x
or x r as x
sdiv -8 -2 as q
sub q 4 as q
or x q as x
add x 5 as x
sys 60 x

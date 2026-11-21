# -16 shifted right by 2 is -4 with sar, a large number with shr
sar -16 2 as a
eq a -4 as x
sar 16 2 as b
eq b 4 as y
shr -16 2 as c
ne c -4 as z
add x y as x
add x z as x
sys 60 x

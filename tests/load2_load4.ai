# 16- and 32-bit loads, zero-extended
buf b 8
store b 0x8877665544332211
load2 b as x
load4 b as y
shr x 8 as x
shr y 24 as y
add x y as x
sys 60 x

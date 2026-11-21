buf b 8
store b -1
load4 b as y
shr y 32 as y
load2 b as x
shr x 16 as x
add x y as x
sys 60 x

buf b 8
store4 b 0x1122334455
load b as x
shr x 24 as x
sys 60 x

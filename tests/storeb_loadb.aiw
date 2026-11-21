# storeb keeps only the low byte; loadb zero-extends
buf b 8
storeb b 2147483713   # 0x80000041, low byte "A"
add b 1 as p
storeb p 10
sys 1 1 b 2
sub 0 1 as m
store b m
loadb b as c          # 255: a sign-extending load would leave high bits set
shr c 8 as h
sys 60 h

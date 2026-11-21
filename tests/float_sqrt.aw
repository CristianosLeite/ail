# the square root of 2 times a million, as an integer
itof 2 as two
fsqrt two as r
eq r 0x3ff6a09e667f3bcd as ok
itof 1000000 as m
fmul r m as r
ftoi r as i
sub i 1414213 as i
add i ok as i
sys exit i

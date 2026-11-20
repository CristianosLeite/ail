# itof reads all 64 bits: 2 to the power of 32, and its negative
itof 0x100000000 as a
eq a 0x41f0000000000000 as x
itof -0x100000000 as b
eq b 0xc1f0000000000000 as y
shl y 1 as y
or x y as x
sys exit x

# a value is the 64 bits of a double: 1.5 + 2.25, 5 - 0.5, 1.5 * 4, 1 / 3
itof 3 as a
itof 2 as b
fdiv a b as h
itof 9 as c
itof 4 as d
fdiv c d as q
fadd h q as s
eq s 0x400e000000000000 as r1
itof 5 as e
itof 1 as one
fdiv one b as half
fsub e half as t
eq t 0x4012000000000000 as r2
fmul h d as u
eq u 0x4018000000000000 as r3
fdiv one a as v
eq v 0x3fd5555555555555 as r4
shl r2 1 as r2
shl r3 2 as r3
shl r4 3 as r4
or r1 r2 as r1
or r1 r3 as r1
or r1 r4 as r1
sys exit r1

# padd, psub, pmul and pdiv compute two doubles at once, from 16 bytes at
# each of two addresses into 16 bytes at a third; pmadd adds the two
# products to what is there. 1.5 and 2.25 with 4 and 0.5
buf a 16
buf b 16
buf c 80
store a 0x3ff8000000000000
store a+8 0x4002000000000000
store b 0x4010000000000000
store b+8 0x3fe0000000000000
padd c a b
psub c+16 a b
pmul c+32 a b
pdiv c+48 a b
# 10 and 20, plus 6 and 1.125
store c+64 0x4024000000000000
store c+72 0x4034000000000000
pmadd c+64 a b
load c as x
load c+8 as y
r=(x==0x4016000000000000)+(y==0x4006000000000000)
load c+16 as x
load c+24 as y
r+=(x==0xc004000000000000)+(y==0x3ffc000000000000)
load c+32 as x
load c+40 as y
r+=(x==0x4018000000000000)+(y==0x3ff2000000000000)
load c+48 as x
load c+56 as y
r+=(x==0x3fd8000000000000)+(y==0x4012000000000000)
load c+64 as x
load c+72 as y
r+=(x==0x4030000000000000)+(y==0x4035200000000000)
sys exit r

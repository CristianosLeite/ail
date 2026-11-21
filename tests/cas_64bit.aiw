buf c 8
store c 0x100000001
cas c 1 2 as no
cas c 0x100000001 -1 as yes
load c as v
shr v 60 as v
shl yes 4 as yes
or v yes as v
or v no as v
sys exit v

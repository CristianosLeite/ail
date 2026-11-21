set 0x100000001 as a
jeq a 1 bad
jne a 0x100000001 bad
sys 60 3
label bad
sys 60 4

# only bit 32 is set: the low 32 bits are zero, the value is not
shl 1 32 as v
jz v bad
jnz v good
label bad
sys 60 1
label good
sys 1 1 "ok\n"

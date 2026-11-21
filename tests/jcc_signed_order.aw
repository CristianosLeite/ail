set 0 as r
jslt -1 1 a
jmp x
label a
add r 1 as r
jsle -1 1 b
jmp x
label b
add r 2 as r
jsgt 1 -1 c
jmp x
label c
add r 4 as r
jsge 1 -1 d
jmp x
label d
add r 8 as r
jslt 1 -1 x
jsle 1 -1 x
jsgt -1 1 x
jsge -1 1 x
add r 16 as r
label x
sys 60 r

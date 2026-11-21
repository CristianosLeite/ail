set 0 as r
jlt 1 -1 a
jmp x
label a
add r 1 as r
jle 1 -1 b
jmp x
label b
add r 2 as r
jgt -1 1 c
jmp x
label c
add r 4 as r
jge -1 1 d
jmp x
label d
add r 8 as r
jlt -1 1 x
jle -1 1 x
jgt 1 -1 x
jge 1 -1 x
add r 16 as r
label x
sys 60 r

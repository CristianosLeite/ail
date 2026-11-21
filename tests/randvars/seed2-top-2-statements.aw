mul 7 4096 as t1
or 255 t1 as t0
mul 255 4 as t1
xor 64 63 as t2
shl t1 t2 as t1
or t1 1 as t1
mod t0 t1 as v9
sub v9 v9 as t2
mul v9 t2 as t1
sub v9 t1 as v7
jeq v9 v7 l1
eq v7 4096 as t0
sub v9 v7 as t1
or t0 t1 as t0
xor v7 v7 as t2
gt v7 t2 as t1
or t0 t1 as v14
and v7 v14 as t0
and v14 4096 as t1
shl t0 t1 as v21
set 3 as c0
label l2
set v14 as v13
set 3 as c1
label l3
set v9 as v6
set 0 as v17
or v17 1 as t1
div 5 t1 as t0
shl t0 v14 as v10
gt v9 v7 as v31
set v7 as v33
or v7 v17 as t0
mul v10 v21 as t1
sub t1 v33 as t1
or t1 1 as t1
mod t0 t1 as v5
sub c1 1 as c1
jnz c1 l3
set v14 as v24
set 1 as c2
label l4
set v7 as v12
sub c2 1 as c2
jnz c2 l4
set 3 as c3
label l5
add v24 v24 as v24
or v7 4096 as t0
or 0xffffffffffffffff 1 as t1
div t0 t1 as t0
shl t0 v24 as v26
set v14 as v33
set v21 as v26
and v21 3 as t0
add t0 v9 as t0
or v7 1 as t2
div 4096 t2 as t1
shl t0 t1 as v18
shr 0xffffffffffffffff 0 as v14
sub c3 1 as c3
jnz c3 l5
set 3 as c4
label l6
add v7 v24 as t1
or v13 1 as t2
mod t1 t2 as t1
or t1 1 as t1
div v13 t1 as v13
set v21 as v10
set 0xffffffffffffffff as v20
sub v20 v10 as t0
le t0 v13 as v29
set v20 as v24
sub c4 1 as c4
jnz c4 l6
sub c0 1 as c0
jnz c0 l2
jmp l7
label l1
set 2 as c5
label l8
set v9 as v12
sub c5 1 as c5
jnz c5 l8
label l7
jlt v7 v7 l9
or 4 v7 as t0
ge v9 v9 as t1
shr t0 t1 as t0
sub 255 v9 as t2
ge v9 t2 as t1
xor t0 t1 as v15
sub v9 v7 as t0
sub t0 v7 as v29
set v9 as v24
label l9
sub v7 v9 as v19
set v9 as v9
mul v19 v9 as t1
or v7 t1 as v15
set v9 as v27
and v7 v27 as t0
mul t0 v9 as t0
xor v27 v15 as t1
shr t1 0xffffffffffffffff as t1
ge t0 t1 as v29
add v15 v19 as v22
or v22 1 as t2
mod 63 t2 as t1
xor v27 t1 as v18
set v27 as v29
set 0 as h
add h v15 as h
add h v18 as h
add h v19 as h
add h v22 as h
add h v27 as h
add h v29 as h
add h v7 as h
add h v9 as h
mod h 251 as h
sys 60 h

add 0x100000000 2 as t0
ne 4096 1 as t1
shl t0 t1 as t0
gt -1 255 as t1
shr t1 0 as t1
shl t0 t1 as v7
set v7 as v5
sub v7 v7 as t0
or v7 1 as t1
div t0 t1 as t0
add t0 v7 as v9
set v7 as v8
add v8 v5 as t1
or v8 t1 as t0
le v8 v9 as t1
or v8 v5 as t2
mul t1 t2 as t1
shr t0 t1 as v1
add 8 v8 as t0
or 6 1 as t1
mod t0 t1 as t0
mul v7 v7 as t2
shr v9 t2 as t1
shl t0 t1 as v10
sub -1 v1 as t1
shl 0xffffffffffffffff t1 as v6
set v8 as v6
set v1 as v10
or v7 1 as t1
mod v6 t1 as v6
shr v9 8 as t0
and 9 v9 as t1
or 1 1 as t2
div t1 t2 as t1
sub t0 t1 as v6
set v1 as v4
set v6 as v5
shr v8 v7 as t1
shl v4 t1 as v4
jlt v9 v6 l1
jne v10 v5 l2
set v10 as v0
set v5 as v10
label l2
jmp l3
label l1
set v5 as v6
set 3 as c0
label l4
set 2 as c1
label l5
gt v1 v4 as t0
mul v6 3 as t1
lt v9 v8 as t2
and t1 t2 as t1
shl t0 t1 as v6
set 1 as v3
shr v9 5 as v1
sub c1 1 as c1
jnz c1 l5
set v5 as v2
set 0xffffffffffffffff as v4
jne v8 v5 l6
or v9 1 as t2
mod v6 t2 as t1
xor t1 5 as t1
shr v4 t1 as v4
jmp l7
label l6
set v2 as v1
xor 4096 v4 as t1
or v1 8 as t2
shl t1 t2 as t1
xor v5 t1 as v5
or v2 v4 as v4
label l7
sub c0 1 as c0
jnz c0 l4
label l3
or v7 1 as t1
div v1 t1 as v4
shl v5 0x100000000 as v5
set 0 as h
add h v1 as h
add h v10 as h
add h v4 as h
add h v5 as h
add h v6 as h
add h v7 as h
add h v8 as h
add h v9 as h
mod h 251 as h
sys 60 h

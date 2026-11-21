set -1 as v12
and v12 0x100000000 as t0
mul t0 v12 as t0
sub v12 v12 as t1
and v12 v12 as t2
xor t1 t2 as t1
mul t0 t1 as v9
or v12 1 as t1
div v9 t1 as t0
shl v9 v9 as t1
or t0 t1 as t0
eq v9 v9 as t2
xor 64 t2 as t1
sub t0 t1 as v5
set v5 as v12
ne 8 4096 as t0
jz t0 l1
set 0xffffffffffffffff as v12
set v5 as v7
set 2 as c0
label l2
xor 4 0x100000000 as t0
and v12 v5 as t1
ne t0 t1 as v8
or v9 1 as t1
div v7 t1 as t0
or t0 v7 as t0
add v12 v12 as t1
le v12 v8 as t2
add t1 t2 as t1
xor t0 t1 as v11
set 0xffffffffffffffff as v11
or v8 1 as t3
div v7 t3 as t2
shl 4 t2 as t1
xor v11 t1 as v3
mul v5 v8 as t2
shr 3 t2 as t1
or t1 1 as t1
div v5 t1 as v11
sub c0 1 as c0
jnz c0 l2
set 2 as c1
label l3
set v5 as v8
set v9 as v9
shr v7 v7 as t1
or 2 1 as t2
div t1 t2 as t1
sub v8 t1 as v8
sub c1 1 as c1
jnz c1 l3
label l1
set v12 as v9
or 6 v12 as t0
add t0 v9 as t0
le v9 v9 as t1
gt v12 v12 as t2
gt t1 t2 as t1
or t0 t1 as v11
add 63 v11 as t1
eq v9 t1 as v9
xor v12 v5 as t2
shl v5 t2 as t1
mul v12 t1 as v12
set v11 as v7
set 1 as c2
label l4
shr v7 9 as t1
xor v7 t1 as t0
le t0 v9 as v12
sub c2 1 as c2
jnz c2 l4
mul v7 v11 as t0
shr v7 9 as t1
and t0 t1 as t0
jz t0 l5
set v11 as v7
set v7 as v8
set v11 as v5
jmp l6
label l5
or v9 v7 as t1
add v7 t1 as t0
xor t0 v12 as v8
label l6
add v7 v5 as t0
shr t0 v12 as v1
set v12 as v6
set 8 as v1
xor v1 v5 as t1
lt v1 t1 as v0
or v1 1 as t2
mod v9 t2 as t1
sub v6 v7 as t2
mul t1 t2 as t1
shl v11 t1 as v6
set 5 as v12
lt v0 v5 as t0
add v12 v5 as t1
ge t0 t1 as t0
mul t0 v11 as v4
set 0 as h
add h v0 as h
add h v1 as h
add h v11 as h
add h v12 as h
add h v4 as h
add h v5 as h
add h v6 as h
add h v7 as h
add h v9 as h
mod h 251 as h
sys 60 h

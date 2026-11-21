set -1 as v11
set 2 as c0
label l1
set 1 as c1
label l2
jgt 3 v11 l3
mul v11 v11 as t0
ne t0 v11 as t0
or t0 v11 as v1
label l3
set v11 as v11
shr v11 v11 as t1
or v11 1 as t3
div v11 t3 as t2
xor t1 t2 as t1
or t1 1 as t1
mod 4096 t1 as v5
or v11 1 as t3
div v11 t3 as t2
xor v11 t2 as t1
shl v11 t1 as v16
sub c1 1 as c1
jnz c1 l2
set v11 as v4
set v4 as v18
add 8 v18 as t0
mul t0 255 as t0
sub t0 v18 as v9
set v9 as v16
jgt v18 v16 l4
gt v11 v18 as t1
sub v11 t1 as v6
set 2 as c2
label l5
set v16 as v12
set v4 as v5
set 0xffffffffffffffff as v10
sub c2 1 as c2
jnz c2 l5
label l4
sub c0 1 as c0
jnz c0 l1
set v11 as v14
set v11 as v17
and v14 v17 as v10
set 3 as c3
label l6
set 3 as c4
label l7
jlt v11 v14 l8
set v14 as v10
set v11 as v11
label l8
set 1 as c5
label l9
set v14 as v4
set v4 as v6
sub c5 1 as c5
jnz c5 l9
jgt v11 v14 l10
set v11 as v0
eq v10 v11 as v18
shr 3 v0 as t1
ge v0 t1 as t0
gt v14 v10 as t1
or t1 v14 as t1
mul t0 t1 as v11
jmp l11
label l10
set v10 as v6
or v14 1 as t1
mod v6 t1 as v12
or v11 1 as t1
div v10 t1 as t0
sub 5 v10 as t1
mul t0 t1 as t0
gt v14 v17 as t1
add t1 v6 as t1
xor t0 t1 as v7
label l11
sub c4 1 as c4
jnz c4 l7
jle -1 v14 l12
lt v11 v10 as v6
mul v10 v6 as t0
and v17 v10 as t1
xor t0 t1 as t0
shr t0 v17 as v13
xor v6 v10 as t0
xor t0 v10 as t0
shr v17 7 as t1
shr t1 v13 as t1
xor t0 t1 as v18
shr v17 v17 as t0
add t0 v13 as t0
or v18 1 as t2
mod v13 t2 as t1
or v17 1 as t2
mod t1 t2 as t1
shl t0 t1 as v4
jmp l13
label l12
set v11 as v16
label l13
sub c3 1 as c3
jnz c3 l6
set v17 as v6
set 0x100000000 as v4
set 255 as v0
set v0 as v2
shl 0 v6 as t1
le v11 t1 as t0
jz t0 l14
set 1 as c6
label l15
set v0 as v16
xor v0 v4 as t0
ge v14 v10 as t1
xor t0 t1 as t0
shl t0 v10 as v8
sub c6 1 as c6
jnz c6 l15
set 0xffffffffffffffff as v13
set v2 as v4
label l14
shr -1 v10 as t0
add v10 v4 as t1
sub t0 t1 as t0
or v11 1 as t1
div t0 t1 as v8
set 3 as c7
label l16
jeq v4 0x100000000 l17
or v17 1 as t1
mod v10 t1 as v1
jmp l18
label l17
shr -1 v17 as t1
or t1 1 as t1
div v14 t1 as t0
sub 2 v14 as t1
shr t1 9 as t1
ne t0 t1 as v11
label l18
jne v4 v17 l19
set 2 as c8
label l20
set v14 as v14
lt 4 v0 as t1
shl v8 t1 as t0
add v14 v11 as t2
le v6 t2 as t1
sub t0 t1 as v17
set v8 as v0
sub c8 1 as c8
jnz c8 l20
sub 0x100000000 v14 as v17
label l19
set v8 as v17
sub v4 v4 as t0
or v11 1 as t2
div 64 t2 as t1
mul t0 t1 as t0
or v17 1 as t2
div v14 t2 as t1
sub t0 t1 as v5
jle v6 v6 l21
or 0x100000000 1 as t1
mod v11 t1 as t0
add 6 v2 as t1
add t0 t1 as t0
and 4096 v4 as t1
xor t0 t1 as v6
le 4096 v10 as t1
and v8 t1 as t0
or v17 1 as t2
mod 0x100000000 t2 as t1
or v0 4 as t2
shr t1 t2 as t1
ne t0 t1 as v12
jmp l22
label l21
shl v5 v5 as v10
label l22
sub c7 1 as c7
jnz c7 l16
mul v17 v2 as v3
set 63 as v10
set v11 as v0
set 0 as h
add h v0 as h
add h v10 as h
add h v11 as h
add h v14 as h
add h v17 as h
add h v2 as h
add h v3 as h
add h v4 as h
add h v6 as h
add h v8 as h
mod h 251 as h
sys 60 h

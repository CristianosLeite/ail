set 2 as c0
label l1
set -1 as v1
set 0x100000000 as v6
sub v1 v6 as t0
or v6 1 as t2
mod v1 t2 as t1
or t1 1 as t1
mod t0 t1 as t0
and t0 v6 as v2
eq v1 v6 as t2
or t2 1 as t2
mod v2 t2 as t1
add v1 t1 as v5
set 3 as c1
label l2
set v6 as v1
or v5 1 as t2
mod v6 t2 as t1
add t1 v1 as t1
ge v1 t1 as v4
sub c1 1 as c1
jnz c1 l2
mul v6 255 as t0
xor t0 v1 as t0
and t0 0x100000000 as v5
sub c0 1 as c0
jnz c0 l1
set -1 as v0
sub v0 v0 as t1
or t1 1 as t1
mod v0 t1 as t0
shr v0 4 as t1
le v0 0xffffffffffffffff as t2
or t2 1 as t2
mod t1 t2 as t1
or t1 1 as t1
mod t0 t1 as v6
add v0 v0 as t0
shl t0 v6 as t0
jz t0 l3
shl v0 v0 as v6
label l3
jz v6 l4
or v0 v0 as t0
eq v6 v6 as t1
or t1 1 as t1
mod t0 t1 as t0
add v0 v0 as t1
shr t0 t1 as v0
jmp l5
label l4
set 2 as c2
label l6
shl v6 64 as t1
or t1 1 as t1
mod v6 t1 as v6
set v6 as v7
set v7 as v1
sub c2 1 as c2
jnz c2 l6
set 3 as c3
label l7
jeq v6 v6 l8
shl v6 v6 as t0
add 6 v6 as t1
sub t0 t1 as t0
gt t0 v6 as v4
set v0 as v9
label l8
jle v6 v0 l9
set v6 as v0
label l9
set v0 as v1
set 3 as c4
label l10
eq 64 v6 as t0
xor v1 v0 as t1
shl t0 t1 as t0
sub t0 9 as v6
set 2 as v4
le v4 v0 as t0
or t0 v4 as v7
set v7 as v0
sub c4 1 as c4
jnz c4 l10
set v1 as v1
jz v0 l11
set v6 as v2
set v0 as v1
shl v6 0xffffffffffffffff as t0
xor t0 v0 as t0
or v0 1 as t1
mod t0 t1 as v9
shr v6 v1 as v4
jmp l12
label l11
mul v1 v6 as t1
or v6 1 as t2
mod t1 t2 as t1
xor v6 t1 as v0
set 0xffffffffffffffff as v2
set v2 as v2
label l12
sub c3 1 as c3
jnz c3 l7
or v0 1 as t1
mod v0 t1 as t0
shl v6 v0 as t1
sub t0 t1 as t0
ge v6 v6 as t2
shr v0 t2 as t1
shl t0 t1 as v8
label l5
or v0 1 as t1
mod v0 t1 as t0
or v6 v6 as t2
shr v0 t2 as t1
shr t0 t1 as v5
xor v6 v5 as t0
jz t0 l13
sub v0 v6 as t0
shl t0 v0 as t0
xor t0 9 as v1
add 0 3 as v3
jeq v1 v3 l14
xor v3 v5 as v3
set v6 as v2
label l14
or 8 1 as t1
mod v6 t1 as t0
add v5 v3 as t1
lt t0 t1 as t0
gt t0 v5 as v4
jmp l15
label l13
jne 4096 v6 l16
set v5 as v5
or v6 1 as t1
div 63 t1 as t0
add t0 v6 as v2
lt v6 v6 as t1
eq t1 v0 as t1
xor v0 t1 as v0
sub v6 v6 as v3
label l16
or v5 v0 as v1
shl v0 v5 as t0
or v1 1 as t1
mod t0 t1 as t0
sub v5 v1 as t1
add 5 v5 as t2
sub t1 t2 as t1
shr t0 t1 as v3
label l15
set v5 as v0
and 0 v6 as t0
add v0 0 as t1
mul t0 t1 as t0
eq v5 v0 as t1
shr t1 v6 as t1
ne t0 t1 as v3
lt v3 v3 as t0
or v3 1 as t2
mod v5 t2 as t1
ne t0 t1 as t0
sub v0 v6 as t2
add v5 t2 as t1
le t0 t1 as v0
set v6 as v6
set 2 as c5
label l17
set v5 as v7
or v5 1 as t2
mod v3 t2 as t1
shl v7 t1 as t0
add v5 2 as t2
or t2 1 as t2
div v7 t2 as t1
add t0 t1 as v0
gt v3 v5 as v2
sub c5 1 as c5
jnz c5 l17
or v0 1 as t1
mod v5 t1 as v5
add v3 v3 as t2
or v5 t2 as t1
or t1 1 as t1
mod v6 t1 as v0
shl v0 v0 as t1
shr v5 2 as t2
xor t1 t2 as t1
shl v5 t1 as v5
jne v6 v5 l18
jlt 64 v5 l19
or v0 1 as t3
div v6 t3 as t2
lt v6 t2 as t1
shl v0 t1 as v0
jmp l20
label l19
le 7 v5 as t0
sub t0 v5 as v4
set 2 as c6
label l21
set v3 as v1
or v3 1 as t2
div v6 t2 as t1
mul t1 v6 as t1
xor v0 t1 as v2
set v6 as v9
set v9 as v4
set v9 as v9
sub c6 1 as c6
jnz c6 l21
shl v4 v0 as v4
label l20
xor v5 v0 as t0
add -1 v6 as t1
shr t0 t1 as t0
lt t0 v5 as v6
jgt v5 v3 l22
lt -1 0 as t0
jz t0 l23
mul 255 v0 as t1
shl v0 -1 as t2
xor t1 t2 as t1
shr -1 t1 as v5
or 0x100000000 1 as t3
mod v0 t3 as t2
xor 3 t2 as t1
or t1 1 as t1
div v5 t1 as v2
jmp l24
label l23
set v0 as v1
label l24
sub v5 v3 as t0
or t0 v3 as t0
xor v6 v6 as t1
shl v5 v3 as t2
add t1 t2 as t1
and t0 t1 as v7
mul v3 v7 as v2
label l22
label l18
shr v6 v5 as t1
add 1 t1 as t0
add 0 v3 as t2
sub v6 t2 as t1
add t0 t1 as v9
sub v3 v9 as t2
or v0 t2 as t1
eq 9 t1 as v2
ne v6 -1 as t2
add v3 t2 as t1
mul v3 t1 as v3
set 3 as c7
label l25
set 0xffffffffffffffff as v1
shl v6 v1 as t1
sub 8 t1 as v4
mul v6 63 as v1
set 4 as v5
sub c7 1 as c7
jnz c7 l25
set 2 as c8
label l26
set 1 as c9
label l27
set 3 as c10
label l28
ne 0x100000000 v2 as t1
xor 0xffffffffffffffff t1 as t0
mul 64 v9 as t1
shl t0 t1 as v0
set v2 as v9
set v0 as v6
sub c10 1 as c10
jnz c10 l28
set v9 as v9
jne 255 v3 l29
or v3 1 as t1
div v6 t1 as t0
or t0 v0 as t0
or v3 1 as t2
mod v0 t2 as t1
and t0 t1 as v8
label l29
set v2 as v6
sub c9 1 as c9
jnz c9 l27
sub c8 1 as c8
jnz c8 l26
mul v9 v9 as v7
set v0 as v6
set v2 as v8
set v3 as v1
set 0 as h
add h v0 as h
add h v1 as h
add h v2 as h
add h v3 as h
add h v5 as h
add h v6 as h
add h v7 as h
add h v8 as h
add h v9 as h
mod h 251 as h
sys 60 h

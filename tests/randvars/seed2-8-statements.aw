fn f p0 p1
set p1 as v11
set p1 as v13
set 2 as v20
set 1 as c0
label l1
jgt v20 p1 l2
set 3 as c1
label l3
set p0 as v21
sub c1 1 as c1
jnz c1 l3
jeq v11 p1 l4
ne p1 p0 as t1
xor v20 t1 as v4
add 0x100000000 v11 as t1
xor v20 t1 as t0
add v20 v11 as t1
shl p1 p0 as t2
xor t1 t2 as t1
ne t0 t1 as v3
lt v4 v20 as t1
le v13 t1 as v13
set p0 as v19
label l4
jmp l5
label l2
set p1 as v22
label l5
or v11 0xffffffffffffffff as t0
and t0 p0 as t0
add v13 1 as t2
or t2 1 as t2
div 0xffffffffffffffff t2 as t1
shl t0 t1 as v21
sub c0 1 as c0
jnz c0 l1
jge v11 p1 l6
set -1 as v2
jlt p0 v20 l7
set 3 as v13
set 1 as c2
label l8
set v20 as v22
shl v11 63 as v23
sub c2 1 as c2
jnz c2 l8
jgt p1 v20 l9
set v13 as v14
jmp l10
label l9
set v2 as v5
label l10
label l7
label l6
jne 0x100000000 v20 l11
jgt v11 v13 l12
set v11 as v21
label l12
sub p1 2 as t1
or p1 t1 as v12
set 2 as c3
label l13
or v13 1 as t2
mod 0x100000000 t2 as t1
shl p0 t1 as t0
or t0 v12 as v25
jeq p1 v20 l14
shl 255 0xffffffffffffffff as t1
xor v13 t1 as t0
and t0 0xffffffffffffffff as v7
sub v7 p1 as t0
shl v13 v20 as t1
or t1 1 as t1
mod t0 t1 as t0
lt t0 v11 as v21
jmp l15
label l14
or v12 1 as t2
div 64 t2 as t1
and t1 v20 as t1
mul v11 t1 as v14
or v12 1 as t1
mod -1 t1 as t0
ne v20 64 as t1
mul t0 t1 as t0
shr p1 v14 as t1
sub t1 v12 as t1
and t0 t1 as v9
mul v25 0xffffffffffffffff as t0
gt t0 63 as t0
shr v14 v20 as t2
or t2 1 as t2
mod p0 t2 as t1
and t0 t1 as v23
label l15
set 7 as v21
xor 8 v20 as t0
or v11 1 as t1
mod t0 t1 as v25
set p1 as v11
sub c3 1 as c3
jnz c3 l13
sub v20 v20 as t1
or v11 1 as t3
mod v11 t3 as t2
shl t1 t2 as t1
shl v13 t1 as v7
label l11
or v11 1 as t1
div v11 t1 as t0
sub 255 0x100000000 as t1
gt t0 t1 as t0
eq t0 v11 as v7
add 63 p0 as t1
sub v7 63 as t2
sub t1 t2 as t1
or t1 1 as t1
mod p1 t1 as v19
mul v13 v19 as t1
add 64 8 as t2
sub t1 t2 as t1
gt 6 t1 as v19
jle v13 p1 l16
and v20 255 as t0
gt v13 v20 as t1
shr t0 t1 as t0
or 4 1 as t2
mod p0 t2 as t1
or 4 1 as t3
mod p0 t3 as t2
sub t1 t2 as t1
and t0 t1 as v24
gt p0 v19 as t0
xor 4096 v7 as t1
shr t0 t1 as t0
xor t0 v13 as v16
set 1 as v16
jmp l17
label l16
or v20 1 as t1
mod p1 t1 as v9
label l17
sub v7 v13 as t1
or t1 1 as t1
mod p1 t1 as t0
or t0 v11 as v6
xor v11 v7 as v0
set v7 as v1
jle v19 3 l18
and v1 v7 as t1
shl p0 t1 as t0
gt t0 v19 as v9
label l18
xor v0 v20 as t0
and v19 v7 as t1
mul v13 v11 as t2
shl t1 t2 as t1
and t0 t1 as v1
shr 63 p1 as t1
le v0 t1 as t0
mul v19 7 as t1
or t1 4 as t1
shl t0 t1 as v4
set 3 as v16
set v16 as v20
set v4 as v20
set v7 as v24
set v20 as v5
shr 3 p0 as t1
shl 1 t1 as t0
or t0 v20 as v5
or p1 1 as t2
mod v7 t2 as t1
or v5 v6 as t2
le t1 t2 as t1
or t1 1 as t1
mod v0 t1 as v0
mul v19 v0 as v19
set 0 as h
add h p0 as h
add h p1 as h
add h v0 as h
add h v1 as h
add h v11 as h
add h v13 as h
add h v16 as h
add h v19 as h
add h v20 as h
add h v24 as h
add h v4 as h
add h v5 as h
add h v6 as h
add h v7 as h
mod h 251 as h
ret h
end
call f 173 46 as r
sys 60 r

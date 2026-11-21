fn f p0 p1 p2
set p1 as v7
jle v7 v7 l1
set v7 as v9
set 2 as c0
label l2
sub p1 v7 as t1
lt 0x100000000 t1 as t0
jz t0 l3
set p1 as v2
set v7 as v7
label l3
shr 4096 p0 as t0
add t0 v7 as t0
mul 4096 p2 as t1
mul p0 p2 as t2
lt t1 t2 as t1
mul t0 t1 as v5
set 63 as v1
jne 64 v7 l4
add v7 p1 as v0
set 8 as v6
label l4
sub c0 1 as c0
jnz c0 l2
set 3 as c1
label l5
jne v7 v9 l6
mul p2 0x100000000 as t1
add p0 t1 as v3
jmp l7
label l6
set p2 as v7
or p0 1 as t2
mod p1 t2 as t1
add p2 0xffffffffffffffff as t2
sub t1 t2 as t1
or t1 1 as t1
div v9 t1 as v9
label l7
set v7 as v4
sub c1 1 as c1
jnz c1 l5
sub 2 v7 as v6
label l1
and p2 64 as v9
jge p2 p1 l8
jgt p1 v9 l9
and p0 0xffffffffffffffff as t0
or p1 p2 as t1
add t0 t1 as t0
or p0 1 as t1
div t0 t1 as v0
label l9
set 2 as c2
label l10
set 2 as c3
label l11
set p2 as v8
set v9 as v7
sub c3 1 as c3
jnz c3 l11
set 1 as c4
label l12
and v9 p0 as t1
shr 63 p1 as t2
or t2 1 as t2
div t1 t2 as t1
sub v9 t1 as v8
set v8 as v7
ne p2 p1 as t1
or v8 1 as t3
mod 5 t3 as t2
and t1 t2 as t1
sub v7 t1 as v0
add p0 p2 as t1
le t1 p2 as t1
lt v9 t1 as v9
or v7 1 as t1
mod p0 t1 as v3
set p2 as v4
sub c4 1 as c4
jnz c4 l12
set -1 as v5
or p2 1 as t1
mod -1 t1 as t0
or p2 1 as t1
mod t0 t1 as t0
eq p2 p0 as t1
gt t0 t1 as v8
eq v7 v5 as t0
add v9 v5 as t1
eq t0 t1 as t0
jz t0 l13
set 0xffffffffffffffff as v4
ge v9 v9 as t0
shl v9 v4 as t1
add t0 t1 as t0
shl t0 v9 as v6
lt 63 p0 as v3
jmp l14
label l13
set p0 as v4
set v4 as v6
or p0 v4 as t1
add v5 t1 as t0
or p1 v7 as t1
gt t1 v4 as t1
mul t0 t1 as v6
label l14
sub c2 1 as c2
jnz c2 l10
jmp l15
label l8
sub p2 p0 as t1
or t1 v7 as t1
sub v7 t1 as v6
set 3 as c5
label l16
or p1 1 as t1
mod v9 t1 as t0
lt p1 p0 as t1
shl t0 t1 as t0
jz t0 l17
set 4096 as v3
label l17
sub c5 1 as c5
jnz c5 l16
label l15
set 8 as v8
jz p1 l18
set p0 as v9
set p2 as v1
label l18
mul p0 v7 as t0
shr v7 63 as t1
shl t1 p2 as t1
or t1 1 as t1
div t0 t1 as v8
set v8 as v0
set v8 as v1
shr v0 4096 as v0
sub p1 p1 as t0
and 1 1 as t1
ne t0 t1 as t0
mul t0 p2 as v8
set 2 as c6
label l19
jne v0 4096 l20
jeq p2 7 l21
set v1 as v5
set 3 as v7
and 64 v5 as t1
sub 0 t1 as t0
and p0 v1 as t2
or t2 1 as t2
div v1 t2 as t1
sub t0 t1 as v4
shr 4096 v4 as t0
shl v8 v8 as t1
xor t0 t1 as t0
add v0 v4 as t1
add p1 p0 as t2
or t1 t2 as t1
or t1 1 as t1
mod t0 t1 as v4
label l21
set v1 as v6
or 0xffffffffffffffff 1 as t3
div v1 t3 as t2
or t2 1 as t2
mod p2 t2 as t1
shl v6 t1 as v3
mul p0 v0 as t0
mul t0 v9 as t0
or v3 1 as t1
div t0 t1 as v5
label l20
jlt p1 p0 l22
set p0 as v9
set 3 as v2
jge v1 -1 l23
set v8 as v3
shl 6 v1 as t1
xor p0 v1 as t2
or t2 1 as t2
div t1 t2 as t1
or t1 1 as t1
mod 7 t1 as v7
mul 63 4096 as t0
and t0 v3 as t0
xor p1 v9 as t1
and p0 v7 as t2
or t2 1 as t2
div t1 t2 as t1
mul t0 t1 as v8
or v1 255 as t0
sub t0 3 as t0
shl t0 4096 as v5
label l23
label l22
sub c6 1 as c6
jnz c6 l19
set v8 as v6
and p1 5 as v4
jeq 0x100000000 p0 l24
add p2 p1 as t1
or t1 1 as t1
div p0 t1 as t0
ne t0 v4 as v6
set v7 as v8
jmp l25
label l24
sub v9 v7 as t0
and p0 v7 as t1
xor t0 t1 as t0
or v9 1 as t2
mod p0 t2 as t1
shl 1 p0 as t2
sub t1 t2 as t1
or t0 t1 as v3
or v9 v1 as v9
set 2 as c7
label l26
set p1 as v9
jz 4096 l27
and v7 v3 as v3
set v3 as v4
or p2 v0 as t2
mul v3 t2 as t1
or t1 1 as t1
div p0 t1 as v7
or v9 1 as t1
mod v9 t1 as v0
label l27
sub c7 1 as c7
jnz c7 l26
label l25
set v1 as v0
set v4 as v8
sub v0 p2 as t1
add v1 t1 as t0
ge v8 v9 as t2
shr v7 t2 as t1
ne t0 t1 as v0
set 1 as c8
label l28
sub 9 v7 as v2
jgt v9 v0 l29
jz 0xffffffffffffffff l30
xor p0 v9 as t2
shr v7 t2 as t1
add p0 t1 as v6
set 255 as v3
jmp l31
label l30
and v2 v0 as t0
ge v8 3 as t1
add t0 t1 as t0
shl p1 v1 as t1
xor t0 t1 as v0
set v8 as v4
label l31
set v2 as v3
jmp l32
label l29
set 1 as c9
label l33
shl v4 9 as v3
shl v1 v1 as t1
or 63 0 as t2
shr t1 t2 as t1
shr 2 t1 as v0
sub c9 1 as c9
jnz c9 l33
set v2 as v9
shl v7 p1 as v4
label l32
sub c8 1 as c8
jnz c8 l28
set 3 as c10
label l34
shl v4 v4 as t1
shl t1 p0 as t1
or t1 1 as t1
mod v7 t1 as v1
or p1 64 as t0
and v4 p1 as t1
lt t0 t1 as t0
shr p2 v7 as t2
or t2 1 as t2
div v8 t2 as t1
or t1 1 as t1
div t0 t1 as v0
sub c10 1 as c10
jnz c10 l34
set 1 as c11
label l35
set p2 as v0
sub c11 1 as c11
jnz c11 l35
set v9 as v0
or v6 1 as t2
mod 4 t2 as t1
and v1 t1 as t0
mul t0 v8 as v4
jlt v6 v0 l36
set p1 as v2
or v4 1 as t1
div v7 t1 as v7
mul 4096 p0 as t0
shr t0 2 as v9
sub v0 v9 as t1
add p0 t1 as t0
or t0 v2 as v7
jmp l37
label l36
set v7 as v6
gt p2 v9 as t1
add t1 v8 as t1
shr p2 t1 as v0
label l37
set 0 as h
add h p0 as h
add h p1 as h
add h p2 as h
add h v0 as h
add h v1 as h
add h v4 as h
add h v6 as h
add h v7 as h
add h v8 as h
add h v9 as h
mod h 251 as h
ret h
end
call f 44 259 183 as r
sys 60 r

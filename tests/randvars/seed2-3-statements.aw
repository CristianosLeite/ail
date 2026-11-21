fn f p0 p1 p2 p3
and p1 p3 as t0
shr 2 p0 as t1
shr t1 p0 as t1
sub t0 t1 as v10
set 2 as c0
label l1
set v10 as v5
xor p1 v5 as v3
set v3 as v7
sub c0 1 as c0
jnz c0 l1
jlt p2 p2 l2
jz p1 l3
set 63 as v7
mul v7 8 as t1
or v7 1 as t2
div t1 t2 as t1
shl 0xffffffffffffffff t1 as v10
set v7 as v3
jmp l4
label l3
set 255 as v9
set 2 as c1
label l5
xor p2 p1 as t1
shl v9 t1 as t0
or p2 1 as t2
mod p0 t2 as t1
and p2 p3 as t2
or t1 t2 as t1
or t1 1 as t1
div t0 t1 as v5
set v9 as v0
xor p3 v10 as t1
sub p3 t1 as t0
shr p3 64 as t1
sub p1 p0 as t2
or t1 t2 as t1
lt t0 t1 as v1
xor v0 0xffffffffffffffff as t0
ne t0 p0 as t0
or p0 1 as t1
div t0 t1 as v6
sub c1 1 as c1
jnz c1 l5
shr p3 p0 as t0
or p1 1 as t1
div t0 t1 as t0
add t0 p2 as v5
label l4
jmp l6
label l2
jge v10 p3 l7
set v10 as v7
label l7
label l6
set p1 as v8
set p2 as v10
set p1 as v1
shl 0 v1 as t0
xor 0 p2 as t1
xor t0 t1 as t0
add t0 p1 as v3
set p0 as v10
set 1 as c2
label l8
shr p3 64 as t0
and v10 p2 as t1
shl t0 t1 as t0
shl t0 p2 as v7
mul v10 v1 as v10
le p2 p0 as t1
xor 0x100000000 t1 as t0
xor t0 p0 as v2
set 2 as c3
label l9
set 1 as v6
sub c3 1 as c3
jnz c3 l9
shr v8 p0 as v8
sub c2 1 as c2
jnz c2 l8
set 1 as c4
label l10
set 7 as v6
set v6 as v7
sub c4 1 as c4
jnz c4 l10
set v8 as v8
or v3 1 as t1
mod p1 t1 as t0
xor t0 v1 as v7
ne 0xffffffffffffffff 4096 as t0
jz t0 l11
set v8 as v9
jge v8 v7 l12
set 2 as c5
label l13
gt v1 5 as t1
xor v10 v1 as t2
ge t1 t2 as t1
or t1 1 as t1
div p1 t1 as v10
sub v1 p2 as t2
add v7 t2 as t1
shr v7 t1 as v7
sub c5 1 as c5
jnz c5 l13
jmp l14
label l12
set 6 as v8
label l14
and v8 v10 as t2
shr v8 t2 as t1
or t1 1 as t1
mod v9 t1 as v5
shr v3 p1 as t1
xor v5 v1 as t2
add t1 t2 as t1
shl v8 t1 as v10
jmp l15
label l11
shr v7 v8 as t0
add p3 p0 as t1
le t0 t1 as t0
jz t0 l16
add 8 1 as v4
label l16
sub p1 63 as t1
mul p0 t1 as t0
or t0 v3 as v6
label l15
set 0 as h
add h p0 as h
add h p1 as h
add h p2 as h
add h p3 as h
add h v1 as h
add h v10 as h
add h v3 as h
add h v7 as h
add h v8 as h
mod h 251 as h
ret h
end
call f 344 557 24 0 as r
sys 60 r

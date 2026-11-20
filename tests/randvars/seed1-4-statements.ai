fn f p0 p1 p2
set p1 as v7
xor p0 p0 as t0
or p2 1 as t2
mod v7 t2 as t1
mul t0 t1 as t0
or v7 1 as t1
div t0 t1 as v10
ne p2 v7 as t1
add 2 t1 as t0
or t0 p1 as v6
xor v7 v10 as t1
sub p2 v7 as t2
or t2 1 as t2
mod t1 t2 as t1
add v6 t1 as v2
ne v2 v6 as v2
jlt p2 v6 l1
or v2 1 as t2
mod 7 t2 as t1
add v2 v6 as t2
shl t1 t2 as t1
shl v6 t1 as v4
set 2 as c0
label l2
xor v4 p2 as t0
sub t0 v6 as v0
sub c0 1 as c0
jnz c0 l2
label l1
eq v7 0xffffffffffffffff as t1
sub t1 p0 as t1
eq v2 t1 as v1
and p1 v7 as v2
jne v1 p2 l3
sub v10 -1 as t0
shl t0 v10 as v7
jz v1 l4
set 0xffffffffffffffff as v1
shl v1 v7 as t0
shl t0 p1 as t0
mul v6 63 as t1
or t0 t1 as v7
set 4 as v5
set 2 as c1
label l5
ne 0x100000000 p2 as t2
xor 0xffffffffffffffff t2 as t1
ne 3 t1 as v1
set 64 as v0
mul v2 v7 as t0
add t0 -1 as v7
set v10 as v9
or v2 1 as t3
div 3 t3 as t2
shr v2 t2 as t1
add v5 t1 as v5
sub c1 1 as c1
jnz c1 l5
jmp l6
label l4
set p2 as v6
label l6
jmp l7
label l3
sub v6 v7 as v2
set v10 as v0
label l7
xor v1 p0 as v1
or 64 1 as t1
div v2 t1 as t0
shr p1 p0 as t1
eq t0 t1 as t0
lt p2 p2 as t1
mul v10 v2 as t2
ne t1 t2 as t1
xor t0 t1 as v5
set v2 as v4
shr v7 v5 as t0
sub t0 p2 as v9
jeq 3 v9 l8
ne v6 v6 as t2
sub p1 t2 as t1
shl v6 t1 as v6
xor v2 v1 as v2
shr v7 v10 as t1
add t1 5 as t1
xor v2 t1 as v6
label l8
set v4 as v5
sub p2 5 as t0
shl p0 v10 as t1
le t0 t1 as t0
jz t0 l9
set v1 as v5
add v10 v9 as t1
shl v5 t1 as t0
or t0 p2 as v1
or v6 1 as t2
mod 0xffffffffffffffff t2 as t1
add v1 t1 as v2
set 7 as v6
label l9
or 6 1 as t3
div p1 t3 as t2
and v5 t2 as t1
or t1 1 as t1
mod v9 t1 as v9
shl 4096 v5 as t1
xor v4 6 as t2
sub t1 t2 as t1
and v7 t1 as v8
gt p1 63 as t1
ne v6 t1 as t0
eq t0 v4 as v0
jgt p0 7 l10
set v4 as v5
set v4 as v1
label l10
set v5 as v0
set v0 as v3
set 0xffffffffffffffff as v4
set 1 as c2
label l11
set 1 as c3
label l12
lt v6 p0 as v6
jgt v4 v6 l13
set p2 as v9
label l13
sub c3 1 as c3
jnz c3 l12
set v10 as v5
gt v3 p1 as v8
sub c2 1 as c2
jnz c2 l11
set p0 as v6
set 0 as h
add h p0 as h
add h p1 as h
add h p2 as h
add h v0 as h
add h v1 as h
add h v10 as h
add h v2 as h
add h v3 as h
add h v4 as h
add h v5 as h
add h v6 as h
add h v7 as h
add h v8 as h
add h v9 as h
mod h 251 as h
ret h
end
call f 513 188 58 as r
sys 60 r

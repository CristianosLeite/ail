fn f p0 p1 p2 p3
or p2 1 as t1
mod p0 t1 as t0
add 0 p0 as t1
mul t0 t1 as t0
or 8 1 as t2
div p3 t2 as t1
shl t1 p3 as t1
xor t0 t1 as v7
jz 1 l1
or p3 1 as t2
mod 7 t2 as t1
shl p3 t1 as t0
gt t0 v7 as v5
or p3 1 as t1
div p3 t1 as t0
jz t0 l2
or 0x100000000 1 as t2
div v5 t2 as t1
sub p0 t1 as v9
label l2
or v5 1 as t2
div 6 t2 as t1
or t1 1 as t1
div 7 t1 as v8
jmp l3
label l1
shr p0 p1 as t1
shr 1 t1 as t0
sub t0 p1 as v3
or p2 p0 as t0
shr t0 p1 as v2
jne p3 v3 l4
mul v2 6 as t0
shl 4 4 as t1
or t1 1 as t1
div t0 t1 as t0
shr v7 4096 as t1
shl t0 t1 as v8
shr p3 64 as t2
xor v3 t2 as t1
and v7 t1 as v9
jmp l5
label l4
set v2 as v10
or p3 1 as t1
div v10 t1 as v10
label l5
label l3
or p0 p3 as t1
and v7 t1 as v8
set 1 as c0
label l6
set 3 as c1
label l7
shr p0 0x100000000 as t1
shr v7 t1 as t0
shl v7 p0 as t1
sub p0 p3 as t2
add t1 t2 as t1
or t1 1 as t1
mod t0 t1 as v9
set 1 as c2
label l8
and p0 p2 as v4
set p1 as v5
and v4 v4 as t1
eq v5 t1 as v5
shl v5 v4 as v1
or p1 1 as t1
mod p3 t1 as v1
sub c2 1 as c2
jnz c2 l8
or p1 1 as t1
div 2 t1 as t0
add v9 4 as t1
or t1 1 as t1
div t0 t1 as t0
or 3 1 as t2
mod 63 t2 as t1
mul t1 p0 as t1
or t0 t1 as v4
sub c1 1 as c1
jnz c1 l7
set 1 as c3
label l9
and p3 v8 as t0
eq p2 v7 as t1
or t1 1 as t1
div t0 t1 as t0
xor t0 p2 as v1
set p3 as v6
sub c3 1 as c3
jnz c3 l9
sub c0 1 as c0
jnz c0 l6
shl p2 v8 as t0
shl p0 v8 as t1
and t0 t1 as t0
shl v7 v8 as t1
ge t0 t1 as v8
gt p3 p0 as v1
shr p2 p0 as t0
or 255 1 as t2
mod 4096 t2 as t1
mul t0 t1 as t0
shl v1 p0 as t2
le p1 t2 as t1
or t1 1 as t1
div t0 t1 as v6
set p0 as v4
jle p3 3 l10
set v1 as v3
set 2 as c4
label l11
set 2 as c5
label l12
set p3 as v7
eq v4 p2 as v4
sub c5 1 as c5
jnz c5 l12
set v7 as v4
set v3 as v7
set 6 as v7
sub c4 1 as c4
jnz c4 l11
set -1 as v8
label l10
set 0 as h
add h p0 as h
add h p1 as h
add h p2 as h
add h p3 as h
add h v1 as h
add h v4 as h
add h v6 as h
add h v7 as h
add h v8 as h
mod h 251 as h
ret h
end
call f 312 719 174 460 as r
sys 60 r

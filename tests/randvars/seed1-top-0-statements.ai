or 7 1 as t1
mod 63 t1 as t0
add 5 0 as t1
mul t0 t1 as t0
ge -1 64 as t1
xor t1 -1 as t1
xor t0 t1 as v7
shr v7 255 as t0
ne v7 255 as t1
or t1 1 as t1
div t0 t1 as t0
sub v7 v7 as t1
xor v7 v7 as t2
shl t1 t2 as t1
shr t0 t1 as v3
or v3 1 as t3
div v3 t3 as t2
or t2 1 as t2
div v7 t2 as t1
sub v3 t1 as v9
set 7 as v8
sub 64 4 as t1
add 7 v8 as t2
shl t1 t2 as t1
and v3 t1 as v3
set v7 as v9
or v8 v3 as t0
shr t0 v7 as v2
jne v8 v3 l1
set 4096 as v10
set v3 as v10
set v10 as v4
set 255 as v1
label l1
shr v3 64 as t2
xor v7 t2 as t1
shl v8 t1 as v8
set 0 as h
add h v2 as h
add h v3 as h
add h v7 as h
add h v8 as h
add h v9 as h
mod h 251 as h
sys 60 h

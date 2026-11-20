fn f 
or 255 1 as t1
div 63 t1 as t0
or 0x100000000 1 as t1
div t0 t1 as v16
set v16 as v7
set 1 as c0
label l1
set 3 as c1
label l2
or v16 1 as t2
mod -1 t2 as t1
shr v16 v16 as t2
or t2 1 as t2
mod t1 t2 as t1
shr v16 t1 as v13
set v16 as v9
or v13 1 as t2
mod v7 t2 as t1
or t1 1 as t1
mod v13 t1 as v3
shl v3 v9 as t0
shr t0 v13 as t0
sub t0 v7 as v7
set v16 as v18
sub c1 1 as c1
jnz c1 l2
sub c0 1 as c0
jnz c0 l1
set 2 as c2
label l3
mul v16 v16 as t1
or t1 1 as t1
mod v7 t1 as v4
sub c2 1 as c2
jnz c2 l3
mul v16 v16 as t1
or v7 t1 as t0
or v16 1 as t2
div 0xffffffffffffffff t2 as t1
shr t0 t1 as v0
set 6 as v3
or v3 v3 as t1
sub t1 v7 as t1
or t1 1 as t1
div 0 t1 as v2
set v3 as v8
set 2 as c3
label l4
or v16 1 as t3
div v2 t3 as t2
add -1 t2 as t1
shl v3 t1 as v13
set v13 as v16
set v16 as v17
ge 0x100000000 2 as t1
shr v3 v3 as t2
shr t1 t2 as t1
sub v3 t1 as v16
add 63 v2 as t1
xor t1 v13 as t1
sub v16 t1 as v10
set 3 as c4
label l5
or v17 v0 as t2
shl v8 t2 as t1
or t1 1 as t1
mod 4 t1 as v5
set 3 as c5
label l6
set v7 as v15
set v3 as v18
or v7 1 as t1
div v8 t1 as v9
set v3 as v17
sub c5 1 as c5
jnz c5 l6
sub c4 1 as c4
jnz c4 l5
sub c3 1 as c3
jnz c3 l4
set 0 as h
add h v0 as h
add h v16 as h
add h v2 as h
add h v3 as h
add h v7 as h
add h v8 as h
mod h 251 as h
ret h
end
call f  as r
sys 60 r

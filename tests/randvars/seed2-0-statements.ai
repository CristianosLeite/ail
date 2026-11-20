fn f 
shr 0x100000000 255 as v1
lt v1 -1 as t0
shr t0 v1 as t0
and t0 v1 as v5
lt v5 v5 as t0
xor t0 v5 as t0
and v5 7 as t1
ge v1 0x100000000 as t2
shr t1 t2 as t1
sub t0 t1 as v2
set -1 as v3
and v2 1 as t0
or v2 1 as t2
mod v1 t2 as t1
or t1 1 as t1
mod t0 t1 as t0
mul v3 v1 as t1
shl t1 0 as t1
shl t0 t1 as v5
set -1 as v2
mul 1 v5 as v0
and 4096 v1 as t0
or v1 5 as t1
or t0 t1 as t0
le t0 63 as v4
sub v1 0 as v1
set v4 as v2
set 0 as h
add h v0 as h
add h v1 as h
add h v2 as h
add h v3 as h
add h v4 as h
add h v5 as h
mod h 251 as h
ret h
end
call f  as r
sys 60 r

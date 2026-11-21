# the frame with its slots and locals is released before the jump, and
# the values are read before that
fn g a b c
	add a b as a
	add a c as a
	ret a
end
fn f a b c d e h
	local m 16
	add a b as t1
	add c d as t2
	add e h as t3
	store m t1
	add t1 t2 as u
	add u t3 as u
	load m as v
	tail g u v t3
end
set 1 as p
set 2 as q
call f 1 2 3 4 5 6 as r
add r p as r
add r q as r
sys 60 r

fn g a
	ret a
end
fn f
	set 1 as a
	set 1 as b
	set 1 as c
	set 1 as d
	add a b as a
	add a c as a
	add a d as a
	tail g a
end
set 10 as p
set 20 as q
set 30 as r
set 40 as s
call f as x
add x p as x
add x q as x
add x r as x
add x s as x
sys 60 x

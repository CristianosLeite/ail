# the address of a function, and a call through it
fn inc x
	add x 1 as x
	ret x
end
fn dec x
	sub x 1 as x
	ret x
end
ref inc as p
ref dec as q
callp p 10 as a
callp q 10 as b
mul a 10 as a
add a b as a
sys 60 a

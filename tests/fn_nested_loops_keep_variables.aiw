fn f
	set 0 as s
	set 3 as i
	label a
	set 2 as j
	label b
	set 7 as x
	add s x as s
	set 1 as y
	set 1 as z
	set 1 as w
	add y z as v
	add v w as v
	add s v as s
	sub j 1 as j
	jnz j b
	add s i as s
	sub i 1 as i
	jnz i a
	ret s
end
call f as r
sys 60 r

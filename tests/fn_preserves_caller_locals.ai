# clobber writes all six of its registers; the six variables of each
# caller, at top level and inside a function, must come back unchanged
fn clobber a
	set 91 as b
	set 92 as c
	set 93 as d
	set 94 as e
	set 95 as f
	set 96 as a
	ret a
end
fn inner
	set 1 as a
	set 2 as b
	set 3 as c
	set 4 as d
	set 5 as e
	set 6 as f
	call clobber 0
	mul b 10 as b
	add a b as a
	mul c 100 as c
	add a c as a
	mul d 1000 as d
	add a d as a
	mul e 10000 as e
	add a e as a
	mul f 100000 as f
	add a f as a
	ret a
end
set 6 as a
set 5 as b
set 4 as c
set 3 as d
set 2 as e
set 1 as f
call clobber 0
call inner
mul b 10 as b
add a b as a
mul c 100 as c
add a c as a
mul d 1000 as d
add a d as a
mul e 10000 as e
add a e as a
mul f 100000 as f
add a f as a
eq a 123456 as a
jz a bad
call inner as a
eq a 654321 as a
jz a bad
sys 1 1 "ok\n"
sys 60 0
label bad
sys 60 1

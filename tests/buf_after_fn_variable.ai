# the variable b of the function is gone when the buffer is declared
fn f
	set 7 as b
	ret b
end
buf b 8
store b 3
call f as x
load b as y
add x y as x
sys 60 x

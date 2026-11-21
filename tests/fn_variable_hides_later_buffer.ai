# the same when the buffer is declared after the function
fn f
	set 4 as b
	ret b
end
buf b 8
storeb b 1
call f as x
loadb b as y
add x y as x
sys 60 x

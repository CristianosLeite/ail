# before its as, a name still means the global
buf b 8
fn f
	storeb b 6
	set 1 as b
	ret b
end
call f as x
loadb b as y
add x y as x
sys 60 x

fn two
	ret 30 4
end
fn f
	tail two
end
call f as a b
add a b as a
sys 60 a

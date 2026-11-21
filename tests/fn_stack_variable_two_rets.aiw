# every ret releases the slots
fn f x a b c d e
	add x a as g
	add g b as h
	add h c as i
	jz x z
	add i d as i
	add i e as i
	add i g as i
	add i h as i
	ret i
	label z
	ret 7
end
call f 0 1 1 1 1 1 as p
call f 1 1 1 1 1 1 as q
add p q as p
sys 60 p

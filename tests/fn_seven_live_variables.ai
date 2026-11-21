# seven values in use at once: one is on the stack
fn f a b c d e g
	add a b as h
	add h c as h
	add h d as h
	add h e as h
	add h g as h
	add h a as h
	ret h
end
call f 1 2 3 4 5 6 as r
sys 60 r

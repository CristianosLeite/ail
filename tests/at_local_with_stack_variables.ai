fn f a b c d e g
	local m 16
	add a b as h
	add h c as i
	at m 8 8 as p
	store p i
	at m 0 8 as q
	store q h
	load p as x
	load q as y
	add x y as x
	add x d as x
	add x e as x
	add x g as x
	add x a as x
	ret x
end
call f 1 2 3 4 5 6 as r
sys 60 r

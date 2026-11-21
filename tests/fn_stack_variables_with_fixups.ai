# the first pass leaves no trace: a function whose code moves between the
# passes (two stack slots) uses a later buffer, a later function, data of its
# own and a label
fn f a b c d e g
	add a b as h
	add h c as i
	storeb later h
	call twice i as j
	data own 5
	loadb own as k
	jz a z
	add j k as j
	label z
	add j d as j
	add j e as j
	add j g as j
	add j h as j
	add j i as j
	loadb later as k
	add j k as j
	ret j
end
fn twice x
	add x x as x
	ret x
end
call f 1 2 3 4 5 6 as r
sys 60 r
buf later 8

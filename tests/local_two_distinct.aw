fn f
	local a 3
	local b 8
	sub b a as d
	store b 7
	storeb a 1
	load b as x
	add d x as d
	ret d
end
call f as r
sys 60 r

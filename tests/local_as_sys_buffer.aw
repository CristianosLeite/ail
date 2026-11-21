fn f
	local line 4
	store4 line 0x0a6b6f
	sys 1 1 line 3 as n
	ret n
end
call f as r
sys 60 r

# if with a comparison as its value, for a smaller, an equal and a larger left side,
# also where the order is only right unsigned; exit status = the first wrong one
fn f
	a=3
	b=5
	if a==b
		ret 1
	else
	end
	if a!=b
	else
		ret 2
	end
	if a<b
	else
		ret 3
	end
	if a<=b
	else
		ret 4
	end
	if a>b
		ret 5
	else
	end
	if a>=b
		ret 6
	else
	end
	a=5
	b=5
	if a==b
	else
		ret 7
	end
	if a!=b
		ret 8
	else
	end
	if a<b
		ret 9
	else
	end
	if a<=b
	else
		ret 10
	end
	if a>b
		ret 11
	else
	end
	if a>=b
	else
		ret 12
	end
	a=7
	b=5
	if a==b
		ret 13
	else
	end
	if a!=b
	else
		ret 14
	end
	if a<b
		ret 15
	else
	end
	if a<=b
		ret 16
	else
	end
	if a>b
	else
		ret 17
	end
	if a>=b
	else
		ret 18
	end
	a=0
	b=0xffffffffffffffff
	if a==b
		ret 19
	else
	end
	if a!=b
	else
		ret 20
	end
	if a<b
	else
		ret 21
	end
	if a<=b
	else
		ret 22
	end
	if a>b
		ret 23
	else
	end
	if a>=b
		ret 24
	else
	end
	a=0xffffffffffffffff
	b=0
	if a==b
		ret 25
	else
	end
	if a!=b
	else
		ret 26
	end
	if a<b
		ret 27
	else
	end
	if a<=b
		ret 28
	else
	end
	if a>b
	else
		ret 29
	end
	if a>=b
	else
		ret 30
	end
	a=0xffffffffffffffff
	b=0xffffffffffffffff
	if a==b
	else
		ret 31
	end
	if a!=b
		ret 32
	else
	end
	if a<b
		ret 33
	else
	end
	if a<=b
	else
		ret 34
	end
	if a>b
		ret 35
	else
	end
	if a>=b
	else
		ret 36
	end
	ret 0
end
call f as r
sys exit r

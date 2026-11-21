# the address of a local is a value
fn f n
	local t 32
	store t+8 n*2
	store t+16 n+1
	load t+8 as a
	load t+16 as b
	ret a*b
end
call f 4 as r
sys exit r

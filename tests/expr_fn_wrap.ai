# arithmetic wraps at 64 bits, in a function whose parameters are the values
fn f v0 v1 v2 v3 v4 v5 v6 v7 v8 v9 v10
	jne v0-v1 18446744073709551615 f1
	jne v2+v3 1 f2
	jne v4*v3 0 f3
	jne v5*v5 0 f4
	jne v6-v7 -2 f5
	jne v0-v1>>v8 1 f6
	jne v1<<v8>>v8 1 f7
	jne v0-v9/v3 -4 f8
	jne v2/v3 9223372036854775807 f9
	jne v2%v10 5 f10
	ret 0
	label f1
	ret 1
	label f2
	ret 2
	label f3
	ret 3
	label f4
	ret 4
	label f5
	ret 5
	label f6
	ret 6
	label f7
	ret 7
	label f8
	ret 8
	label f9
	ret 9
	label f10
	ret 10
end
call f 0 1 0xffffffffffffffff 2 0x8000000000000000 0x100000000 3 5 63 8 10 as r
sys exit r

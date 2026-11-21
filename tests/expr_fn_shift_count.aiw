# a shift takes its count modulo 64, in a function whose parameters are the values
fn f v0 v1 v2 v3 v4 v5
	jne v0<<v1 1 f1
	jne v0<<v2 2 f2
	jne v3>>v4 1 f3
	jne v0<<v5 9223372036854775808 f4
	ret 0
	label f1
	ret 1
	label f2
	ret 2
	label f3
	ret 3
	label f4
	ret 4
end
call f 1 64 65 8 67 63 as r
sys exit r

# the comparisons are unsigned and give 1 or 0, in a function whose parameters are the values
fn f v0 v1 v2 v3 v4 v5 v6 v7
	jne v0<v1 1 f1
	jne v1<v0 0 f2
	jne v0<=v0 1 f3
	jne v2<=v0 0 f4
	jne v1>v0 1 f5
	jne v0>v0 0 f6
	jne v0>=v0 1 f7
	jne v3>=v0 0 f8
	jne v4==v4 1 f9
	jne v4==v5 0 f10
	jne v4!=v5 1 f11
	jne v4!=v4 0 f12
	jne v6-v7>v7 1 f13
	jne (v7<v3)+(v3<v0) 2 f14
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
	label f11
	ret 11
	label f12
	ret 12
	label f13
	ret 13
	label f14
	ret 14
end
call f 3 5 4 2 6 7 0 1 as r
sys exit r

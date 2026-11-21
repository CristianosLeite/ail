# the comparisons are unsigned and give 1 or 0; exit status = the first check that fails
v0=3
v1=5
v2=4
v3=2
v4=6
v5=7
v6=0
v7=1
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
sys exit 0
label f1
sys exit 1
label f2
sys exit 2
label f3
sys exit 3
label f4
sys exit 4
label f5
sys exit 5
label f6
sys exit 6
label f7
sys exit 7
label f8
sys exit 8
label f9
sys exit 9
label f10
sys exit 10
label f11
sys exit 11
label f12
sys exit 12
label f13
sys exit 13
label f14
sys exit 14

# parentheses group values that are computed when the program runs; exit status = the first check that fails
v0=2
v1=3
v2=4
v3=1
v4=7
v5=20
v6=5
v7=6
jne (v0+v1)*v2 20 f1
jne v0*(v1+v2) 14 f2
jne ((v0+v1))*((v2)) 20 f3
jne (v3+(v0*(v1+(v2)))) 15 f4
jne (v4) 7 f5
jne v5/(v0+v1) 4 f6
jne (v3<<v2)-(v3<<v0) 12 f7
jne (v0+v1)*(v2+v6)-(v7+v4)*(v3+v3) 19 f8
jne v0-(v1-(v2-(v6-(v7-v4)))) -3 f9
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

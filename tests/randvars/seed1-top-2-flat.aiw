c0=1
label l1
v11=5
v7=v11
c0-=1
jnz c0 l1
t1=64|1
t0=63/t1
v0=t0<<5
t2=v0&v0
t1=v0+t2
v10=7^t1
t1=v0-v10
v6=v0&t1
v10=v10
v8=v0
c1=2
label l2
v10=v0
t0=v8&v10
v5=t0&4
v3=v5
v0=3
v2=v6
v8=v8<=v2
c1-=1
jnz c1 l2
v3=v6==v0
t1=9&v6
t0=v8|t1
t1=v3&v3
v7=t0<t1
h=0
h+=v0
h+=v10
h+=v3
h+=v6
h+=v7
h+=v8
h%=251
sys 60 h

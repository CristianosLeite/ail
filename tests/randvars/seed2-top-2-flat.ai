t1=7*4096
t0=255|t1
t1=255*4
t2=64^63
t1<<=t2
t1|=1
v9=t0%t1
t2=v9-v9
t1=v9*t2
v7=v9-t1
jz v9!=v7 l1
t0=v7==4096
t1=v9-v7
t0|=t1
t2=v7^v7
t1=v7>t2
v14=t0|t1
t0=v7&v14
t1=v14&4096
v21=t0<<t1
c0=3
label l2
v13=v14
c1=3
label l3
v6=v9
v17=0
t1=v17|1
t0=5/t1
v10=t0<<v14
v31=v9>v7
v33=v7
t0=v7|v17
t1=v10*v21
t1-=v33
t1|=1
v5=t0%t1
c1-=1
jnz c1 l3
v24=v14
c2=1
label l4
v12=v7
c2-=1
jnz c2 l4
c3=3
label l5
v24+=v24
t0=v7|4096
t1=0xffffffffffffffff|1
t0/=t1
v26=t0<<v24
v33=v14
v26=v21
t0=v21&3
t0+=v9
t2=v7|1
t1=4096/t2
v18=t0<<t1
v14=0xffffffffffffffff>>0
c3-=1
jnz c3 l5
c4=3
label l6
t1=v7+v24
t2=v13|1
t1%=t2
t1|=1
v13/=t1
v10=v21
v20=0xffffffffffffffff
t0=v20-v10
v29=t0<=v13
v24=v20
c4-=1
jnz c4 l6
c0-=1
jnz c0 l2
jmp l7
label l1
c5=2
label l8
v12=v9
c5-=1
jnz c5 l8
label l7
jz v7>=v7 l9
t0=4|v7
t1=v9>=v9
t0>>=t1
t2=255-v9
t1=v9>=t2
v15=t0^t1
t0=v9-v7
v29=t0-v7
v24=v9
label l9
v19=v7-v9
v9=v9
t1=v19*v9
v15=v7|t1
v27=v9
t0=v7&v27
t0*=v9
t1=v27^v15
t1>>=0xffffffffffffffff
v29=t0>=t1
v22=v15+v19
t2=v22|1
t1=63%t2
v18=v27^t1
v29=v27
h=0
h+=v15
h+=v18
h+=v19
h+=v22
h+=v27
h+=v29
h+=v7
h+=v9
h%=251
sys 60 h

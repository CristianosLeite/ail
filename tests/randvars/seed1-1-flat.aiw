fn f 
t1=255|1
t0=63/t1
t1=0x100000000|1
v16=t0/t1
v7=v16
c0=1
label l1
c1=3
label l2
t2=v16|1
t1=-1%t2
t2=v16>>v16
t2|=1
t1%=t2
v13=v16>>t1
v9=v16
t2=v13|1
t1=v7%t2
t1|=1
v3=v13%t1
t0=v3<<v9
t0>>=v13
v7=t0-v7
v18=v16
c1-=1
jnz c1 l2
c0-=1
jnz c0 l1
c2=2
label l3
t1=v16*v16
t1|=1
v4=v7%t1
c2-=1
jnz c2 l3
t1=v16*v16
t0=v7|t1
t2=v16|1
t1=0xffffffffffffffff/t2
v0=t0>>t1
v3=6
t1=v3|v3
t1-=v7
t1|=1
v2=0/t1
v8=v3
c3=2
label l4
t3=v16|1
t2=v2/t3
t1=-1+t2
v13=v3<<t1
v16=v13
v17=v16
t1=0x100000000>=2
t2=v3>>v3
t1>>=t2
v16=v3-t1
t1=63+v2
t1^=v13
v10=v16-t1
c4=3
label l5
t2=v17|v0
t1=v8<<t2
t1|=1
v5=4%t1
c5=3
label l6
v15=v7
v18=v3
t1=v7|1
v9=v8/t1
v17=v3
c5-=1
jnz c5 l6
c4-=1
jnz c4 l5
c3-=1
jnz c3 l4
h=0
h+=v0
h+=v16
h+=v2
h+=v3
h+=v7
h+=v8
h%=251
ret h
end
call f  as r
sys 60 r

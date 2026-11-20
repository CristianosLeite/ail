v11=-1
c0=2
label l1
c1=1
label l2
jz 3<=v11 l3
t0=v11*v11
t0=t0!=v11
v1=t0|v11
label l3
v11=v11
t1=v11>>v11
t3=v11|1
t2=v11/t3
t1^=t2
t1|=1
v5=4096%t1
t3=v11|1
t2=v11/t3
t1=v11^t2
v16=v11<<t1
c1-=1
jnz c1 l2
v4=v11
v18=v4
t0=8+v18
t0*=255
v9=t0-v18
v16=v9
jz v18<=v16 l4
t1=v11>v18
v6=v11-t1
c2=2
label l5
v12=v16
v5=v4
v10=0xffffffffffffffff
c2-=1
jnz c2 l5
label l4
c0-=1
jnz c0 l1
v14=v11
v17=v11
v10=v14&v17
c3=3
label l6
c4=3
label l7
jz v11>=v14 l8
v10=v14
v11=v11
label l8
c5=1
label l9
v4=v14
v6=v4
c5-=1
jnz c5 l9
jz v11<=v14 l10
v0=v11
v18=v10==v11
t1=3>>v0
t0=v0>=t1
t1=v14>v10
t1|=v14
v11=t0*t1
jmp l11
label l10
v6=v10
t1=v14|1
v12=v6%t1
t1=v11|1
t0=v10/t1
t1=5-v10
t0*=t1
t1=v14>v17
t1+=v6
v7=t0^t1
label l11
c4-=1
jnz c4 l7
jz -1>v14 l12
v6=v11<v10
t0=v10*v6
t1=v17&v10
t0^=t1
v13=t0>>v17
t0=v6^v10
t0^=v10
t1=v17>>7
t1>>=v13
v18=t0^t1
t0=v17>>v17
t0+=v13
t2=v18|1
t1=v13%t2
t2=v17|1
t1%=t2
v4=t0<<t1
jmp l13
label l12
v16=v11
label l13
c3-=1
jnz c3 l6
v6=v17
v4=0x100000000
v0=255
v2=v0
t1=0<<v6
t0=v11<=t1
jz t0 l14
c6=1
label l15
v16=v0
t0=v0^v4
t1=v14>=v10
t0^=t1
v8=t0<<v10
c6-=1
jnz c6 l15
v13=0xffffffffffffffff
v4=v2
label l14
t0=-1>>v10
t1=v10+v4
t0-=t1
t1=v11|1
v8=t0/t1
c7=3
label l16
jz v4!=0x100000000 l17
t1=v17|1
v1=v10%t1
jmp l18
label l17
t1=-1>>v17
t1|=1
t0=v14/t1
t1=2-v14
t1>>=9
v11=t0!=t1
label l18
jz v4==v17 l19
c8=2
label l20
v14=v14
t1=4<v0
t0=v8<<t1
t2=v14+v11
t1=v6<=t2
v17=t0-t1
v0=v8
c8-=1
jnz c8 l20
v17=0x100000000-v14
label l19
v17=v8
t0=v4-v4
t2=v11|1
t1=64/t2
t0*=t1
t2=v17|1
t1=v14/t2
v5=t0-t1
jz v6>v6 l21
t1=0x100000000|1
t0=v11%t1
t1=6+v2
t0+=t1
t1=4096&v4
v6=t0^t1
t1=4096<=v10
t0=v8&t1
t2=v17|1
t1=0x100000000%t2
t2=v0|4
t1>>=t2
v12=t0!=t1
jmp l22
label l21
v10=v5<<v5
label l22
c7-=1
jnz c7 l16
v3=v17*v2
v10=63
v0=v11
h=0
h+=v0
h+=v10
h+=v11
h+=v14
h+=v17
h+=v2
h+=v3
h+=v4
h+=v6
h+=v8
h%=251
sys 60 h

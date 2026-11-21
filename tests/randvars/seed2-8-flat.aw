fn f p0 p1
v11=p1
v13=p1
v20=2
c0=1
label l1
jz v20<=p1 l2
c1=3
label l3
v21=p0
c1-=1
jnz c1 l3
jz v11!=p1 l4
t1=p1!=p0
v4=v20^t1
t1=0x100000000+v11
t0=v20^t1
t1=v20+v11
t2=p1<<p0
t1^=t2
v3=t0!=t1
t1=v4<v20
v13=v13<=t1
v19=p0
label l4
jmp l5
label l2
v22=p1
label l5
t0=v11|0xffffffffffffffff
t0&=p0
t2=v13+1
t2|=1
t1=0xffffffffffffffff/t2
v21=t0<<t1
c0-=1
jnz c0 l1
jz v11<p1 l6
v2=-1
jz p0>=v20 l7
v13=3
c2=1
label l8
v22=v20
v23=v11<<63
c2-=1
jnz c2 l8
jz p1<=v20 l9
v14=v13
jmp l10
label l9
v5=v2
label l10
label l7
label l6
jz 0x100000000==v20 l11
jz v11<=v13 l12
v21=v11
label l12
t1=p1-2
v12=p1|t1
c3=2
label l13
t2=v13|1
t1=0x100000000%t2
t0=p0<<t1
v25=t0|v12
jz p1!=v20 l14
t1=255<<0xffffffffffffffff
t0=v13^t1
v7=t0&0xffffffffffffffff
t0=v7-p1
t1=v13<<v20
t1|=1
t0%=t1
v21=t0<v11
jmp l15
label l14
t2=v12|1
t1=64/t2
t1&=v20
v14=v11*t1
t1=v12|1
t0=-1%t1
t1=v20!=64
t0*=t1
t1=p1>>v14
t1-=v12
v9=t0&t1
t0=v25*0xffffffffffffffff
t0=t0>63
t2=v14>>v20
t2|=1
t1=p0%t2
v23=t0&t1
label l15
v21=7
t0=8^v20
t1=v11|1
v25=t0%t1
v11=p1
c3-=1
jnz c3 l13
t1=v20-v20
t3=v11|1
t2=v11%t3
t1<<=t2
v7=v13<<t1
label l11
t1=v11|1
t0=v11/t1
t1=255-0x100000000
t0=t0>t1
v7=t0==v11
t1=63+p0
t2=v7-63
t1-=t2
t1|=1
v19=p1%t1
t1=v13*v19
t2=64+8
t1-=t2
v19=6>t1
jz v13>p1 l16
t0=v20&255
t1=v13>v20
t0>>=t1
t2=4|1
t1=p0%t2
t3=4|1
t2=p0%t3
t1-=t2
v24=t0&t1
t0=p0>v19
t1=4096^v7
t0>>=t1
v16=t0^v13
v16=1
jmp l17
label l16
t1=v20|1
v9=p1%t1
label l17
t1=v7-v13
t1|=1
t0=p1%t1
v6=t0|v11
v0=v11^v7
v1=v7
jz v19>3 l18
t1=v1&v7
t0=p0<<t1
v9=t0>v19
label l18
t0=v0^v20
t1=v19&v7
t2=v13*v11
t1<<=t2
v1=t0&t1
t1=63>>p1
t0=v0<=t1
t1=v19*7
t1|=4
v4=t0<<t1
v16=3
v20=v16
v20=v4
v24=v7
v5=v20
t1=3>>p0
t0=1<<t1
v5=t0|v20
t2=p1|1
t1=v7%t2
t2=v5|v6
t1=t1<=t2
t1|=1
v0%=t1
v19*=v0
h=0
h+=p0
h+=p1
h+=v0
h+=v1
h+=v11
h+=v13
h+=v16
h+=v19
h+=v20
h+=v24
h+=v4
h+=v5
h+=v6
h+=v7
h%=251
ret h
end
call f 173 46 as r
sys 60 r

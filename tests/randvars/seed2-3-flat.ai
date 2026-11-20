fn f p0 p1 p2 p3
t0=p1&p3
t1=2>>p0
t1>>=p0
v10=t0-t1
c0=2
label l1
v5=v10
v3=p1^v5
v7=v3
c0-=1
jnz c0 l1
jz p2>=p2 l2
jz p1 l3
v7=63
t1=v7*8
t2=v7|1
t1/=t2
v10=0xffffffffffffffff<<t1
v3=v7
jmp l4
label l3
v9=255
c1=2
label l5
t1=p2^p1
t0=v9<<t1
t2=p2|1
t1=p0%t2
t2=p2&p3
t1|=t2
t1|=1
v5=t0/t1
v0=v9
t1=p3^v10
t0=p3-t1
t1=p3>>64
t2=p1-p0
t1|=t2
v1=t0<t1
t0=v0^0xffffffffffffffff
t0=t0!=p0
t1=p0|1
v6=t0/t1
c1-=1
jnz c1 l5
t0=p3>>p0
t1=p1|1
t0/=t1
v5=t0+p2
label l4
jmp l6
label l2
jz v10<p3 l7
v7=v10
label l7
label l6
v8=p1
v10=p2
v1=p1
t0=0<<v1
t1=0^p2
t0^=t1
v3=t0+p1
v10=p0
c2=1
label l8
t0=p3>>64
t1=v10&p2
t0<<=t1
v7=t0<<p2
v10*=v1
t1=p2<=p0
t0=0x100000000^t1
v2=t0^p0
c3=2
label l9
v6=1
c3-=1
jnz c3 l9
v8>>=p0
c2-=1
jnz c2 l8
c4=1
label l10
v6=7
v7=v6
c4-=1
jnz c4 l10
v8=v8
t1=v3|1
t0=p1%t1
v7=t0^v1
t0=0xffffffffffffffff!=4096
jz t0 l11
v9=v8
jz v8<v7 l12
c5=2
label l13
t1=v1>5
t2=v10^v1
t1=t1>=t2
t1|=1
v10=p1/t1
t2=v1-p2
t1=v7+t2
v7>>=t1
c5-=1
jnz c5 l13
jmp l14
label l12
v8=6
label l14
t2=v8&v10
t1=v8>>t2
t1|=1
v5=v9%t1
t1=v3>>p1
t2=v5^v1
t1+=t2
v10=v8<<t1
jmp l15
label l11
t0=v7>>v8
t1=p3+p0
t0=t0<=t1
jz t0 l16
v4=8+1
label l16
t1=p1-63
t0=p0*t1
v6=t0|v3
label l15
h=0
h+=p0
h+=p1
h+=p2
h+=p3
h+=v1
h+=v10
h+=v3
h+=v7
h+=v8
h%=251
ret h
end
call f 344 557 24 0 as r
sys 60 r

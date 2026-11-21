fn f p0 p1 p2 p3
t1=p2|1
t0=p0%t1
t1=0+p0
t0*=t1
t2=8|1
t1=p3/t2
t1<<=p3
v7=t0^t1
jz 1 l1
t2=p3|1
t1=7%t2
t0=p3<<t1
v5=t0>v7
t1=p3|1
t0=p3/t1
jz t0 l2
t2=0x100000000|1
t1=v5/t2
v9=p0-t1
label l2
t2=v5|1
t1=6/t2
t1|=1
v8=7/t1
jmp l3
label l1
t1=p0>>p1
t0=1>>t1
v3=t0-p1
t0=p2|p0
v2=t0>>p1
jz p3==v3 l4
t0=v2*6
t1=4<<4
t1|=1
t0/=t1
t1=v7>>4096
v8=t0<<t1
t2=p3>>64
t1=v3^t2
v9=v7&t1
jmp l5
label l4
v10=v2
t1=p3|1
v10/=t1
label l5
label l3
t1=p0|p3
v8=v7&t1
c0=1
label l6
c1=3
label l7
t1=p0>>0x100000000
t0=v7>>t1
t1=v7<<p0
t2=p0-p3
t1+=t2
t1|=1
v9=t0%t1
c2=1
label l8
v4=p0&p2
v5=p1
t1=v4&v4
v5=v5==t1
v1=v5<<v4
t1=p1|1
v1=p3%t1
c2-=1
jnz c2 l8
t1=p1|1
t0=2/t1
t1=v9+4
t1|=1
t0/=t1
t2=3|1
t1=63%t2
t1*=p0
v4=t0|t1
c1-=1
jnz c1 l7
c3=1
label l9
t0=p3&v8
t1=p2==v7
t1|=1
t0/=t1
v1=t0^p2
v6=p3
c3-=1
jnz c3 l9
c0-=1
jnz c0 l6
t0=p2<<v8
t1=p0<<v8
t0&=t1
t1=v7<<v8
v8=t0>=t1
v1=p3>p0
t0=p2>>p0
t2=255|1
t1=4096%t2
t0*=t1
t2=v1<<p0
t1=p1<=t2
t1|=1
v6=t0/t1
v4=p0
jz p3>3 l10
v3=v1
c4=2
label l11
c5=2
label l12
v7=p3
v4=v4==p2
c5-=1
jnz c5 l12
v4=v7
v7=v3
v7=6
c4-=1
jnz c4 l11
v8=-1
label l10
h=0
h+=p0
h+=p1
h+=p2
h+=p3
h+=v1
h+=v4
h+=v6
h+=v7
h+=v8
h%=251
ret h
end
call f 312 719 174 460 as r
sys 60 r

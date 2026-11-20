fn f p0 p1 p2
v7=p1
jz v7>v7 l1
v9=v7
c0=2
label l2
t1=p1-v7
t0=0x100000000<t1
jz t0 l3
v2=p1
v7=v7
label l3
t0=4096>>p0
t0+=v7
t1=4096*p2
t2=p0*p2
t1=t1<t2
v5=t0*t1
v1=63
jz 64==v7 l4
v0=v7+p1
v6=8
label l4
c0-=1
jnz c0 l2
c1=3
label l5
jz v7==v9 l6
t1=p2*0x100000000
v3=p0+t1
jmp l7
label l6
v7=p2
t2=p0|1
t1=p1%t2
t2=p2+0xffffffffffffffff
t1-=t2
t1|=1
v9/=t1
label l7
v4=v7
c1-=1
jnz c1 l5
v6=2-v7
label l1
v9=p2&64
jz p2<p1 l8
jz p1<=v9 l9
t0=p0&0xffffffffffffffff
t1=p1|p2
t0+=t1
t1=p0|1
v0=t0/t1
label l9
c2=2
label l10
c3=2
label l11
v8=p2
v7=v9
c3-=1
jnz c3 l11
c4=1
label l12
t1=v9&p0
t2=63>>p1
t2|=1
t1/=t2
v8=v9-t1
v7=v8
t1=p2!=p1
t3=v8|1
t2=5%t3
t1&=t2
v0=v7-t1
t1=p0+p2
t1=t1<=p2
v9=v9<t1
t1=v7|1
v3=p0%t1
v4=p2
c4-=1
jnz c4 l12
v5=-1
t1=p2|1
t0=-1%t1
t1=p2|1
t0%=t1
t1=p2==p0
v8=t0>t1
t0=v7==v5
t1=v9+v5
t0=t0==t1
jz t0 l13
v4=0xffffffffffffffff
t0=v9>=v9
t1=v9<<v4
t0+=t1
v6=t0<<v9
v3=63<p0
jmp l14
label l13
v4=p0
v6=v4
t1=p0|v4
t0=v5+t1
t1=p1|v7
t1=t1>v4
v6=t0*t1
label l14
c2-=1
jnz c2 l10
jmp l15
label l8
t1=p2-p0
t1|=v7
v6=v7-t1
c5=3
label l16
t1=p1|1
t0=v9%t1
t1=p1<p0
t0<<=t1
jz t0 l17
v3=4096
label l17
c5-=1
jnz c5 l16
label l15
v8=8
jz p1 l18
v9=p0
v1=p2
label l18
t0=p0*v7
t1=v7>>63
t1<<=p2
t1|=1
v8=t0/t1
v0=v8
v1=v8
v0>>=4096
t0=p1-p1
t1=1&1
t0=t0!=t1
v8=t0*p2
c6=2
label l19
jz v0==4096 l20
jz p2!=7 l21
v5=v1
v7=3
t1=64&v5
t0=0-t1
t2=p0&v1
t2|=1
t1=v1/t2
v4=t0-t1
t0=4096>>v4
t1=v8<<v8
t0^=t1
t1=v0+v4
t2=p1+p0
t1|=t2
t1|=1
v4=t0%t1
label l21
v6=v1
t3=0xffffffffffffffff|1
t2=v1/t3
t2|=1
t1=p2%t2
v3=v6<<t1
t0=p0*v0
t0*=v9
t1=v3|1
v5=t0/t1
label l20
jz p1>=p0 l22
v9=p0
v2=3
jz v1<-1 l23
v3=v8
t1=6<<v1
t2=p0^v1
t2|=1
t1/=t2
t1|=1
v7=7%t1
t0=63*4096
t0&=v3
t1=p1^v9
t2=p0&v7
t2|=1
t1/=t2
v8=t0*t1
t0=v1|255
t0-=3
v5=t0<<4096
label l23
label l22
c6-=1
jnz c6 l19
v6=v8
v4=p1&5
jz 0x100000000!=p0 l24
t1=p2+p1
t1|=1
t0=p0/t1
v6=t0!=v4
v8=v7
jmp l25
label l24
t0=v9-v7
t1=p0&v7
t0^=t1
t2=v9|1
t1=p0%t2
t2=1<<p0
t1-=t2
v3=t0|t1
v9|=v1
c7=2
label l26
v9=p1
jz 4096 l27
v3=v7&v3
v4=v3
t2=p2|v0
t1=v3*t2
t1|=1
v7=p0/t1
t1=v9|1
v0=v9%t1
label l27
c7-=1
jnz c7 l26
label l25
v0=v1
v8=v4
t1=v0-p2
t0=v1+t1
t2=v8>=v9
t1=v7>>t2
v0=t0!=t1
c8=1
label l28
v2=9-v7
jz v9<=v0 l29
jz 0xffffffffffffffff l30
t2=p0^v9
t1=v7>>t2
v6=p0+t1
v3=255
jmp l31
label l30
t0=v2&v0
t1=v8>=3
t0+=t1
t1=p1<<v1
v0=t0^t1
v4=v8
label l31
v3=v2
jmp l32
label l29
c9=1
label l33
v3=v4<<9
t1=v1<<v1
t2=63|0
t1>>=t2
v0=2>>t1
c9-=1
jnz c9 l33
v9=v2
v4=v7<<p1
label l32
c8-=1
jnz c8 l28
c10=3
label l34
t1=v4<<v4
t1<<=p0
t1|=1
v1=v7%t1
t0=p1|64
t1=v4&p1
t0=t0<t1
t2=p2>>v7
t2|=1
t1=v8/t2
t1|=1
v0=t0/t1
c10-=1
jnz c10 l34
c11=1
label l35
v0=p2
c11-=1
jnz c11 l35
v0=v9
t2=v6|1
t1=4%t2
t0=v1&t1
v4=t0*v8
jz v6>=v0 l36
v2=p1
t1=v4|1
v7/=t1
t0=4096*p0
v9=t0>>2
t1=v0-v9
t0=p0+t1
v7=t0|v2
jmp l37
label l36
v6=v7
t1=p2>v9
t1+=v8
v0=p2>>t1
label l37
h=0
h+=p0
h+=p1
h+=p2
h+=v0
h+=v1
h+=v4
h+=v6
h+=v7
h+=v8
h+=v9
h%=251
ret h
end
call f 44 259 183 as r
sys 60 r

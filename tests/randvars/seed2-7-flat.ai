fn f p0 p1 p2 p3
v14=p2
t0=p3+p0
t2=p0|1
t1=p3/t2
t0>>=t1
t1=p2+0x100000000
t1|=1
v6=t0/t1
t0=p1>>v14
t0*=0
v18=t0+63
jz v6<v6 l1
jz v6<=v18 l2
v19=p1
t1=p2|1
v2=v19/t1
t1=3*0xffffffffffffffff
v14=v18<<t1
v14=v14
label l2
v3=64|p1
v4=v6*v6
t1=v18>v18
t2=p3^v18
t1^=t2
v7=v14<<t1
jmp l3
label l1
v17=v14
v8=p0
label l3
v16=v14
v1=p2
v10=63
v2=255
jz v2==v6 l4
t1=255|1
v18%=t1
c0=2
label l5
v18=63
v11=p1
c0-=1
jnz c0 l5
v13=v18>>v6
t2=v13|1
t1=v2%t2
t0=v1>>t1
v10=t0>=1
jmp l6
label l4
v5=v14
label l6
jz p0 l7
v0=0xffffffffffffffff
t2=v6>=p1
t2|=1
t1=v16%t2
t1|=1
v11=v14%t1
label l7
c1=1
label l8
v7=p0
t1=v2|1
t0=p2%t1
t1=7|1
t0%=t1
jz t0 l9
v7=v16
t0=v14<<p0
t0>>=v2
v9=t0>v14
v2=v16
jmp l10
label l9
v12=v2
v0=p1
label l10
t1=v14*4096
t0=p1>>t1
v3=t0>v18
c2=3
label l11
t2=255^v3
t2|=1
t1=v18%t2
v8=v6>>t1
t0=p2<=8
t0*=v6
t2=v18+v8
t2|=1
t1=v7%t2
v18=t0+t1
v8=p3
c2-=1
jnz c2 l11
c1-=1
jnz c1 l8
c3=3
label l12
jz v2>=9 l13
t1=v16&0
t2=v10&v16
t1-=t2
v8=p2<<t1
t1=p2|1
v18=p2%t1
t0=v16-v6
t1=v1^p3
t0|=t1
v15=t0&v18
label l13
t1=3<4096
t1|=1
v14%=t1
v4=p0>v1
v0=v14
c4=1
label l14
t0=v0<<v6
t1=v2>>v18
t0>>=t1
v2=t0>>v14
c4-=1
jnz c4 l14
v14=v16
c3-=1
jnz c3 l12
v19=v6
v0=64
t1=v2+v16
v19=p1|t1
t1=9+1
t2=7^7
t1^=t2
v18|=t1
t0=v10&64
t1=0x100000000|1
t0/=t1
v19=t0-v6
t0=7*-1
t0=t0<=v1
v16=t0<<v6
c5=3
label l15
t2=1|1
t1=p1%t2
t0=6<<t1
v7=t0>>v1
v1=v0^v14
c6=3
label l16
t1=v0|1
t0=p3%t1
t2=5>p1
t2|=1
t1=p3/t2
v19=t0>>t1
jz v0!=v16 l17
v16=v18
t0=v14+v10
t1=v10-64
t0^=t1
t1=v2*v2
t1-=4
t1|=1
v17=t0/t1
t1=v10<<-1
t0=7*t1
t1=5^v0
t1=t1>v7
v13=t0&t1
label l17
t1=v16*63
v4=p1<<t1
c6-=1
jnz c6 l16
v16=v0
v1=p1
t1=v19*v18
t1|=1
t0=v19%t1
jz t0 l18
v7=p2
v11=4096<p3
label l18
c5-=1
jnz c5 l15
v6=v0
c7=1
label l19
v14=0
c7-=1
jnz c7 l19
c8=1
label l20
t1=7>v18
t2=9^8
t1^=t2
v5=v6-t1
c8-=1
jnz c8 l20
h=0
h+=p0
h+=p1
h+=p2
h+=p3
h+=v0
h+=v1
h+=v10
h+=v14
h+=v16
h+=v18
h+=v19
h+=v2
h+=v6
h%=251
ret h
end
call f 651 652 125 791 as r
sys 60 r

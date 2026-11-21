fn f p0 p1 p2 p3
v14=p2
v6=(p3+p0>>p3/(p0|1))/((p2+0x100000000)|1)
v18=(p1>>v14)*0+63
if v6<v6
if v6<=v18
v19=p1
v2=v19/(p2|1)
v14=(v18<<3*0xffffffffffffffff)
v14=v14
end
v3=64|p1
v4=v6*v6
v7=v14<<((v18>v18)^(p3^v18))
else
v17=v14
v8=p0
end
v16=v14
v1=p2
v10=63
v2=255
if v2==v6
v18%=255|1
c0=2
while c0
v18=63
v11=p1
c0-=1
end
v13=v18>>v6
v10=v1>>v2%(v13|1)>=1
else
v5=v14
end
if p0
v0=0xffffffffffffffff
v11=v14%(v16%((v6>=p1)|1)|1)
end
c1=1
while c1
v7=p0
if p2%(v2|1)%(7|1)
v7=v16
v9=(v14<<p0>>v2)>v14
v2=v16
else
v12=v2
v0=p1
end
v3=(p1>>v14*4096>v18)
c2=3
while c2
v8=v6>>(v18%(255^v3|1))
v18=(p2<=8)*v6+v7%(v18+v8|1)
v8=p3
c2-=1
end
c1-=1
end
c3=3
while c3
if v2>=9
v8=p2<<((v16&0)-(v10&v16))
v18=p2%(p2|1)
v15=(v16-v6|v1^p3)&v18
end
v14%=(3<4096)|1
v4=p0>v1
v0=v14
c4=1
while c4
v2=v0<<v6>>(v2>>v18)>>v14
c4-=1
end
v14=v16
c3-=1
end
v19=v6
v0=64
v19=p1|v2+v16
v18|=9+1^(7^7)
v19=(v10&64)/(0x100000000|1)-v6
v16=((7*-1<=v1)<<v6)
c5=3
while c5
v7=(6<<p1%(1|1))>>v1
v1=(v0^v14)
c6=3
while c6
v19=(p3%(v0|1))>>p3/((5>p1)|1)
if (v0!=v16)
v16=v18
v17=((v14+v10)^v10-64)/(v2*v2-4|1)
v13=(7*(v10<<-1)&(5^v0>v7))
end
v4=p1<<v16*63
c6-=1
end
v16=v0
v1=p1
if v19%(v19*v18|1)
v7=p2
v11=4096<p3
end
c5-=1
end
v6=v0
c7=1
while c7
v14=0
c7-=1
end
c8=1
while c8
v5=v6-((7>v18)^(9^8))
c8-=1
end
h=(p0+p1+p2+p3+v0+v1+v10+v14+v16+v18+v19+v2+v6)%251
ret h
end
call f 651 652 125 791 as r
sys 60 r

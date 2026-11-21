fn f p0 p1 p2 p3
v7=p0%(p2|1)*(0+p0)^(p3/(8|1)<<p3)
if 1
v5=p3<<7%(p3|1)>v7
if p3/(p3|1)
v9=p0-v5/(0x100000000|1)
end
v8=7/(6/(v5|1)|1)
else
v3=(1>>(p0>>p1))-p1
v2=(p2|p0)>>p1
if p3==v3
v8=v2*6/(4<<4|1)<<(v7>>4096)
v9=v7&(v3^p3>>64)
else
v10=v2
v10=v10/(p3|1)
end
end
v8=v7&(p0|p3)
c0=1
while c0
c1=3
while c1
v9=(v7>>(p0>>0x100000000))%((v7<<p0)+(p0-p3)|1)
c2=1
while c2
v4=p0&p2
v5=p1
v5=v5==v4&v4
v1=v5<<v4
v1=p3%(p1|1)
c2-=1
end
v4=2/(p1|1)/(v9+4|1)|(63%(3|1))*p0
c1-=1
end
c3=1
while c3
v1=(p3&v8)/((p2==v7)|1)^p2
v6=p3
c3-=1
end
c0-=1
end
v8=p2<<v8&(p0<<v8)>=v7<<v8
v1=p3>p0
v6=(p2>>p0)*(4096%(255|1))/((p1<=v1<<p0)|1)
v4=p0
if p3>3
v3=v1
c4=2
while c4
c5=2
while c5
v7=p3
v4=v4==p2
c5-=1
end
v4=v7
v7=v3
v7=6
c4-=1
end
v8=-1
end
h=(p0+p1+p2+p3+v1+v4+v6+v7+v8)%251
ret h
end
call f 312 719 174 460 as r
sys 60 r

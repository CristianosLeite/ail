t1=2>7
t1|=1
t0=9/t1
v34=t0<<0x100000000
v23=6
t0=v34>v34
t1=v34|v34
t0|=t1
v12=t0*v23
v7=6
t0=v7&v7
t1=v23>>v34
t0&=t1
t1=v23+64
t1+=v12
v1=t0*t1
jz v23>=v23 l1
v18=v34
v33=v12
jz v7>=63 l2
v1=v18-v23
v35=v34
jmp l3
label l2
v12=v34
t2=v7|1
t1=v1%t2
v33=v33>=t1
c0=3
label l4
t0=1<<v23
t1=v23+4096
t1|=1
t0/=t1
t1=v1|1
v31=t0%t1
v22=v34
v8=v34
v9=v1
t0=v31>>v9
t1=v12^v22
t0-=t1
v34=t0<<v18
c0-=1
jnz c0 l4
label l3
v2=v12
label l1
v7=6
t0=5<<v12
t1=v12&v12
t0-=t1
v21=t0|v34
v21=v34
t0=v12+4096
v20=t0>>255
v1=v1
jz v12 l5
t1=v20-v34
v30=v12&t1
t1=v20|1
v21=v12%t1
v7=v34
v30=v30>8
jmp l6
label l5
v6=v1*7
c1=3
label l7
v30=v1
t1=v20|1
v34=v21/t1
v29=v21
t0=v21-v21
t0-=v30
v21=t0>=v23
c1-=1
jnz c1 l7
v17=v23
label l6
t0=v34<<v20
t1=9!=v12
t3=0xffffffffffffffff|1
t2=0xffffffffffffffff/t3
t1*=t2
v8=t0*t1
v13=v23
c2=3
label l8
t0=v23*v34
t1=v13<<v7
t0+=t1
t1=v7<<v7
t2=v7+v13
t1=t1<=t2
v26=t0*t1
v19=v1>>v23
t3=v1|1
t2=v8/t3
t1=v21<<t2
v21|=t1
v25=v23|v1
v5=v23*v21
c2-=1
jnz c2 l8
v31=v1<<v23
t1=64*v12
t0=v21-t1
t3=v1|1
t2=0%t3
t1=64&t2
v3=t0+t1
t0=v13^v7
t1=64*255
t1&=v7
v34=t0==t1
v35=v3
t0=v13^v23
t1=-1|1
v17=t0/t1
c3=3
label l9
v28=v13
c4=1
label l10
t0=v21>>v1
t1=v8*v3
t0=t0<=t1
t2=v3<<v20
t1=v21>>t2
t1|=1
v11=t0%t1
jz v8 l11
v24=v3
t1=v20|1
t0=v17/t1
t0=t0>=v20
v5=t0<=255
jmp l12
label l11
t1=v8-v11
t0=5+t1
t1=v20+v23
t2=v1|1
t1%=t2
v16=t0^t1
t1=v34|1
t0=v3%t1
t1=v21<<v31
t2=v21<<v7
t1|=t2
v30=t0*t1
t2=3|1
t1=v16%t2
t2=v23<<v1
t2|=1
t1%=t2
v17-=t1
label l12
c4-=1
jnz c4 l10
v23=0xffffffffffffffff|v28
t0=v13+v20
t1=v28*v13
t0*=t1
jz t0 l13
c5=1
label l14
v6=v12<<v7
v8=3
v1=v12
c5-=1
jnz c5 l14
t0=63+v20
t2=v7|1
t1=v17/t2
t0-=t1
t1=v34<<v21
t1+=v3
v31=t0|t1
jmp l15
label l13
v2=255
label l15
c3-=1
jnz c3 l9
v17=9+-1
v15=v23
v20=v21
v16=v21
v8=v34
t0=v15<<v20
t1=v16-9
t0*=t1
t2=0xffffffffffffffff>>64
t1=v21<t2
v9=t0^t1
v33=v13
t1=v9+v17
v16=v16<=t1
c6=3
label l16
t2=v17|1
t1=8/t2
t1=t1!=v34
v2=v34>>t1
c6-=1
jnz c6 l16
jz v31<=4096 l17
v3=v7
v16=v35
v30=v3
jmp l18
label l17
c7=1
label l19
v4=v8*v31
c7-=1
jnz c7 l19
label l18
c8=2
label l20
t1=v1|1
v33=v23/t1
c8-=1
jnz c8 l20
v11=v17
t0=v11>>v16
jz t0 l21
t1=v33-v12
t1<<=0xffffffffffffffff
v7=v17>>t1
label l21
h=0
h+=v1
h+=v11
h+=v12
h+=v13
h+=v15
h+=v16
h+=v17
h+=v20
h+=v21
h+=v23
h+=v3
h+=v31
h+=v33
h+=v34
h+=v35
h+=v7
h+=v8
h+=v9
h%=251
sys 60 h

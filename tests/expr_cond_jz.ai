# jz with a comparison as its value, for a smaller, an equal and a larger left side,
# also where the order is only right unsigned; exit status = the first wrong one
a=3
b=5
jz a==b t1
sys exit 1
label t1
label e1
jz a!=b t2
jmp e2
label t2
sys exit 2
label e2
jz a<b t3
jmp e3
label t3
sys exit 3
label e3
jz a<=b t4
jmp e4
label t4
sys exit 4
label e4
jz a>b t5
sys exit 5
label t5
label e5
jz a>=b t6
sys exit 6
label t6
label e6
a=5
b=5
jz a==b t7
jmp e7
label t7
sys exit 7
label e7
jz a!=b t8
sys exit 8
label t8
label e8
jz a<b t9
sys exit 9
label t9
label e9
jz a<=b t10
jmp e10
label t10
sys exit 10
label e10
jz a>b t11
sys exit 11
label t11
label e11
jz a>=b t12
jmp e12
label t12
sys exit 12
label e12
a=7
b=5
jz a==b t13
sys exit 13
label t13
label e13
jz a!=b t14
jmp e14
label t14
sys exit 14
label e14
jz a<b t15
sys exit 15
label t15
label e15
jz a<=b t16
sys exit 16
label t16
label e16
jz a>b t17
jmp e17
label t17
sys exit 17
label e17
jz a>=b t18
jmp e18
label t18
sys exit 18
label e18
a=0
b=0xffffffffffffffff
jz a==b t19
sys exit 19
label t19
label e19
jz a!=b t20
jmp e20
label t20
sys exit 20
label e20
jz a<b t21
jmp e21
label t21
sys exit 21
label e21
jz a<=b t22
jmp e22
label t22
sys exit 22
label e22
jz a>b t23
sys exit 23
label t23
label e23
jz a>=b t24
sys exit 24
label t24
label e24
a=0xffffffffffffffff
b=0
jz a==b t25
sys exit 25
label t25
label e25
jz a!=b t26
jmp e26
label t26
sys exit 26
label e26
jz a<b t27
sys exit 27
label t27
label e27
jz a<=b t28
sys exit 28
label t28
label e28
jz a>b t29
jmp e29
label t29
sys exit 29
label e29
jz a>=b t30
jmp e30
label t30
sys exit 30
label e30
a=0xffffffffffffffff
b=0xffffffffffffffff
jz a==b t31
jmp e31
label t31
sys exit 31
label e31
jz a!=b t32
sys exit 32
label t32
label e32
jz a<b t33
sys exit 33
label t33
label e33
jz a<=b t34
jmp e34
label t34
sys exit 34
label e34
jz a>b t35
sys exit 35
label t35
label e35
jz a>=b t36
jmp e36
label t36
sys exit 36
label e36
sys exit 0

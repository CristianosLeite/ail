# jnz with a comparison as its value, for a smaller, an equal and a larger left side,
# also where the order is only right unsigned; exit status = the first wrong one
a=3
b=5
jnz a==b t1
jmp e1
label t1
sys exit 1
label e1
jnz a!=b t2
sys exit 2
label t2
label e2
jnz a<b t3
sys exit 3
label t3
label e3
jnz a<=b t4
sys exit 4
label t4
label e4
jnz a>b t5
jmp e5
label t5
sys exit 5
label e5
jnz a>=b t6
jmp e6
label t6
sys exit 6
label e6
a=5
b=5
jnz a==b t7
sys exit 7
label t7
label e7
jnz a!=b t8
jmp e8
label t8
sys exit 8
label e8
jnz a<b t9
jmp e9
label t9
sys exit 9
label e9
jnz a<=b t10
sys exit 10
label t10
label e10
jnz a>b t11
jmp e11
label t11
sys exit 11
label e11
jnz a>=b t12
sys exit 12
label t12
label e12
a=7
b=5
jnz a==b t13
jmp e13
label t13
sys exit 13
label e13
jnz a!=b t14
sys exit 14
label t14
label e14
jnz a<b t15
jmp e15
label t15
sys exit 15
label e15
jnz a<=b t16
jmp e16
label t16
sys exit 16
label e16
jnz a>b t17
sys exit 17
label t17
label e17
jnz a>=b t18
sys exit 18
label t18
label e18
a=0
b=0xffffffffffffffff
jnz a==b t19
jmp e19
label t19
sys exit 19
label e19
jnz a!=b t20
sys exit 20
label t20
label e20
jnz a<b t21
sys exit 21
label t21
label e21
jnz a<=b t22
sys exit 22
label t22
label e22
jnz a>b t23
jmp e23
label t23
sys exit 23
label e23
jnz a>=b t24
jmp e24
label t24
sys exit 24
label e24
a=0xffffffffffffffff
b=0
jnz a==b t25
jmp e25
label t25
sys exit 25
label e25
jnz a!=b t26
sys exit 26
label t26
label e26
jnz a<b t27
jmp e27
label t27
sys exit 27
label e27
jnz a<=b t28
jmp e28
label t28
sys exit 28
label e28
jnz a>b t29
sys exit 29
label t29
label e29
jnz a>=b t30
sys exit 30
label t30
label e30
a=0xffffffffffffffff
b=0xffffffffffffffff
jnz a==b t31
sys exit 31
label t31
label e31
jnz a!=b t32
jmp e32
label t32
sys exit 32
label e32
jnz a<b t33
jmp e33
label t33
sys exit 33
label e33
jnz a<=b t34
sys exit 34
label t34
label e34
jnz a>b t35
jmp e35
label t35
sys exit 35
label e35
jnz a>=b t36
sys exit 36
label t36
label e36
sys exit 0

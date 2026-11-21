# jz with a comparison as its value, for a smaller, an equal and a larger left side,
# also where the order is only right unsigned; exit status = the first wrong one
fn f
	a=3
	b=5
	jz a==b t1
	ret 1
	label t1
	label e1
	jz a!=b t2
	jmp e2
	label t2
	ret 2
	label e2
	jz a<b t3
	jmp e3
	label t3
	ret 3
	label e3
	jz a<=b t4
	jmp e4
	label t4
	ret 4
	label e4
	jz a>b t5
	ret 5
	label t5
	label e5
	jz a>=b t6
	ret 6
	label t6
	label e6
	a=5
	b=5
	jz a==b t7
	jmp e7
	label t7
	ret 7
	label e7
	jz a!=b t8
	ret 8
	label t8
	label e8
	jz a<b t9
	ret 9
	label t9
	label e9
	jz a<=b t10
	jmp e10
	label t10
	ret 10
	label e10
	jz a>b t11
	ret 11
	label t11
	label e11
	jz a>=b t12
	jmp e12
	label t12
	ret 12
	label e12
	a=7
	b=5
	jz a==b t13
	ret 13
	label t13
	label e13
	jz a!=b t14
	jmp e14
	label t14
	ret 14
	label e14
	jz a<b t15
	ret 15
	label t15
	label e15
	jz a<=b t16
	ret 16
	label t16
	label e16
	jz a>b t17
	jmp e17
	label t17
	ret 17
	label e17
	jz a>=b t18
	jmp e18
	label t18
	ret 18
	label e18
	a=0
	b=0xffffffffffffffff
	jz a==b t19
	ret 19
	label t19
	label e19
	jz a!=b t20
	jmp e20
	label t20
	ret 20
	label e20
	jz a<b t21
	jmp e21
	label t21
	ret 21
	label e21
	jz a<=b t22
	jmp e22
	label t22
	ret 22
	label e22
	jz a>b t23
	ret 23
	label t23
	label e23
	jz a>=b t24
	ret 24
	label t24
	label e24
	a=0xffffffffffffffff
	b=0
	jz a==b t25
	ret 25
	label t25
	label e25
	jz a!=b t26
	jmp e26
	label t26
	ret 26
	label e26
	jz a<b t27
	ret 27
	label t27
	label e27
	jz a<=b t28
	ret 28
	label t28
	label e28
	jz a>b t29
	jmp e29
	label t29
	ret 29
	label e29
	jz a>=b t30
	jmp e30
	label t30
	ret 30
	label e30
	a=0xffffffffffffffff
	b=0xffffffffffffffff
	jz a==b t31
	jmp e31
	label t31
	ret 31
	label e31
	jz a!=b t32
	ret 32
	label t32
	label e32
	jz a<b t33
	ret 33
	label t33
	label e33
	jz a<=b t34
	jmp e34
	label t34
	ret 34
	label e34
	jz a>b t35
	ret 35
	label t35
	label e35
	jz a>=b t36
	jmp e36
	label t36
	ret 36
	label e36
	ret 0
end
call f as r
sys exit r

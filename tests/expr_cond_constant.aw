# a comparison of constants is computed by the compiler
c=0
if 2<3
	c+=1
end
ifz 2<3
	c+=2
end
jnz 1==1 l
c+=4
label l
sys exit c

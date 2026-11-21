# in a function, with more variables than registers alive across the loop
fn f a b c d e g
	h=a+b
	i=c+d
	j=e+g
	k=0
	n=0
	while n<4
		k+=a+b+c+d+e+g+h+i+j+n
		n+=1
	end
	ret k
end
call f 1 2 3 4 5 6 as r
sys exit r

# the values of the comparison may live in stack slots
fn f a b c d e g
	h=a+b
	i=c+d
	j=e+g
	k=h+i
	if k+j>=h*i
		ret a+b+c+d+e+g+h+i+j+k
	end
	ret 0
end
call f 1 2 3 4 5 6 as r
sys exit r

# a variable read at the top of a loop keeps its register to the end of the
# loop, though it is not mentioned again: the next round reads it
fn f a b c d e g
	s=0
	n=3
	while n
		s+=a+b+c+d+e+g
		h=n*2
		i=h+1
		j=i+h
		k=j+i
		s+=k
		n-=1
	end
	ret s
end
call f 1 2 3 4 5 6 as r
sys exit r

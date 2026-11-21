# two loops after each other reuse places, and a variable of the first is done before the second
fn f n
	s=0
	i=0
	while i<n
		t=i*2
		s+=t
		i+=1
	end
	j=0
	while j<n
		u=j+s
		s=u
		j+=1
	end
	ret s
end
call f 5 as r
sys exit r

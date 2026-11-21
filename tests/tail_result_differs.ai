# a tail is a return: its target gives as many results as the rets of
# the function it stands in
fn one a
	ret a
end
fn two a
	if a
		ret a a
	end
	tail one a
end
call two 1 as x y
sys exit y

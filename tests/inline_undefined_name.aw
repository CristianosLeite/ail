# a fault in a body that is compiled in place of its calls is reported
# once, at its line in the function
fn f
	x=late+1
	ret x
end
fn g
	call f as y
	ret y
end
call g as r
sys exit r

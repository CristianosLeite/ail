# a fault in a body that is compiled in place of its calls is reported
# once, at its line in the function
buf b 8
fn f
	storeb b+8 1
end
fn g
	call f
	call f
end
call g

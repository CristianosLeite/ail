# a fault in a body that is compiled in place of its calls is reported
# once, at its line in the function
fn f
	call nowhere
end
fn g
	call f
	call f
end
call g

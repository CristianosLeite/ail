# a function that returns through tail has the results of its target:
# a second name after "as" would take a register the target left
fn single a b
	ret a
end
fn wrap a b
	tail single a b
end
call wrap 5 37 as a b
sys exit b

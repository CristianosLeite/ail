use "tests/lib/twice.aw"
fn quad x
	call twice x as x
	call twice x as x
	ret x
end

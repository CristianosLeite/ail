use "tests/lib/twice.aw"
fn six x
	call twice x as y
	add y x as y
	call twice y as y
	ret y
end

# top-level execution runs around the bodies, also at the end of the source
sys 1 1 "a\n"
fn one
	sys 60 1
end
sys 1 1 "b\n"
fn two
	sys 60 2
end
fn three
	sys 60 3
end

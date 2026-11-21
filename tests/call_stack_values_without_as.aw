var out
fn f a b c d e g h
	set h as out
end
call f 0 0 0 0 0 0 9
call f 0 0 0 0 0 0 8
add out 1 as r
sys 60 r

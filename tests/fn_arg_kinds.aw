# a buffer name, a variable and a number as arguments
buf b 8
fn f p v n
	store p v
	load p as r
	add r n as r
	ret r
end
set 30 as v
call f b v 12 as x
sys 60 x

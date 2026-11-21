# a frame of many pages: the first and the last byte are usable, and the
# stack parameters and the return still line up
fn f a b c d e g h i
	local big 300000
	store big a
	add big 299992 as p
	store p i
	load big as x
	load p as y
	add x y as x
	add x h as x
	ret x
end
set 5 as keep
call f 1 0 0 0 0 0 30 4 as r
add r keep as r
sys 60 r

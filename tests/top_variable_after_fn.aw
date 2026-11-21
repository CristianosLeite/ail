# the function does not disturb the count of top-level variables
set 1 as a
set 1 as b
set 1 as c
set 1 as d
set 1 as e
set 6 as g
fn f
	set 1 as z
	ret z
end
set 7 as h
call f as i
add g h as r
add r i as r
sys 60 r

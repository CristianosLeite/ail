# a source for tests/infix.sh: every rewrite of tools/infix.aw, and what
# it must leave alone
var g
buf b 64
fn f a b
add a b as t
mul t 2 as u
sub u a as u        # a comment keeps its line
ret u
end
set 0 as i
set 0 as s
label loop
jge i 8 done
mul i 8 as o
add b o as p
store p i
load p as v
add s v as s
iflt v 3
add s 1 as s
else
shr s 0 as s
end
add i 1 as i
jmp loop
label done
set 5 as k
label down
sub k 1 as k
jnz k down
add s k as g
div s 2 as q
mod s 2 as r
sys write 1 "x" as w
add q r as q
add q w as q
sdiv q 2 as q
jslt q 0 neg
call f q 3 as z
sub z q as z
sys exit z
label neg
sys exit 1

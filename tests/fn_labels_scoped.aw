# x is three different labels; the first jump is recorded before the
# functions and resolved after them
jmp x
sys 60 1
fn f a
	jz a x
	ret 1
	label x
	ret 10
end
label x
fn g a
	jz a x
	ret 2
	label x
	ret 20
end
call f 0 as r
call g 0 as s
add r s as r
jmp y
sys 60 3
label y
sys 60 r

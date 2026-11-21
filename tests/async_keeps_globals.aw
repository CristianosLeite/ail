# a var of the program declared before the use keeps its value: every
# variable of the library has a name that starts with async
var a b c f h k n p r s t v w x z
use "lib/async/task.aw"
fn poll u
	call asyncwake u
	load u+64 as m
	store u+64 m+1
	ifz m
		ret 0
	end
	store u+16 m
	ret 1
end
a=1
b=1
c=1
f=1
h=1
k=1
n=1
p=1
r=1
s=1
t=1
v=1
w=1
x=1
z=1
ref poll as q
call async 72 q as g
store g+64 0
call async 20000 0 as e
call asyncfinish e 0
call await e 0
call asyncyield as y
call await y 0
call await g 0 as d
sys exit_group a+b+c+f+h+k+n+p+r+s+t+v+w+x+z+d

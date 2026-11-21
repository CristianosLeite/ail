# a short function whose body calls through an address is compiled in
# place like any other: the variables of the caller, in registers and on
# the stack, live across that call, its results are taken, and the values
# it pushed are off the stack afterwards
use "lib/io.aw"
fn sum8 a b c d e f g h
	ret a+b+c+d+e+f+g+h a*h
end
fn twice x
	ret x*2
end
# one value: called through p with x
fn ap p x
	callp p x as r
	ret r+1
end
# eight values, two of them on the stack, and two results
fn ap8 p x y
	callp p x y x y x y x y as s t
	ret s t
end
fn out n
	call putn n
	call print " "
end
fn run
	ref twice as q
	ref sum8 as w
	a=1
	b=2
	c=3
	d=4
	e=5
	f=6
	g=7
	h=8
	i=0
	z=0
	while i<4
		call ap q i+a as r
		call ap8 w r h as s t
		z+=r+s+t+a+b+c+d+e+f+g+h
		i+=1
	end
	call out z
	call out a+b+c+d+e+f+g+h
	call ap q g as g
	call ap8 w g b as b a
	call out g
	call out b
	call out a
end
call run
call print "\n"

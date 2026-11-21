# a function that names a var, a buf or data, or calls another function,
# is compiled in place of its calls like any short one: the names are
# the global ones also where the caller has a variable of that name, an
# access is checked, a call in the body is a call, of a function that
# stands later too, and one that calls itself goes on calling itself
use "lib/io.aw"
var total
buf box 16
data tab 3 5 7
fn bump n
	total+=n
end
fn third i
	loadb tab+i as v
	ret v
end
fn put i v
	store box+i*8 v
end
fn twice n
	call bump n
	call bump n
	ret total
end
fn later n
	call after n as m
	ret m+1
end
fn fact n
	ifz n
		ret 1
	end
	call fact n-1 as m
	ret n*m
end
fn all box tab
	total=box+tab
	call put 0 11
	call put 1 22
	call third 2 as a
	call twice a as b
	call later b as c
	call fact 5 as d
	ret a+b+c+d
end
fn after n
	ret n*2
end
call all 1 2 as r
load box as p
load box+8 as q
call putn r
call print " "
call putn total
call print " "
call putn p+q
call print "\n"

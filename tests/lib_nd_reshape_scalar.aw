# an array without axes that ndscalar made keeps its element in its own
# 176 bytes, where the lengths of an array with axes are: lengths given
# to it in its place are refused and the element stays; as another array
# it gets them
use "lib/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "tests/lib/ndshow.aw"
buf k 176
buf v 176
buf sh 16
itof 5 as x
call ndscalar k x
store sh 1
store sh+8 1
call ndreshape k k 1 sh as s
call show k
call ndreshape k k 2 sh as t
call show k
call ndreshape k k 0 sh as u
call show k
call ndreshape v k 2 sh as w
call show v
load v+16 as n
call ndreshape v v 1 sh as y
call show v
call ndreshape v v 0 sh as z
call show v
call putn s+t+u
call putn w+y+z
call putn n
call print "\n"

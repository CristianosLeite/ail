# lengths whose product or whose bytes do not fit are refused, also
# beside an axis without elements, as is storage the kernel has not got,
# and the array stays what it was
use "lib/io.aw"
use "lib/nd/array.aw"
buf a 176
buf sh 24
buf ix 8
buf m 8
call ndvec a 2 as r
store ix 1
call ndset a ix 42 as s
load a as p
store sh 0x1000000000000000
call ndnew a 1 sh as t
store sh 0x100000000
store sh+8 0x100000000
call ndnew a 2 sh as u
store sh 18446744073709551615
store sh+8 0
call ndnew a 2 sh as v
call ndwrap a m 8 2 sh as w
store sh 0x0ffffffffffffff
call ndnew a 1 sh as x
store sh 0x40000000
store sh+8 0x40000000
store sh+16 0x4000
call ndwrap a m 8 3 sh as y
call ndmat a 0x100000000 0x10000000 as z
load a as q
call ndget a ix as e f
call ndsize a as n
call putn e
call putn n
call putn t+u+v+w+x+y+z
call print "\n"
call ndfree a
sys exit r+s+(p==q)+f

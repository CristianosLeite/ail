# with the memory of the process limited to 64 MiB an array of 128 MiB
# is refused and the one that was there keeps its elements; a smaller
# one is still made
use "lib/std/io.aw"
use "lib/nd/array.aw"
const setrlimit 160
buf lim 16
buf a 176
buf b 176
buf ix 16
store lim 0x4000000
store lim+8 0x4000000
sys setrlimit 9 lim as r
if r
	sys exit 1
end
call ndvec a 1000 as r
store ix 999
call ndset a ix 7 as s
load a as p
call ndvec a 0x1000000 as t
call ndmat a 4096 4096 as u
call ndvec b 0x1000000 as v
load a as q
call ndget a ix as x f
call ndsize a as n
load b+8 as w
call ndvec b 0x100000 as y
store ix 0xfffff
call ndset b ix 1 as z
call ndfree b
call ndfree a
call putn x
call putn n
call putn t+u+v+w
call print "\n"
sys exit r+s+(p==q)+f+y+z

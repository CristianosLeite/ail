# a product without elements writes nothing, also where the result is
# bytes at the address 0: no rows, no columns, and nothing to add over.
# A result of 2^40 rows without columns is done at once, on one thread
# and in tasks, and not after a walk over its rows
use "lib/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "lib/task.aw"
use "lib/nd/par.aw"
use "tests/lib/ndshow.aw"
buf a 176
buf b 176
buf c 176
buf sh 16
# 2 by 3 times 3 by 0 gives 2 by 0
call ndmat a 2 3 as r
call ramp a 4 4
store sh 3
store sh+8 0
call ndwrap b 0 0 2 sh as r
store sh 2
call ndwrap c 0 0 2 sh as r
call ndmatmul c a b as s
call ndmatmulp c a b 4 as t
# 0 by 3 times 3 by 2 gives 0 by 2
call ndfree a
store sh 0
store sh+8 3
call ndwrap a 0 0 2 sh as r
call ndmat b 3 2 as r
store sh+8 2
call ndwrap c 0 0 2 sh as r
call ndmatmul c a b as u
call ndmatmulp c a b 4 as v
call ndfree b
# 2^40 by 0 times 0 by 0 gives 2^40 by 0
store sh 0x10000000000
store sh+8 0
call ndwrap a 0 0 2 sh as r
call ndwrap c 0 0 2 sh as r
store sh 0
call ndwrap b 0 0 2 sh as r
call ndmatmul c a b as y
call ndmatmulp c a b 4 as z
# 2 by 0 times 0 by 2 gives 2 by 2 of zeros
store sh 2
store sh+8 0
call ndwrap a 0 0 2 sh as r
store sh 0
store sh+8 2
call ndwrap b 0 0 2 sh as r
call ndmat c 2 2 as r
itof 7 as x
call ndfill c x
call ndmatmul c a b as w
call show c
call putn s+t+u+v+w
call putn r+y+z
call print "\n"
call ndfree c
sys exit_group 0

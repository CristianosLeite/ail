# a request whose length would not fit in 64 bits is refused and leaves
# the buffer as it was, as is one the kernel has no memory for
use "lib/io.aw"
use "lib/bytes.aw"
buf b 24
call byadd b "x" as a
load b as p
load b+16 as c
call byneed b 18446744073709551615 as r
call byadd b p -1 as s
call byneed b 0x7fffffffffff0000 as t
load b as q
load b+8 as n
load b+16 as d
call byadd b "y" as u
load b as q
load b+8 as m
call print q m
sys exit a+u+r+s+t+(p==q)+(c==d)+(n==1)

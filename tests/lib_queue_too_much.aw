# room whose bytes would not fit in 64 bits is refused, as is room the
# kernel has no memory for, and the queue stays all zero; room for no
# value is a queue that is always full; a freed queue is given room again
use "lib/io.aw"
use "lib/queue.aw"
buf q 32
call queueinit q 0x2000000000000000 as a
call queueinit q 18446744073709551615 as b
call queueinit q 0x0fffffffffffe000 as c
load q as p
load q+8 as n
call queueinit q 0 as d
call queuepush q 1 as e
call queuepop q as x f
call queuefree q
load q as o
load q+8 as m
call queueinit q 2 as g
call queuepush q 5 as h
call queuepush q 6 as i
call queuepush q 7 as j
call queuepop q as x k
call putn x
call print "\n"
call queuefree q
call queuefree q
sys exit a+b+c+p+n+e+f+o+m+j+d+g+h+i+k

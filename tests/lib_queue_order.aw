# values leave in the order they came, a value of 0 like any other; a
# full queue takes no more and an empty one gives 0 and 0
use "lib/io.aw"
use "lib/queue.aw"
buf q 32
call queuepush q 9 as a
call queuepop q as x b
call queueinit q 3 as c
call queuepop q as x d
call queuepush q 0 as e
call queuepush q 18446744073709551615 as f
call queuepush q 7 as g
call queuepush q 8 as h
load q+24 as n
call putn n
call queuepop q as x i
call print " "
call putn x
call queuepop q as x j
call print " "
call putn x
call queuepop q as x k
call print " "
call putn x
call queuepop q as x l
call print " "
call putn x
call print "\n"
call queuefree q
sys exit a+b+d+h+l+c+e+f+g+i+j+k

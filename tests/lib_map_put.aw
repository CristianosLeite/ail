# a key has the value put last; the key 0, the value 0 and the largest of
# both are like any other; a key that is not there gives 0 and 0, in an
# empty map too, and is not taken out
use "lib/io.aw"
use "lib/map.aw"
buf m 32
call mapget m 0 as x a
call mapdel m 0 as b
call mapput m 0 0 as c
call mapput m 18446744073709551615 18446744073709551615 as d
call mapput m 5 50 as e
call mapput m 5 51 as f
load m+16 as n
call putn n
call mapget m 0 as x g
call print " "
call putn x
call mapget m 5 as x h
call print " "
call putn x
call mapget m 18446744073709551615 as x i
call print " "
call putn x
call mapget m 6 as x j
call mapdel m 6 as k
call mapdel m 0 as l
call mapget m 0 as x o
load m+16 as n
call print " "
call putn n
call print "\n"
call mapfree m
sys exit a+b+j+k+o+x+c+d+e+f+g+h+i+l

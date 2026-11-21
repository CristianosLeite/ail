# values come back by index and off the end in the reverse order, a value
# of 0 like any other; an empty vector and an index too far give 0 and 0
use "lib/std/io.aw"
use "lib/std/vec.aw"
buf v 24
call vecpop v as x a
call vecget v 0 as y b
call vecpush v 7 as c
call vecpush v 0 as d
call vecpush v 18446744073709551615 as e
call vecget v 1 as x f
call vecget v 3 as y g
call vecset v 1 5 as h
call vecset v 3 5 as i
call vecget v 1 as y j
call putn y
call print " "
load v+8 as n
call putn n
s=a+b+g+i+x
call vecpop v as x a
call print " "
call putn x
call vecpop v as x b
call print " "
call putn x
call vecpop v as x g
call print " "
call putn x
call vecpop v as x i
call print " "
call putn x
call print "\n"
sys exit s+c+d+e+f+h+j+a+b+g+i

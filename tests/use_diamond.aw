# two files use a third: it is compiled once
use "tests/lib/quad.aw"
use "tests/lib/six.aw"
call quad 1 as a
call six 1 as b
add a b as a
sys 60 a

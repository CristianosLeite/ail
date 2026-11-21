# a var of the program keeps its value: every variable of the library has
# a name that starts with "vec"
var v n i x p cap len old ok
use "lib/std/io.aw"
use "lib/std/vec.aw"
buf b 24
v=1
n=1
i=1
x=1
p=1
cap=1
len=1
old=1
ok=1
call vecreserve b 10
call vecpush b 5
call vecset b 0 6
call vecget b 0
call vecreserve b 1000
call vecpop b
call vecfree b
sys exit v+n+i+x+p+cap+len+old+ok

# a var of the program keeps its value: every variable of the library has
# a name that starts with "proc"
var n e s i c d l p q z pid st pf fd r argv
use "lib/std/io.aw"
use "lib/std/proc.aw"
data t "/bin/true" 0
buf av 16
n=1
e=1
s=1
i=1
c=1
d=1
l=1
p=1
q=1
z=1
pid=1
st=1
pf=1
fd=1
r=1
argv=1
store av t
call procstart av -1 -1 -1 as x
call procwait x 5000 as y
call procvar "PATH" as a b
call procenv as f
sys exit n+e+s+i+c+d+l+p+q+z+pid+st+pf+fd+r+argv+y

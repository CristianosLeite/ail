# a var of the program keeps its value: every variable of the library has
# a name that starts with "map"
var m k v p c h d s t x n q i f u new
use "lib/io.aw"
use "lib/map.aw"
buf b 32
m=1
k=1
v=1
p=1
c=1
h=1
d=1
s=1
t=1
x=1
n=1
q=1
i=1
f=1
u=1
new=1
call mapput b 1 2
call mapput b 1 3
call mapget b 1
call mapdel b 1
call mapget b 1
call mapfree b
sys exit m+k+v+p+c+h+d+s+t+x+n+q+i+f+u+new

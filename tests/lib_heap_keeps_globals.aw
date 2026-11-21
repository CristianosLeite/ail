# a var of the program keeps its value: every variable of the library has
# a name that starts with "heap"
var h x i p c y z n r
use "lib/io.aw"
use "lib/vec.aw"
use "lib/heap.aw"
buf b 24
h=1
x=1
i=1
p=1
c=1
y=1
z=1
n=1
r=1
call heappush b 5
call heappush b 2
call heappush b 7
call heappeek b
call heappop b
call heappop b
call heapfree b
sys exit h+x+i+p+c+y+z+n+r

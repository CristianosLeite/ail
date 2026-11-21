# a var of the program keeps its value: every variable of the library has
# a name that starts with "queue"
var q n p c i x h
use "lib/io.aw"
use "lib/queue.aw"
buf b 32
q=1
n=1
p=1
c=1
i=1
x=1
h=1
call queueinit b 2
call queuepush b 5
call queuepush b 6
call queuepop b
call queuepop b
call queuefree b
sys exit q+n+p+c+i+x+h

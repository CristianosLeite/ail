# the stack at start: the count, the arguments, a null, the environment
args as p
load p as n
add p 16 as q
load q as z
add n z as n
sys exit n

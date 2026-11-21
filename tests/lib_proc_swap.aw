# the three descriptors of a child may be one another's: with 2 as its
# output and 1 as its error output the child writes "out" to the error
# output of this process and "err" to its output; a descriptor that is
# not open is a child that ends with 127 and runs nothing
use "lib/std/io.aw"
use "lib/std/bytes.aw"
use "lib/std/file.aw"
use "lib/std/proc.aw"
const dup 32
const dup2 33
data sh "/bin/sh" 0
data c "-c" 0
data s "echo out; echo err >&2" 0
buf av 32
buf b 24
store av sh
store av+8 c
store av+16 s
call fileopen "build/tests/lib_proc_swap.1" 0x241 420 as o
call fileopen "build/tests/lib_proc_swap.2" 0x241 420 as e
sys dup 1 as k1
sys dup 2 as k2
sys dup2 o 1
sys dup2 e 2
call procstart av -1 2 1 as p
call procwait p 5000 as r
call procstart av -1 99 -1 as p
call procwait p 5000 as r2
sys dup2 k1 1
sys dup2 k2 2
call print "1:"
call fileread "build/tests/lib_proc_swap.1" b
load b as q
load b+8 as n
call print q n
store b+8 0
call print "2:"
call fileread "build/tests/lib_proc_swap.2" b
load b as q
load b+8 as n
call print q n
call fileunlink "build/tests/lib_proc_swap.1"
call fileunlink "build/tests/lib_proc_swap.2"
call putn r
call putn r2
call print "\n"

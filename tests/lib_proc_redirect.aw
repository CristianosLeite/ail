# the child reads the file given as its input and writes to the two
# files given as its output and its error output
use "lib/std/io.aw"
use "lib/std/bytes.aw"
use "lib/std/file.aw"
use "lib/std/proc.aw"
data sh "/bin/sh" 0
data c "-c" 0
data s "cat; echo to stderr >&2" 0
buf av 32
buf b 24
store av sh
store av+8 c
store av+16 s
call fileopen "tests/lib/words.txt" 0 0 as i
call fileopen "build/tests/lib_proc_redirect.out" 0x241 420 as o
call fileopen "build/tests/lib_proc_redirect.err" 0x241 420 as e
call procstart av i o e as p
sys close i
sys close o
sys close e
call procwait p 5000 as r
call fileread "build/tests/lib_proc_redirect.err" b
call fileread "build/tests/lib_proc_redirect.out" b
load b as q
load b+8 as n
call print q n
call fileunlink "build/tests/lib_proc_redirect.out"
call fileunlink "build/tests/lib_proc_redirect.err"
sys exit r

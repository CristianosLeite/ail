# a file is added to what the buffer holds, and its length returned
use "lib/std/io.aw"
use "lib/std/bytes.aw"
use "lib/std/file.aw"
buf b 24
call byadd b "> "
call fileread "tests/lib/words.txt" b as r
load b as p
load b+8 as n
call print p n
sys exit r

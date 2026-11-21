# a plain file, which epoll does not watch, is read at once
use "lib/io.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
use "lib/async/io.aw"
buf rb 8
data path "/proc/self/exe" 0
sys open path 0 as fd
call asyncread fd rb 4 as h
call await h 0 as n
call print rb+1 n-1
call print "\n"
call asyncclose fd as r
sys exit_group n+r

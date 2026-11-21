sys mmap 0 4096 3 34 -1 0 as p
storeb p 7
loadb p as x
sys munmap p 4096 as r
add x r as x
sys exit_group x

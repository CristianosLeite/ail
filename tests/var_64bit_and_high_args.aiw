# n = 34 is MAP_PRIVATE|MAP_ANONYMOUS, z = 0; mmap takes them in r10, r8, r9
sys 1 1 "this line is thirty-four bytes ok\n" as n
sys 1 1 "" as z
sys 9 0 4096 3 n z z as p
sys 1 1 p 1          # the mapping is zero-filled: prints one NUL
sys 60 n

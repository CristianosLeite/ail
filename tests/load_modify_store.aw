# read a byte, change it and write it back
buf b 8
storeb b 104
loadb b as c
sub c 32 as c
storeb b c
add b 1 as p
storeb p 10
sys 1 1 b 2

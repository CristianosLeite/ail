# zero-filled, writable to the last byte, and gone after free
alloc 100000 as p
loadb p as z
add p 99999 as q
storeb q 7
loadb q as x
add x z as x
free p
sys 60 x

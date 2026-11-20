# a buffer plus or minus a number is an address
buf b 16
storeb b+7 9
storeb 1+b+11-4 20
loadb b+7 as x
loadb b+8 as y
add x y as x
sys exit x

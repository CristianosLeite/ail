# buffers of almost 2 GiB together: the image still fits a 32-bit distance,
# and only the pages that are touched take memory
buf a 0x40000000
buf b 0x3fe00000
storeb a 1
add b 0x3fdfffff as p
storeb p 2
loadb a as x
loadb p as y
add x y as x
sys exit x

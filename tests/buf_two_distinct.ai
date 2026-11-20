# sizes round up to 8 bytes, so the second buffer starts 8 after the first
buf a 3
buf b 8
store2 a 0x6261         # "ab"
add a 2 as p
storeb p 0x63           # "c": the third and last byte of a
store b 10
sub b a as d
sys 1 1 a 9             # a..a+7 then the first byte of b
sys 60 d

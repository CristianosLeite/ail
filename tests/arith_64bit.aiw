# 4294967295 * 4294967295 = 0xFFFFFFFE00000001: every step below gives a
# wrong answer if anything is truncated to 32 bits
set 4294967295 as m
mul m m as p
shr p 32 as h         # 0xFFFFFFFE
sub m h as d          # 1
shl d 40 as big
shr big 34 as s       # 64
add s d as s
sys 60 s

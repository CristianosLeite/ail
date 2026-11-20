# the distance between two data bytes shows the size of the mov between
# them: 5 bytes for 32 bits, 7 sign-extended, 10 for 64 bits. With the
# 5-byte jump over each data byte and the bytes themselves that is 40.
data a 1
set 1 as v
data b 1
set -1 as v
data c 1
set 0x100000000 as v
data d 1
sub d a as n
sys 60 n

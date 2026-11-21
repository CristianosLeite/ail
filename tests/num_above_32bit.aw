# 4294967296 no longer wraps to zero
set 4294967296 as a
shr a 32 as a
set 4294967295 as b
shr b 31 as b
add a b as a
sys 60 a

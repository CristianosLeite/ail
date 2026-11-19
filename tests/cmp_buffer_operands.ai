# buffer addresses compare as values: 1011 = 11
set 0 as r
buf a 8
buf b 8
lt a b as t    # 1
shl r 1 as r
or r t as r
gt a b as t    # 0
shl r 1 as r
or r t as r
eq a a as t    # 1
shl r 1 as r
or r t as r
ne a b as t    # 1
shl r 1 as r
or r t as r
sys 60 r

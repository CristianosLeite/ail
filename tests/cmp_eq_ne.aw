# one bit per comparison, first one highest: 1010 = 10
set 0 as r
eq 5 5 as t    # 1
shl r 1 as r
or r t as r
eq 5 6 as t    # 0
shl r 1 as r
or r t as r
ne 5 6 as t    # 1
shl r 1 as r
or r t as r
ne 5 5 as t    # 0
shl r 1 as r
or r t as r
sys 60 r

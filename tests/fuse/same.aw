# a jump with a string or a comment opens no block, and a line that ends
# with CR and LF stays as it is
buf b 8
jz "x" bad
sys exit 3
label bad
set 1 as x # one
jz x end1 # two
sys exit 4
label end1
eq x 1 as t
jz t l
label l
sys exit 5

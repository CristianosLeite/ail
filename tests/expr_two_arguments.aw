# an expression has no space: 5 -1 is two values, 5-1 one
sub 5 -1 as a
jne a 6 bad
sys exit 5-1
label bad
sys exit 99

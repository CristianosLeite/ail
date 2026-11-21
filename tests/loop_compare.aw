# sum of 0..9, leaving the loop when the comparison turns 0
set 0 as i
set 0 as s
label top
add s i as s
add i 1 as i
lt i 10 as c
jnz c top
sys 60 s

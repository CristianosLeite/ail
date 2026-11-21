# a shift of constants takes its count modulo 64, like the instruction
jne 1<<64 1 f1
jne 1<<65 2 f2
jne 8>>67 1 f3
jne 1<<63 9223372036854775808 f4
sys exit 0
label f1
sys exit 1
label f2
sys exit 2
label f3
sys exit 3
label f4
sys exit 4

# arithmetic of constants wraps at 64 bits as it does when it runs
jne 0-1 18446744073709551615 f1
jne 0xffffffffffffffff+2 1 f2
jne 0x8000000000000000*2 0 f3
jne 0x100000000*0x100000000 0 f4
jne 3-5 -2 f5
jne 0-1>>63 1 f6
jne 1<<63>>63 1 f7
jne 0-8/2 -4 f8
jne 0xffffffffffffffff/2 9223372036854775807 f9
jne 0xffffffffffffffff%10 5 f10
sys exit 0
label f1
sys exit 1
label f2
sys exit 2
label f3
sys exit 3
label f4
sys exit 4
label f5
sys exit 5
label f6
sys exit 6
label f7
sys exit 7
label f8
sys exit 8
label f9
sys exit 9
label f10
sys exit 10

buf b 8
sys read 0 b 8 as n
jne n 8 fail
load b as x
i=100000000
while i
	x=(x^x>>13)*1664525+1013904223
	i-=1
end
store b x
sys write 1 b 8 as n
jne n 8 fail
sys exit 0
label fail
sys exit 1

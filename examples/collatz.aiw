# add up the lengths of the Collatz sequences that start at 1 to n, an
# 8-byte number read from stdin (at most 10000000), and write the sum
# as 8 bytes; exit status 1 on failure
buf b 8
sys read 0 b 8 as n
jne n 8 fail
load b as n
jgt n 10000000 fail
c=0
while n
	x=n
	while x!=1
		c+=1
		if x%2
			x=x*3+1
		else
			x/=2
		end
	end
	n-=1
end
store b c
sys write 1 b 8 as n
jne n 8 fail
sys exit 0
label fail
sys exit 1

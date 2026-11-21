# fill 30000 numbers from a seed of 8 bytes read from stdin, sort them
# by insertion (sortins of lib/algo/sort.aw) and write a 64-bit checksum
# of the order as 8 bytes;
# exit status 1 on failure
use "lib/algo/sort.aw"
const count 30000
buf b 8
buf a 240000
sys read 0 b 8 as n
jne n 8 fail
load b as x
i=0
while i<count
	x=x*0x5851f42d4c957f2d+0x14057b7ef767814f
	store a+i*8 x>>33
	i+=1
end
call sortins a count
n=0
i=0
while i<count
	load a+i*8 as v
	n=n*31+v
	i+=1
end
store b n
sys write 1 b 8 as n
jne n 8 fail
sys exit 0
label fail
sys exit 1

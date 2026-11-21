# the result may be where a value was read, both are read before
# anything is written; the 16 bytes may start at any address, and what
# lies around them stays as it was
use "lib/std/io.aw"
buf m 64
buf k 16
fn show p n
	i=0
	while i<n
		load p+i*8 as x
		ftoi x as x
		call putn x
		call print " "
		i+=1
	end
	call print "\n"
end
i=0
while i<8
	itof i+1 as x
	store m+i*8 x
	i+=1
end
itof 10 as x
store k x
store k+8 x
# 3 4 become 30 40, then 2 3 become 2+3 and 3+4 with the 3 read first
pmul m+16 m+16 k
call show m 8
padd m+8 m+8 m+16
call show m 8
# shifted by one byte the bits are no numbers, but they come back
padd m+1 m+1 m+33
psub m+1 m+1 m+33
call show m 8
pmadd m+48 m+48 m+48
pdiv m+32 m+48 m+32
call show m 8

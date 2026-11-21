# what is known of an address is forgotten at the head of a loop
buf b 16
p=b+16
i=0
while i<2
	if i
		storeb p 9
	end
	p-=8
	i+=1
end
loadb b+8 as x
sys exit x

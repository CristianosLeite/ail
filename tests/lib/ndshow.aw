# tests/lib/ndshow.aw -- print arrays in the tests of lib/nd; needs
# lib/io.aw and lib/nd/array.aw.

# print the double shwx times 100 as a whole number and a blank
fn showx shwx
	itof 100 as shwc
	fmul shwx shwc as shwx
	ftoi shwx as shwn
	slt shwn 0 as shws
	if shws
		call print "-"
		shwn=0-shwn
	end
	call putn shwn
	call print " "
end

# print every element of the array shwd so, the last index fastest, and
# end the line
fn show shwd
	local shwc 176
	call ndcopy shwc shwd as shwok
	ifz shwok
		call print "no array\n"
		ret 0
	end
	call ndsize shwc as shwn
	load shwc as shwp
	shwi=0
	while shwi<shwn
		load shwp+shwi*8 as shwx
		call showx shwx
		shwi+=1
	end
	call print "\n"
	call ndfree shwc
	ret 1
end

# make the elements of the array shwd, which lie one behind the other,
# the numbers shwa/4, (shwa+shwb)/4, (shwa+2*shwb)/4, ...
fn ramp shwd shwa shwb
	call ndsize shwd as shwn
	load shwd as shwp
	itof 4 as shwq
	shwi=0
	while shwi<shwn
		itof shwa+shwi*shwb as shwx
		fdiv shwx shwq as shwx
		store shwp+shwi*8 shwx
		shwi+=1
	end
end

# print every element of the array of integers shwd with its sign, the
# last index fastest, and end the line
fn showi shwd
	local shwc 176
	call ndcopy shwc shwd as shwok
	ifz shwok
		call print "no array\n"
		ret 0
	end
	call ndsize shwc as shwn
	load shwc as shwp
	shwi=0
	while shwi<shwn
		load shwp+shwi*8 as shwx
		slt shwx 0 as shws
		if shws
			call print "-"
			shwx=0-shwx
		end
		call putn shwx
		call print " "
		shwi+=1
	end
	call print "\n"
	call ndfree shwc
	ret 1
end

# make the elements of the array shwd, which lie one behind the other,
# the integers shwa, shwa+shwb, shwa+2*shwb, ...
fn count shwd shwa shwb
	call ndsize shwd as shwn
	load shwd as shwp
	shwi=0
	while shwi<shwn
		store shwp+shwi*8 shwa+shwi*shwb
		shwi+=1
	end
end

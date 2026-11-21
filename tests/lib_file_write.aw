# what is written is what is read back, a second write replaces the
# first, and a file of a megabyte comes back whole
use "lib/io.aw"
use "lib/bytes.aw"
use "lib/file.aw"
buf b 24
buf big 24
buf back 24
call filewrite "build/tests/lib_file_write.tmp" "a longer first text\n" as r
call filewrite "build/tests/lib_file_write.tmp" "short\n" as s
call fileread "build/tests/lib_file_write.tmp" b as t
load b as p
load b+8 as n
call print p n
i=0
while i<1048576
	call byaddb big i*i>>3
	i+=1
end
load big as p
call filewrite "build/tests/lib_file_write.tmp" p 1048576 as u
call fileread "build/tests/lib_file_write.tmp" back as v
load back as q
x=v==1048576
i=0
while i<1048576
	loadb p+i as c
	loadb q+i as d
	x&=c==d
	i+=1
end
set "build/tests/lib_file_write.tmp\x00" as z
sys unlink z
call putn x
call print "\n"
sys exit r+s+t+u

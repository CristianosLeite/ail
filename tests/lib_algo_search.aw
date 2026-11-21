# searchlower of lib/algo/search.aw: the first index whose word is not
# smaller than the key, in no word, in one, and in words with some
# twice; below all, between, equal, above all, and in the unsigned order
use "lib/io.aw"
use "lib/algo/search.aw"
buf a 48
fn low n k
	call searchlower a n k as i
	call putn i
end
store a 2
store a+8 2
store a+16 5
store a+24 5
store a+32 5
store a+40 -9
call low 0 5
call print " "
call low 1 1
call low 1 2
call low 1 3
call print " "
call low 6 0
call low 6 2
call low 6 3
call low 6 5
call low 6 6
call low 6 -9
call low 6 -1
call print " "
# the five words before the last, which is large
call low 5 -9
call print "\n"

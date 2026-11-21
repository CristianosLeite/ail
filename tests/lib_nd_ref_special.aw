# infinities, what is no number and zeros with a sign against NumPy:
# each result must be the same bits, or no number where NumPy has none,
# element by element and in sums and means along an axis
use "lib/io.aw"
use "lib/nd/array.aw"
use "lib/nd/elem.aw"
use "lib/nd/reduce.aw"
use "tests/lib/ndcheck.aw"
use "tests/lib/ndfix.aw"
buf a 176
buf b 176
buf o 176
buf w 176
buf sh 16
# print how many of the n numbers of o are not those at p
fn alike o p n
	local w 176
	call fix w p 1 n 0 0
	call differ o w 2 as n
	call putn n
	call print " "
end
call fix a fxsa 1 8 0 0 as r
call fix b fxsb 1 8 0 0 as r
call ndvec o 8 as r
call ndadd o a b as s
call alike o fxsadd 8
call ndsub o a b as t
call alike o fxssub 8
call ndmul o a b as u
call alike o fxsmul 8
call nddiv o a b as v
call alike o fxsdiv 8
# as 2 rows of 4
store sh 2
store sh+8 4
call ndreshape a a 2 sh as c
call ndreshape b b 2 sh as c
call ndfree o
call ndvec o 2 as r
call ndsumax o a 1 as d
call alike o fxss1 2
call ndfree o
call ndvec o 4 as r
call ndsumax o b 0 as e
call alike o fxss0 4
call ndmeanax o b 0 as f
call alike o fxsm0 4
call print "\n"
call ndfree o
sys exit r+s+t+u+v+c+d+e+f

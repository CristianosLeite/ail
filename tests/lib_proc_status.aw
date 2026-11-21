# the exit status of a child, a child that a signal ends, and a program
# that cannot be started
use "lib/std/io.aw"
use "lib/std/proc.aw"
data sh "/bin/sh" 0
data c "-c" 0
data s7 "exit 7" 0
data s0 "exit 0" 0
data skill "kill -9 $$" 0
data none "/no/such/program" 0
buf av 32
fn show x
	ifslt x 0
		call print "-"
		x=0-x
	end
	call putn x
	call print "\n"
end
store av sh
store av+8 c
store av+16 s7
call procstart av -1 -1 -1 as p
call procwait p 0 as r
call show r
store av+16 s0
call procstart av -1 -1 -1 as p
call procwait p 0 as r
call show r
store av+16 skill
call procstart av -1 -1 -1 as p
call procwait p 0 as r
call show r
store av none
store av+8 0
call procstart av -1 -1 -1 as p
call procwait p 5000 as r
call show r
# a child that was taken is no child any more
call procwait p 0 as r
call show r

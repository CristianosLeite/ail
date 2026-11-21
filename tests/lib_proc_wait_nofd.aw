# procwait keeps its limit when the kernel has no descriptor to give for
# the child: with a limit of three open files a child that sleeps a
# quarter of a second is killed after 20 ms, one that has ended gives
# its status, one ended by a signal the signal, and no child is -1001
use "lib/io.aw"
use "lib/proc.aw"
const setrlimit 160
buf lim 16
buf ts 16
store lim 3
store lim+8 3
sys setrlimit 7 lim as r
call putn r
sys fork as p
ifz p
	store ts+8 250000000
	sys nanosleep ts 0
	sys exit 5
end
call procnow as t0
call procwait p 20 as r
call procnow as t1
call putn 0-r
call putn t1-t0<200000000
call print " "
sys fork as p
ifz p
	sys exit 7
end
call procwait p 5000 as r
call putn r
sys fork as p
ifz p
	store ts+8 20000000
	sys nanosleep ts 0
	sys getpid as q
	sys kill q 15
end
call procwait p 5000 as r
call putn 0-r
call procwait p 20 as r
call putn 0-r
call print "\n"

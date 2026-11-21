# closing a descriptor ends what waits for it with -125, and the next
# socket, which gets the same number, is a file of its own; a connect
# to a port where nobody listens is the error of the kernel, -111
use "lib/io.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
use "lib/async/io.aw"
buf rb 16
fn pair l port
	call asyncaccept l as ha
	call asyncconnect 0x7f000001 port as hc
	call await hc 0 as c
	call await ha 0 as s
	ret c s
end
call asynclisten 0x7f000001 0 as l
call asyncport l as port
call pair l port as c s
call asyncread s rb 16 as h
call asyncwrite c "x" as hw
call await hw 0
call asyncclose s as r
call putn r
call await h 0 as x
call putn 0-x
call print " "
call asyncclose c
call pair l port as c2 s2
call putn (c2==c)+(s2==s)
call asyncread s2 rb 16 as h
call asyncwrite c2 "ok" as hw
call await hw 0 as n
call await h 0 as m
call putn n
call putn m
call print " "
call print rb m
call asyncclose c2
call asyncclose s2
call asyncclose l
call asyncconnect 0x7f000001 port as hc
call await hc 0 as x
call print " "
call putn 0-x
call asyncread 1000 rb 16 as h
call await h 0 as x
call print " "
call putn 0-x
call asyncrun as n
call print " "
call putn n
call print "\n"

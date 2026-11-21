# a limit on the time of an event: -62 when the time is up, the result
# when the event is done before; a cancelled timer is -125; and no timer
# is left, so that running what is left does not sleep
use "lib/io.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
call asyncclock as t0
call asyncsleep 5000 as a
call asynctimeout a 10 as g
call await g 0 as x
call putn 0-x
call print " "
call async 64 0 as e
call asynctimeout e 5000 as g
call asyncsleep 5 as s
call await s 0
call asyncfinish e 9
call await g 0 as x
call putn x
call print " "
call asyncsleep 5000 as a
call asynccancel a as c
call asynccancel a as d
call await a 0 as x
call putn 0-x
call putn c
call putn d
call print " "
# a limit that is cancelled cancels its event and its timer
call async 64 0 as e
call asynctimeout e 5000 as g
call asyncstep
call asynccancel g
call await g 0 as x
call putn 0-x
call print "\n"
call asyncrun as n
call asyncclock as t1
sys exit_group n*2+(t1-t0>1000000000)

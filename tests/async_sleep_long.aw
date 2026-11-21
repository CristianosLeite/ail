# a time whose nanoseconds do not fit in 64 bits, or that passes the end
# of the clock when added to it, is a timer that is never due: a short
# one is first, and the long ones end only when they are cancelled
use "lib/io.aw"
use "lib/async/task.aw"
use "lib/async/time.aw"
use "lib/async/chan.aw"
call asyncsleep 18446744073710 as a
call asyncsleep -1 as b
call asyncsleep 9223372036854 as c
call asyncsleep 10 as s
await asyncfirst a s as i
call putn i
await asyncfirst b s as i
call putn i
await asyncfirst c s as i
call putn i
await s as x
call putn x
call asynctimeout a 10 as g
await g as x
call putn 0-x
call asynccancel b
await b as x
call putn 0-x
call asynccancel c
await c as x
call putn 0-x
call print "\n"

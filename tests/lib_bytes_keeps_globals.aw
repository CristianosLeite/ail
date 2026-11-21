# a var of the program keeps its value: every variable of the library has
# a name that starts with "by"
var b p n i w c d len cap new old ok v digits dst src
use "lib/std/io.aw"
use "lib/std/bytes.aw"
buf x 24
b=1
p=1
n=1
i=1
w=1
c=1
d=1
len=1
cap=1
new=1
old=1
ok=1
v=1
digits=1
dst=1
src=1
call byadd x "0123456789abcdef"
call byaddb x 1
call byaddn x 12345
call byneed x 10000
call bycut x 2
call byfree x
sys exit b+p+n+i+w+c+d+len+cap+new+old+ok+v+digits+dst+src

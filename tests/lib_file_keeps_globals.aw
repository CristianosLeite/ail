# a var of the program keeps its value: every variable of the library has
# a name that starts with "file"
var p n fd b r z i c flags mode sum ok len cap d dn
use "lib/io.aw"
use "lib/bytes.aw"
use "lib/file.aw"
buf x 24
p=1
n=1
fd=1
b=1
r=1
z=1
i=1
c=1
flags=1
mode=1
sum=1
ok=1
len=1
cap=1
d=1
dn=1
call fileread "tests/lib/words.txt" x
call filewrite "build/tests/lib_file_keeps_globals.tmp" "x"
set "build/tests/lib_file_keeps_globals.tmp\x00" as y
sys unlink y
sys exit p+n+fd+b+r+z+i+c+flags+mode+sum+ok+len+cap+d+dn

# two processes add to one counter in shared memory 200000 times each;
# with xadd no addition is lost
sys mmap 0 4096 3 33 -1 0 as c
sys fork as pid
set 200000 as n
label top
xadd c 1 as o
sub n 1 as n
jnz n top
ifz pid
	sys exit 0
end
sys wait4 pid 0 0 0
load c as v
eq v 400000 as ok
sys exit ok

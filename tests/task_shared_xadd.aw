use "lib/task.aw"
buf cell 8
buf hs 400
fn work n
	while n
		xadd cell 1 as o
		n-=1
	end
end
i=0
while i<50
	spawn work 20000 as h
	store hs+i*8 h
	i+=1
end
while i
	i-=1
	load hs+i*8 as h
	join h
end
load cell as c
sys exit_group c==1000000

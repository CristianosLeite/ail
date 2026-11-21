use "lib/std/task.aw"
# what a task wrote to memory it was passed is there after its join
buf b 8000
buf hs 80
fn fill p n v
	while n
		n-=1
		store p+n*8 v
	end
end
i=0
while i<10
	spawn fill b+i*800 100 i+1 as h
	store hs+i*8 h
	i+=1
end
while i
	i-=1
	load hs+i*8 as h
	join h
end
s=0
while i<1000
	load b+i*8 as x
	s+=x
	i+=1
end
sys exit_group s==5500

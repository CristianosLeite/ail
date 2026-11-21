use "lib/task.aw"
# forty rounds of eight tasks on two workers: no third worker, and the
# records are used again
buf hs 64
fn work a
	ret a+1
end
call workers 2
s=0
r=0
while r<40
	i=0
	while i<8
		spawn work i as h
		store hs+i*8 h
		i+=1
	end
	while i
		i-=1
		load hs+i*8 as h
		join h as x
		s+=x
	end
	r+=1
end
load taskq+48 as w
sys exit_group (s==1440)+(w<=2)*2

# a while on two comparisons joined by & runs while both hold, whichever
# fails first and also when one fails at the start; in a function, at top
# level, with every kind of comparison, with values that are expressions,
# nested, and beside the forms that are computed as a value
use "lib/io.aw"
fn both a b n
	i=0
	j=0
	c=0
	while (i<a)&(j<b)
		c+=1
		if c&1
			i+=1
		else
			j+=n
		end
	end
	ret c*100+i*10+j
end
fn kinds a b
	c=0
	while (a!=b)&(a+1<=b*2)
		a+=1
		c+=1
	end
	while (b>=a)&(b==a)
		b+=1
		c+=10
	end
	while (a>3)&(b>a)
		a-=1
		c+=100
	end
	ret c
end
fn nested n
	c=0
	i=0
	while (i<n)&(c<1000)
		j=0
		while (j<i)&(j!=3)
			c+=1
			j+=1
		end
		i+=1
	end
	ret c
end
fn other a b
	c=0
	# three comparisons, an | and a division are computed as a value
	while (a<b)&(c<9)&(a!=7)
		a+=1
		c+=1
	end
	while (a<b)|(c<5)
		a+=1
		c+=1
	end
	while (c<40)&(b/c<4)
		c+=7
	end
	ret c
end
call both 3 3 1 as r
call putn r
call print " "
call both 0 3 1 as r
call putn r
call print " "
call both 3 0 1 as r
call putn r
call print " "
call both 5 2 1 as r
call putn r
call print " "
call both 2 9 4 as r
call putn r
call print "\n"
call kinds 2 6 as r
call putn r
call print " "
call kinds 6 6 as r
call putn r
call print " "
call nested 6 as r
call putn r
call print " "
call other 2 30 as r
call putn r
call print "\n"
x=0
y=10
n=0
while (x<y)&(y>4)
	x+=1
	y-=1
	n+=1
end
while (n<3)&(x<y)
	n+=100
end
call putn x*100+y
call print " "
call putn n
call print "\n"

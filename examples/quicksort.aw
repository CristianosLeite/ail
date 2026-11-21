# quicksort: sort the words from p up to q, in place. The pivot is the
# median of the first, the middle and the last word; one pass puts the
# smaller words before those equal to it and the larger ones behind. The
# smaller side is sorted by a call and the larger one by going round, so
# the calls are never deeper than the logarithm of the count.
use "bench/algo/harness.aw"
fn quicksort p q
	while q-p>8
		load p as a
		load p+(q-p>>4<<3) as b
		load q-8 as c
		if a>b
			x=a
			a=b
			b=x
		end
		if b>c
			b=c
			if a>b
				b=a
			end
		end
		l=p
		i=p
		g=q
		while i<g
			load i as v
			if v<b
				load l as x
				store i x
				store l v
				l+=8
				i+=8
			else
				if v>b
					g-=8
					load g as x
					store i x
					store g v
				else
					i+=8
				end
			end
		end
		if l-p<q-g
			call quicksort p l
			p=g
		else
			call quicksort g q
			q=l
		end
	end
end
fn sort a n t
	tail quicksort a a+n*8
end
ref sort as k
call algosort k

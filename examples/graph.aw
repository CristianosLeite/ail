# graph: reach every vertex of a graph, breadth first and depth first.
# The neighbours of the vertex v are the words of nbr from the index
# off[v] up to off[v+1]; seen has a byte for each vertex, zero at the
# start. Both begin at the lowest vertex not reached yet and write the
# vertices to r in the order they reach them.
use "bench/algo/harness.aw"

# breadth first: r is the queue as well, h the next vertex to leave it
fn bfs off nbr n seen r
	t=0
	h=0
	s=0
	while s<n
		loadb seen+s as c
		ifz c
			storeb seen+s 1
			store r+t*8 s
			t+=1
			while h<t
				load r+h*8 as v
				h+=1
				load off+v*8 as e
				load off+v*8+8 as f
				while e<f
					load nbr+e*8 as w
					loadb seen+w as c
					ifz c
						storeb seen+w 1
						store r+t*8 w
						t+=1
					end
					e+=1
				end
			end
		end
		s+=1
	end
end

# depth first: st is a stack with room for every edge and one vertex
fn dfs off nbr n seen st r
	k=0
	s=0
	while s<n
		loadb seen+s as c
		ifz c
			store st s
			p=1
			while p
				p-=1
				load st+p*8 as v
				loadb seen+v as c
				ifz c
					storeb seen+v 1
					store r+k*8 v
					k+=1
					load off+v*8 as e
					load off+v*8+8 as f
					while e<f
						load nbr+e*8 as w
						store st+p*8 w
						p+=1
						e+=1
					end
				end
			end
		end
		s+=1
	end
end
ref bfs as a
ref dfs as b
call algograph a b

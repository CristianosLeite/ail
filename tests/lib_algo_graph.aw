# graphbfs and graphdfs of lib/algo/graph.aw: no vertex; three vertices
# without an edge; a tree whose two orders differ; and a cycle with an
# edge from a vertex to itself, an edge twice and a vertex that nothing
# leads to. Each vertex is written once and its byte is 1 afterwards
use "lib/std/io.aw"
use "lib/algo/graph.aw"
buf off 56
buf nbr 64
buf seen 8
buf st 72
buf r 48
# the two orders of the n vertices, and how many bytes are not 1
fn both n
	store seen 0
	call graphbfs off nbr n seen r
	call show n
	store seen 0
	call graphdfs off nbr n seen st r
	call show n
end
fn show n
	b=0
	i=0
	while i<n
		load r+i*8 as v
		call putn v
		loadb seen+i as c
		b+=c!=1
		i+=1
	end
	call print ":"
	call putn b
	call print " "
end
call both 0
# no edge
store off 0
store off+8 0
store off+16 0
store off+24 0
call both 3
# 0 to 1 and 2, 1 to 3, 2 to 4
store off 0
store off+8 2
store off+16 3
store off+24 4
store off+32 4
store off+40 4
store nbr 1
store nbr+8 2
store nbr+16 3
store nbr+24 4
call both 5
# 1 to 2 and 1, 2 to 3 twice, 3 to 1; 0 leads nowhere and 4 is alone
store off 0
store off+8 0
store off+16 2
store off+24 4
store off+32 5
store off+40 5
store nbr 2
store nbr+8 1
store nbr+16 3
store nbr+24 3
store nbr+32 1
call both 5
call print "\n"

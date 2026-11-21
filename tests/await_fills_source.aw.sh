# nearly as many awaits of a function as the source limit can hold: each
# is eight bytes and two entries of the table of calls, the most that a
# source can ask of it, and the expression after them uses the table that
# stands behind it
printf 'fn await h s\nend\nfn a\nend\n'
yes 'await a' | head -n 1048500
printf 'b=1\nx=b+1\nsys exit_group x\n'

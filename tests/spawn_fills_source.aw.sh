# nearly as many spawns as the source limit can hold: each is two entries
# of the table of calls, which is sized for that, and the expression after
# them uses the table that stands behind it
printf 'fn spawn\nend\nfn a\nend\n'
yes 'spawn a as b' | head -n 645000
printf 'x=b+1\nsys exit_group x\n'

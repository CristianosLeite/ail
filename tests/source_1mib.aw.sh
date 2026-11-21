# a megabyte of statements, each of which runs
printf 'set 0 as x\n'
yes 'add x 1 as x' | head -80000
printf 'sys exit x\n'

# the same inside one function, which is compiled twice: the labels of the
# first pass are taken out of the hash again
printf 'fn big\nset 0 as s\n'
seq 30000 | awk '{printf "jmp l%d\nadd s 1 as s\nlabel l%d\n", $1, $1}'
printf 'add s 5 as s\nret s\nend\ncall big as r\n'
# a second function may use the same label names
printf 'fn small\njmp l1\nlabel l1\nret 2\nend\ncall small as q\nadd r q as r\nsys exit r\n'

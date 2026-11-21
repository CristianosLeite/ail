# nearly as many calls as 64 KiB of source can hold, and every one runs:
# the function counts them in a buffer
printf 'buf n 8\nfn a\nload n as v\nadd v 1 as v\nstore n v\nend\n'
yes 'call a' | head -n 9343
printf 'load n as v\neq v 9343 as v\njz v bad\nsys 1 1 "ok\\n"\nsys 60 0\nlabel bad\nsys 60 1\n'

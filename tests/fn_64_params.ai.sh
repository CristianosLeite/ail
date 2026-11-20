# 64 parameters, the most a function can have, and one too many
printf 'fn f'; for i in $(seq 64); do printf ' p%s' "$i"; done; printf '\nadd p1 p64 as p1\nadd p1 p7 as p1\nadd p1 p33 as p1\nret p1\nend\ncall f'
for i in $(seq 64); do printf ' %s' "$i"; done; printf ' as x\nsys 60 x\n'

# 64 variables in a function, all in use until the end: 58 stack slots
printf 'fn f a\n'
for i in $(seq 2 64); do printf 'add a %s as v%s\n' "$i" "$i"; done
printf 'set 0 as a\n'
for i in $(seq 2 64); do printf 'add a v%s as a\n' "$i"; done
printf 'ret a\nend\ncall f 0 as r\nmod r 251 as r\nsys 60 r\n'

# 60 variables, each done before the next starts: registers are reused
printf 'fn f\nset 0 as s\n'
for i in $(seq 60); do printf 'set %s as t%s\nadd s t%s as s\n' "$i" "$i" "$i"; done
printf 'ret s\nend\ncall f as r\nmod r 251 as r\nsys 60 r\n'

# 1500 vars: the cells take three pages below the buffers
printf 'var'; for i in $(seq 1500); do printf ' v%s' "$i"; done; printf '\n'
printf 'buf b 8\nset 5 as v1\nset 6 as v513\nset 7 as v1500\nstore b 0\nadd v1 v513 as x\nadd x v1500 as x\nadd x v1499 as x\nsys 60 x\n'

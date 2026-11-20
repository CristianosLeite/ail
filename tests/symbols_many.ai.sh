# 60000 labels with a jump each, 60000 data names and 15000 functions: found
# by hash, where a search through the tables took the square of that
for i in $(seq 60000); do printf 'jmp l%s\nlabel l%s\n' "$i" "$i"; done
printf 'set 0 as s\n'
seq 60000 | awk '{printf "data d%d %d\n", $1, $1 % 256}'
for i in 1 1000 59999 60000; do printf 'loadb d%s as v\nadd s v as s\n' "$i"; done
seq 15000 | awk '{printf "fn f%d\nret %d\nend\n", $1, $1 % 8}'
for i in 1 7 14999; do printf 'call f%s as v\nadd s v as s\n' "$i"; done
printf 'sys exit s\n'

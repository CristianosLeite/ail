# 64 values in one call, many times over: far more code than the gap that
# the output check leaves, in statements that are checked value by value
printf 'fn f'; for i in $(seq 64); do printf ' p%s' "$i"; done; printf '\nret p64\nend\nset 0 as s\n'
for k in $(seq 300); do printf 'call f'; for i in $(seq 64); do printf ' %s' "$i"; done; printf ' as r\nadd s r as s\n'; done
printf 'shr s 8 as s\nsys exit s\n'

# 64 variables at top level: the limit
for i in $(seq 64); do printf 'set %s as v%s\n' "$i" "$i"; done
printf 'add v1 v64 as v1\nadd v1 v7 as v1\nadd v1 v33 as v1\nsys 60 v1\n'

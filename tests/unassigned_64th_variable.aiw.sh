# the check covers all 64 variables of a scope
printf 'sys 39 as v1\n'; for i in $(seq 2 63); do printf 'set %s as v%s\n' "$i" "$i"; done
printf 'jz v1 s\nset 1 as v64\nlabel s\nsys 60 v64\n'

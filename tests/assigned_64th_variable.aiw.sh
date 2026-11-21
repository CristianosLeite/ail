printf 'sys 39 as v1\n'; for i in $(seq 2 63); do printf 'set %s as v%s\n' "$i" "$i"; done
printf 'jz v1 s\nset 1 as v64\njmp t\nlabel s\nset 9 as v64\nlabel t\nsys 60 v64\n'

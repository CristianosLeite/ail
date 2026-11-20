# 100000 nested parentheses around a sum that is computed when it runs
printf 'x=3\nsys exit '
awk 'BEGIN { for (i = 0; i < 100000; i++) printf "("; printf "x+4"; for (i = 0; i < 100000; i++) printf ")"; print "" }'

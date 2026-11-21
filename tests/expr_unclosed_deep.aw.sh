# a hundred thousand parentheses that are never closed
printf 'sys exit '
awk 'BEGIN { for (i = 0; i < 100000; i++) printf "("; print "1" }'

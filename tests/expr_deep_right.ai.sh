# 20000 values, each added to the sum of those after it: every one waits on
# the stack of the program until the last is read
printf 'x=1\nsys exit ('
awk 'BEGIN { for (i = 0; i < 20000; i++) printf "x+("; printf "x"; for (i = 0; i < 20000; i++) printf ")"; print ")%251" }'

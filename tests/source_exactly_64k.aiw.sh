# 65536 bytes: the largest source the compiler accepts
printf 'sys 1 1 "ok\\n"\n'
head -c 65521 /dev/zero | tr '\0' '#'

# 65537 bytes: one more than the compiler accepts
printf 'sys 1 1 "ok\\n"\n'
head -c 65522 /dev/zero | tr '\0' '#'

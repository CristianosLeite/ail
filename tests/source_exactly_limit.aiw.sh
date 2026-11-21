# 8388608 bytes, the most the compiler accepts
printf 'sys exit 7\n'
head -c 8388597 /dev/zero | tr '\0' '#'

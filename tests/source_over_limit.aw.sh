# 8388609 bytes: one too many
printf 'sys exit 7\n'
head -c 8388598 /dev/zero | tr '\0' '#'

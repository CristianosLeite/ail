# a megabyte of constants is one number
printf 'sys exit (1'
awk 'BEGIN { for (i = 0; i < 500000; i++) printf "+1"; print ")%251" }'

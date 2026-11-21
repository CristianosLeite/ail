# an expression of 200001 values added up: its length has no limit of its own
printf 'x=1\nsys exit (x'
awk 'BEGIN { for (i = 0; i < 200000; i++) printf "+x"; print ")%251" }'

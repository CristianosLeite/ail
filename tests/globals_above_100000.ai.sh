# more global names than 99999, which was once the mark for "not found"
seq 100005 | awk '{printf "const k%d %d\n", $1, $1 % 250}'
printf 'add k99999 k100000 as s\nadd s k100001 as s\nadd s k100005 as s\nsys exit s\n'

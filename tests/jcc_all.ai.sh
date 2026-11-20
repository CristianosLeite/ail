# every compare-and-jump with a pair that holds and one that does not: a
# taken jump adds its bit, and a jump taken wrongly would skip a bit too
bit=1
printf 'set 0 as r\n'
i=0
for row in 'jeq 5 5 5 6' 'jne 5 6 5 5' 'jlt 5 6 6 5' 'jle 5 5 6 5' 'jgt 6 5 5 6' 'jge 5 5 5 6'; do
  set -- $row; i=$((i+1))
  printf '%s %s %s t%s\njmp n%s\nlabel t%s\nadd r %s as r\nlabel n%s\n' "$1" "$2" "$3" "$i" "$i" "$i" "$bit" "$i"
  printf '%s %s %s bad\n' "$1" "$4" "$5"
  bit=$((bit*2))
done
printf 'sys 60 r\nlabel bad\nsys 60 255\n'

# every comparison block with a pair that holds and one that does not
bit=1
printf 'set 0 as r\n'
for row in 'ifeq 5 5 5 6' 'ifne 5 6 5 5' 'iflt 5 6 6 5' 'ifle 5 5 6 5' 'ifgt 6 5 5 6' 'ifge 5 5 5 6' 'ifslt -1 1 1 -1' 'ifsle -1 -1 1 -1' 'ifsgt 1 -1 -1 1' 'ifsge -1 -1 -1 1'; do
  set -- $row
  printf '%s %s %s\nadd r %s as r\nend\n%s %s %s\nsys 60 255\nend\n' "$1" "$2" "$3" "$bit" "$1" "$4" "$5"
  bit=$((bit*2))
done
printf 'shr r 4 as h\nand r 15 as r\nxor r h as r\nsys 60 r\n'

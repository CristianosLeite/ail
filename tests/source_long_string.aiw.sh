# one string of 300000 bytes and one data line of 100000 items
printf 'sys write 1 "'; head -c 300000 /dev/zero | tr '\0' 'x'; printf '" as n\nshr n 12 as n\n'
printf 'data d'; yes ' 7' | head -100000 | tr -d '\n'; printf '\nadd d 99999 as p\nloadb p as v\nadd n v as n\nsys exit n\n'

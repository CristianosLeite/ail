# 300 buffers: there is no limit on their number
for i in $(seq 300); do printf 'buf b%s 8\n' "$i"; done
printf 'storeb b1 3\nstoreb b300 4\nloadb b1 as x\nloadb b300 as y\nadd x y as x\nsub b300 b1 as d\nshr d 8 as d\nadd x d as x\nsys 60 x\n'

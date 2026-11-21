# 40 data names and 16 buffers: data does not count as a buffer
for i in $(seq 40); do printf 'data d%s %s\n' "$i" "$i"; done
for i in $(seq 16); do printf 'buf b%s 8\n' "$i"; done
printf 'loadb d40 as x\nstoreb b16 x\nloadb b16 as y\nsys 60 y\n'

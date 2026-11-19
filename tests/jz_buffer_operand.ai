# a buffer name is its address, which is never zero
buf b 8
jz b bad
jnz b good
label bad
sys 60 1
label good
sys 1 1 "ok\n"

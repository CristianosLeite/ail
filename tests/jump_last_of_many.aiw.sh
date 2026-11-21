# the last of as many jumps as fit is the one that runs: it is the final
# entry of the fixup table and jumps back over all the others
printf 'jmp last\nlabel a\nsys 1 1 "ok\\n"\nsys 60 0\n'
yes 'jmp a' | head -n 10912
printf 'label last\njmp a\n'

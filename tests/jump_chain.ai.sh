# 2000 jumps that all run, each to its own label over a statement that
# would exit 1: one wrong displacement or label lookup changes the result
awk 'BEGIN { for (i = 0; i < 2000; i++)
    printf "jmp a%d\nsys 60 1\nlabel a%d\n", i, i
    print "sys 1 1 \"ok\\n\"" }'

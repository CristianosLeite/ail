# 1000 functions, each called once: half of the calls come before the
# definitions and half after, and function i adds i to its argument
echo 'set 0 as s'
seq 1 500 | sed 's/.*/call f& s as s/'
seq 1 1000 | sed 's/.*/fn f& a\nadd a & as a\nret a\nend/'
seq 501 1000 | sed 's/.*/call f& s as s/'
printf 'eq s 500500 as s\njz s bad\nsys 1 1 "ok\\n"\nsys 60 0\nlabel bad\nsys 60 1\n'

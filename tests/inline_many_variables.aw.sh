#!/bin/sh
# a function with 62 variables has no room for the three of add3, whose
# call stays a call; with 60 it is compiled in place
echo 'use "lib/io.aw"'
echo 'fn add3 a b'
echo '	c=a+b'
echo '	ret c+1'
echo 'end'
for n in 60 62; do
	echo "fn f$n"
	i=0
	while [ $i -lt $n ]; do
		echo "	v$i=$i"
		i=$((i+1))
	done
	echo '	call add3 v1 v2 as v0'
	i=1
	while [ $i -lt $n ]; do
		echo "	v0+=v$i"
		i=$((i+1))
	done
	echo '	ret v0'
	echo 'end'
	echo "call f$n as x"
	echo 'call putn x'
	echo 'call print "\n"'
done

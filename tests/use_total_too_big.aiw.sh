# the main source and the files it uses share the 8388608 bytes
printf 'use "tests/lib/twice.aiw"\n'
head -c 8388570 /dev/zero | tr '\0' '#'

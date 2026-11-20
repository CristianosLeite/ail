# the main source and the files it uses share the 65536 bytes
printf 'use "tests/lib/twice.ai"\n'
head -c 65500 /dev/zero | tr '\0' '#'

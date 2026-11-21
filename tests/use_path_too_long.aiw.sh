printf 'use "'; head -c 4096 /dev/zero | tr '\0' 'a'; printf '"\n'

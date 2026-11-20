printf 'fn f\n'; for i in $(seq 65); do printf 'set %s as v%s\n' "$i" "$i"; done; printf 'end\n'

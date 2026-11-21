# as many calls as 64 KiB of source can hold: exactly 65536 bytes
printf 'fn a\nend\n'
yes 'call a' | head -n 9361

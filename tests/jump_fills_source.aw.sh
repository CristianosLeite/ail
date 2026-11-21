# as many jumps as 64 KiB of source can hold, all to one label at the end
yes 'jmp a' | head -n 10921
echo 'label a'

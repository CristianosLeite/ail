# code of about 3000 bytes ends in the upper half of a page: the writable
# segment must still start on the next whole page
printf 'data pad "'; head -c 2800 /dev/zero | tr '\0' 'x'; printf '"\n'
printf 'buf b 8\nstoreb b 5\nloadb b as v\nand b 4095 as x\nshr x 4 as x\nadd x v as x\nsys exit x\n'

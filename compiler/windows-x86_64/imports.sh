#!/bin/sh
# usage: compiler/windows-x86_64/imports.sh data|consts < imports.list
#
# The import tables of a Windows executable, from the list of libraries
# and functions on stdin. They stand in the second page of the file, at
# 4096, where the page is also loaded: a directory of 20 bytes for each
# library and 20 of zeros; for each library two tables of 8 bytes a
# function and 8 of zeros, the first for the loader to read and the
# second for it to write the addresses into; then for each function two
# bytes of zeros, its name and a zero, at an even place; then the names
# of the libraries.
#
# "data" writes them as the data timp of the compiler's target, with
# their length timpn and the length of the directory tidtn. "consts"
# writes for the runtime a const rt_i_<function, in small letters> for
# each function: the place of its address, counted from the start of the
# executable.
set -eu
grep -v -e '^#' -e '^[[:space:]]*$' | awk -v mode="$1" '
function le(v, n,   i) { for (i = 0; i < n; i++) { byte[len++] = v % 256; v = int(v / 256) } }
function str(s,   i) { for (i = 1; i <= length(s); i++) byte[len++] = ord[substr(s, i, 1)]; byte[len++] = 0 }
BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i }
{ nd++; dll[nd] = $1; nf[nd] = NF - 1; for (i = 2; i <= NF; i++) fn[nd, i - 1] = $i }
END {
    base = 4096
    pos = (nd + 1) * 20
    for (d = 1; d <= nd; d++) { ilt[d] = pos; pos += 8 * (nf[d] + 1); iat[d] = pos; pos += 8 * (nf[d] + 1) }
    for (d = 1; d <= nd; d++) for (i = 1; i <= nf[d]; i++) {
        hn[d, i] = pos; pos += 2 + length(fn[d, i]) + 1; pos += pos % 2 }
    for (d = 1; d <= nd; d++) { dn[d] = pos; pos += length(dll[d]) + 1 }
    if (pos > 4096) { print "imports.sh: the tables do not fit a page" > "/dev/stderr"; exit 1 }
    if (mode == "consts") {
        for (d = 1; d <= nd; d++) for (i = 1; i <= nf[d]; i++)
            printf "const rt_i_%s %d\n", tolower(fn[d, i]), base + iat[d] + 8 * (i - 1)
        exit 0
    }
    len = 0
    for (d = 1; d <= nd; d++) { le(base + ilt[d], 4); le(0, 4); le(0, 4); le(base + dn[d], 4); le(base + iat[d], 4) }
    le(0, 4); le(0, 4); le(0, 4); le(0, 4); le(0, 4)
    for (d = 1; d <= nd; d++) for (t = 0; t < 2; t++) {
        for (i = 1; i <= nf[d]; i++) le(base + hn[d, i], 8); le(0, 8) }
    for (d = 1; d <= nd; d++) for (i = 1; i <= nf[d]; i++) { le(0, 2); str(fn[d, i]); if (len % 2) byte[len++] = 0 }
    for (d = 1; d <= nd; d++) str(dll[d])
    printf "# the import tables, written by compiler/windows-x86_64/imports.sh\n"
    printf "const timpn %d\nconst tidtn %d\n", len, (nd + 1) * 20
    for (i = 0; i < len; i++) {
        if (i % 16 == 0) printf "%s", (i ? "\ndata" : "data timp")
        printf " %d", byte[i] }
    printf "\n"
}'

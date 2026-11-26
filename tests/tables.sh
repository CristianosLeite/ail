#!/bin/sh
# Check the form of compiler/tables.aiw, the tables of the compiler. Their
# bytes are checked by tests/insn.sh against an assembler's; this script
# checks what a slip of the hand breaks without changing an instruction:
# a length that is not that of its name or code, a statement or syscall
# name twice, a flag that no statement has, a row split over two lines, a
# missing end, a table of the wrong size, a syscall number that is not
# the kernel's, a service of the runtime that a statement calls with
# another number of values.
cd "$(dirname "$0")/.." || exit 1
out=$(awk '
function bad(msg) { printf "%s (line %d)\n", msg, NR; nbad++ }
# split a data line into bytes b[1..nb]; a string gives its characters
function bytes(line,    i, w, n, k, s) {
    nb = 0
    n = split(line, w, " ")
    for (i = 1; i <= n; i++) {
        if (w[i] ~ /^"[^"]*"$/) {
            s = substr(w[i], 2, length(w[i]) - 2)
            for (k = 1; k <= length(s); k++) { b[++nb] = -1; ch[nb] = substr(s, k, 1) }
        } else if (w[i] ~ /^[0-9]+$/ && w[i] + 0 <= 255) b[++nb] = w[i] + 0
        else bad("not a byte: " w[i])
    }
}
BEGIN {
    size["retc"] = 11; size["fnpush"] = 10; size["zeroes"] = 14
    size["zerolen"] = 6; size["pushlen"] = 7; size["probe"] = 36; size["asytst"] = 5; size["asypoll"] = 15; size["asyret"] = 11; size["asyawt"] = 23; size["asysus"] = 9; size["regtab"] = 18
    size["argnum"] = 9; size["varnum"] = 6; size["exit0"] = 3; size["callkw"] = 4; size["rowas"] = 4
    size["exkw"] = 48; size["xopc"] = 48; size["xord"] = 13; size["nops"] = 45
    # x86-64 Linux, from asm/unistd_64.h
    split("read 0 write 1 open 2 close 3 stat 4 fstat 5 lseek 8 mmap 9 mprotect 10 " \
          "munmap 11 brk 12 rt_sigaction 13 ioctl 16 pipe 22 nanosleep 35 getpid 39 " \
          "socket 41 connect 42 accept 43 bind 49 listen 50 clone 56 fork 57 execve 59 exit 60 " \
          "wait4 61 kill 62 rename 82 mkdir 83 rmdir 84 unlink 87 chmod 90 " \
          "gettimeofday 96 getuid 102 futex 202 sched_getaffinity 204 clock_gettime 228 exit_group 231 openat 257 " \
          "getrandom 318", k, " ")
    for (i = 1; k[i] != ""; i += 2) { sysnum[k[i]] = k[i + 1]; nsys++ }
}
/^#/ || /^[ \t]*$/ { next }
$1 != "data" { bad("not a data line"); next }
{
    line = $0; sub(/^data +/, "", line)
    if (line ~ /^[a-z]/) {              # a name starts a table
        table = line; sub(/ .*/, "", table); sub(/^[a-z0-9]+ */, "", line)
        if (table in seen) bad("table twice: " table)
        seen[table] = 1
    }
    bytes(line)
    if (table != "optab" && table != "sysnames" && table != "rtnames") { count[table] += nb; next }
    if (ended[table]) { bad("row after the end of " table); next }
    if (nb == 1 && b[1] == 0) { ended[table] = 1; next }
    # one row: length, name, then the rest
    len = b[1]; name = ""
    for (i = 2; i <= 1 + len && i <= nb; i++) {
        if (b[i] != -1) bad("name of " table " is not a string")
        name = name ch[i]
    }
    if (length(name) != len || len == 0) { bad("wrong name length: " name); next }
    if (name !~ /^[a-z][a-z0-9_]*$/) bad("bad name: " name)
    if ((table, name) in names) bad("name twice: " name)
    names[table, name] = 1
    p = 2 + len
    if (table == "rtnames") {
        if (nb != p + 3) { bad("wrong row length: " name); next }
        if (b[p + 3] != 0 && b[p + 3] != 2 && b[p + 3] != 3) bad("flag of a service: " name)
        if (b[p] < 1 || b[p] in rtentry) bad("entry of a service twice or none: " name)
        if (b[p + 1] > 5 || b[p + 2] > 2) bad("values or results of a service: " name)
        rtentry[b[p]] = name; rtnum[name] = b[p]; rtargs[name] = b[p + 1]
        if (b[p] > rtmax) rtmax = b[p]
        next
    }
    if (table == "sysnames") {
        if (nb != p + 1) { bad("wrong row length: " name); next }
        if (!(name in sysnum)) bad("unknown syscall: " name)
        else if (b[p] + 256 * b[p + 1] != sysnum[name]) bad("wrong syscall number: " name)
        nsysrows++
        next
    }
    if (nb < p + 3) { bad("short row: " name); next }
    cnt = b[p]; f1 = b[p + 1]; f2 = b[p + 2]; clen = b[p + 3]
    if (nb != p + 3 + clen) bad("wrong code length: " name)
    if (f1 == 255) {                    # parsed on its own, numbered by the count
        if (f2 != 0 || clen != 0) bad("own statement with flags or code: " name)
        if (cnt != ++nown) bad("own statements not numbered in order: " name)
    } else {
        if (nown) bad("statement after the ones parsed on their own: " name)
        # a service: rt reads its name, any other row has its entry as code
        if (f2 > 127 && f1 % 8 < 4) {
            if (clen != 1) bad("service without an entry: " name)
            else { svc[name] = b[p + 4]; svccnt[name] = cnt }
        }
        if (f1 % 4 == 3) bad("as both required and forbidden: " name)
        if (cnt > 4) bad("operand count: " name)
    }
    nrows++
}
END {
    if (!ended["optab"]) bad("optab has no end")
    if (!ended["sysnames"]) bad("sysnames has no end")
    if (!ended["rtnames"]) bad("rtnames has no end")
    for (n in svc) {
        if (rtnum[n] != svc[n]) bad("statement and service of another entry: " n)
        else if (rtargs[n] != svccnt[n]) bad("statement and service of other values: " n)
    }
    if (rtmax > 63) bad("more services than the compiler has room for")
    for (t in size) if (count[t] != size[t]) bad("table " t " has " count[t] + 0 " bytes, not " size[t])
    for (t in count) if (!(t in size)) bad("unknown table: " t)
    if (!("optab" in seen)) bad("no optab")
    if (nsysrows != nsys) bad("sysnames has " nsysrows + 0 " names, not " nsys)
    if (nrows < 80) bad("optab has only " nrows " rows")
    exit nbad != 0
}' compiler/tables.aiw)
# the header of the target, a table of its own file
n=$(awk '/^data thdr / { t = 1; sub(/^data thdr/, "data") } /^data / && t { n += NF - 1; next } t && !/^data / { t = 0 } END { print n + 0 }' compiler/linux-x86_64/target.aiw)
[ "$n" -eq 176 ] || out="$out
the header of linux-x86_64 has $n bytes, not 176"
if [ $? -eq 0 ] && [ -z "$out" ]
then echo "ok   tables_form"
else echo "FAIL tables_form"; [ -n "$out" ] && echo "$out" | sed 's/^/     /'; exit 1
fi

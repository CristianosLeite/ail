#!/bin/sh
# Check the bytes the compiler emits against bytes computed here, without a
# compiler: for programs that fill a fixup table to its capacity, every
# displacement and the whole ELF header. Each program is one line repeated
# until the source has its 8 MiB, so its code is one record for each of the
# K lines, between a prefix and the implicit exit, and the expected file is
# a formula, which awk writes out byte for byte. A second compiler, if
# given, must produce the same file.
# Usage: AILC=<compiler> [AILC2=<compiler>] tests/bytes.sh   (default build/ailc)
set -u
cd "$(dirname "$0")/.."
ailc=${AILC:-build/ailc}
limit=60
mkdir -p build/tests
out=$(mktemp -d build/tests/bytes.XXXXXX) || exit 1
trap 'rm -rf "$out"' EXIT
trap 'exit 1' HUP INT TERM
fail=0

# check <name> <awk program>: the awk program defines K, the number of
# lines; source(), which prints the source; and code(), which prints the
# code between the header and the implicit exit with b() and r4(). MEM is
# the size of the writable segment. code() may use size, the length of the
# output file, and rw, where the writable segment starts.
check() {
    lib='
    function b(s,   i, n, f) { n = split(s, f, " "); for (i = 1; i <= n; i++) printf "%c", f[i] + 0 }
    function le(v, n,   i) { for (i = 0; i < n; i++) { printf "%c", v % 256; v = int(v / 256) } }
    function r4(v) { if (v < 0) v += 4294967296
        printf "%c%c%c%c", v % 256, int(v / 256) % 256, int(v / 65536) % 256, int(v / 16777216) }
    function header(mem) {
        b("127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0")
        le(3, 2); le(62, 2); le(1, 4); le(176, 8); le(64, 8); le(0, 8); le(0, 4)
        le(64, 2); le(56, 2); le(2, 2); le(64, 2); le(0, 2); le(0, 2)
        le(1, 4); le(5, 4); le(0, 8); le(0, 8); le(0, 8); le(size, 8); le(size, 8); le(4096, 8)
        le(1, 4); le(6, 4); le(0, 8); le(rw, 8); le(rw, 8); le(0, 8); le(mem, 8); le(4096, 8)
    }'
    awk "$lib $2 BEGIN { init(); source() }" > "$out/src"
    if ! timeout --signal=KILL $limit "$ailc" < "$out/src" > "$out/bin" 2> "$out/err"; then
        echo "FAIL $1 (compile)"; fail=1; return
    fi
    size=$(wc -c < "$out/bin")
    LC_ALL=C awk -v size="$size" "$lib $2 BEGIN { init(); rw = int((size + 4095) / 4096) * 4096
        header(MEM); code(); b(\"184 231 0 0 0 49 255 15 5\") }" > "$out/want"
    ok=1
    cmp -s "$out/want" "$out/bin" || ok=0
    if [ -n "${AILC2:-}" ]; then
        timeout --signal=KILL $limit "$AILC2" < "$out/src" 2> /dev/null | cmp -s - "$out/bin" || ok=0
    fi
    if [ $ok -eq 1 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

# jumps forward to one label: jump i lands 5 bytes for each jump after it
check bytes_jumps_forward '
    function init() { K = 1398100; MEM = 0 }
    function source(   i) { for (i = 0; i < K; i++) print "jmp a"; print "label a" }
    function code(   i) { for (i = 0; i < K; i++) { printf "%c", 233; r4(5 * (K - 1 - i)) } }'

# jumps back to one label
check bytes_jumps_backward '
    function init() { K = 1398100; MEM = 0 }
    function source(   i) { print "label a"; for (i = 0; i < K; i++) print "jmp a" }
    function code(   i) { for (i = 0; i < K; i++) { printf "%c", 233; r4(-5 * (i + 1)) } }'

# conditional jumps with a value: mov eax, 0 / test rax, rax / jz rel32
check bytes_conditional_jumps '
    function init() { K = 1198371; MEM = 0 }
    function source(   i) { for (i = 0; i < K; i++) print "jz 0 a"; print "label a" }
    function code(   i) { for (i = 0; i < K; i++) {
        printf "%c%c%c%c%c%c%c%c%c%c", 184, 0, 0, 0, 0, 72, 133, 192, 15, 132; r4(14 * (K - 1 - i)) } }'

# calls of one function, which is a jump over it, xor eax, eax and ret
check bytes_calls '
    function init() { K = 1198371; MEM = 0 }
    function source(   i) { print "fn a"; print "end"; for (i = 0; i < K; i++) print "call a" }
    function code(   i) { b("233 3 0 0 0 49 192 195")
        for (i = 0; i < K; i++) { printf "%c", 232; r4(181 - (184 + 5 * i + 5)) } }'

# the address of a buffer: lea rbx, [rip+rel32]
check bytes_buffer_addresses '
    function init() { K = 762600; MEM = 8 }
    function source(   i) { print "buf b 8"; for (i = 0; i < K; i++) print "set b as x" }
    function code(   i) { for (i = 0; i < K; i++) {
        printf "%c%c%c", 72, 141, 29; r4(rw - (176 + 7 * i + 7)) } }'

# the cell of a var, read and written: mov rax, [rip+rel32] / mov [rip+rel32], rax
check bytes_var_cells '
    function init() { K = 762600; MEM = 8 }
    function source(   i) { print "var v"; for (i = 0; i < K; i++) print "set v as v" }
    function code(   i) { for (i = 0; i < K; i++) {
        printf "%c%c%c", 72, 139, 5; r4(rw - (176 + 14 * i + 7))
        printf "%c%c%c", 72, 137, 5; r4(rw - (176 + 14 * i + 14)) } }'

exit $fail

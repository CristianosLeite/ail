#!/bin/sh
# usage: tests/insn.sh            check the compiler against tests/insn.cases
#        tests/insn.sh asm        check the cases against the assembler
#        tests/insn.sh hex '<instructions>'   print the bytes of instructions
#
# The instruction bytes of every statement, checked against bytes that do
# not come from the compiler. A line of tests/insn.cases is
#
#   <source> | <code in hex> | <the same code as instructions>
#
# with " ; " for a line end in the source. The source is compiled, by the
# compiler named by AILC (default build/ailc), and the bytes between the
# image of the runtime, which stands behind the 176-byte header, and the
# end of every program, xor eax, eax and a jump to the service exit, must
# be the hex. A call of a service is in the cases as "call" and four
# bytes that are not compared, written as "........". Four bytes between
# "<" and ">" are a distance to the writable segment, as the assembler
# wrote it for a file of the header and that code alone; the image moves
# the code and with it the segment, and the distance is moved as far
# before it is compared.
# The hex was written by GNU as from the instructions, Intel syntax; the
# second form checks that it still is, and the third prints it for a new
# case. Those two need as and objcopy; the first, which make test runs,
# needs neither.
set -u
cd "$(dirname "$0")/.." || exit 1
ailc=${AILC:-build/ailc}
mkdir -p build/tests
tmp=$(mktemp -d build/tests/insn.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
exit0=31c0e9                  # xor eax, eax ; jmp rel32
# the size of the image: the four bytes at 8 of it
isz=$(od -An -tu4 -j184 -N4 "$ailc" | tr -d ' ')

hexof() {
    od -An -v -tx1 "$@" | tr -d ' \n'
}
# asmhex <instructions>: their bytes in hex
asmhex() {
    printf '.intel_syntax noprefix\n%s\n' "$1" | tr ';' '\n' > "$tmp/a.s"
    as -o "$tmp/a.o" "$tmp/a.s" 2> "$tmp/a.err" &&
        objcopy -O binary -j .text "$tmp/a.o" "$tmp/a.bin" && hexof "$tmp/a.bin"
}

if [ "${1:-}" = hex ]; then
    asmhex "$2" || { cat "$tmp/a.err" >&2; exit 1; }
    echo
    exit 0
fi
mode=${1:-compile}
fail=0
n=0
while IFS= read -r line; do
    case $line in ''|'#'*) continue;; esac
    n=$((n + 1))
    src=${line%% | *}
    rest=${line#* | }
    hex=$(printf '%s' "${rest%% | *}" | tr -d ' ')
    asm=${rest#* | }
    name="insn $(printf '%s' "$src" | cut -c1-40 | tr ' ' '_')"
    if [ "$mode" = asm ]; then
        got=$(asmhex "$asm")
    else
        printf '%s\n' "$src" | sed 's/ ; /\n/g' > "$tmp/src"
        timeout --signal=KILL 10 "$ailc" < "$tmp/src" > "$tmp/out" 2> /dev/null
        got=$(tail -c +$((177 + isz)) "$tmp/out" | hexof)
        case $got in
        *$exit0????????) got=${got%$exit0????????};;
        *) got="no exit: $got";;
        esac
    fi
    if [ "$mode" = asm ]; then
        pat=$(printf '%s' "$hex" | sed 's/e8\.\{8\}/e800000000/g' | tr -d '<>')
    else
        pat=$(printf '%s' "$hex" | tr . '?')
        # a distance to the writable segment: as far as the segment is
        # from where it would be behind the code alone
        delta=$(( ($(wc -c < "$tmp/out") + 4095) / 4096 * 4096 - 4096 - isz ))
        while case $pat in *'<'*) true;; *) false;; esac; do
            rest=${pat#*<}
            d=$(printf '%s' "${rest%%>*}" | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/')
            d=$(printf '%08x' $(( (0x$d + delta) & 0xffffffff )) | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/')
            pat=${pat%%<*}$d${rest#*>}
        done
    fi
    case $got in $pat) same=1;; *) same=0;; esac
    if [ $same -eq 1 ]; then
        echo "ok   $name"
    else
        echo "FAIL $name"; fail=1
        [ -n "${INSN_SHOW:-}" ] && echo "     want $hex" && echo "     got  $got"
    fi
done < tests/insn.cases
[ $n -gt 0 ] || { echo "FAIL insn: no cases"; fail=1; }
exit $fail

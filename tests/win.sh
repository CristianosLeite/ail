#!/bin/sh
# usage: tests/win.sh [all]
#
# Check the compiler for Windows on x86-64, build/ailc-windows-x86_64,
# and the runtime of that platform, by running what it writes under
# Wine. Without wine it prints "skip" and succeeds.
# - hello must run, write its line and end with 0.
# - The compiler compiled for Windows, run under Wine, must write the
#   same hello as the compiler that runs here, report an error of a
#   source with its message and the status 1, and compile its own source
#   to the file it is itself: the fixed point of the port. Its image must
#   be one that Windows loads, which is not for Wine to say.
# - The header of a program must let Windows choose the address of its
#   image, among all 64 bits, and tests/win/moved.aiw must find itself
#   loaded elsewhere than the header names; it is skipped where the
#   loader chooses no address, as Wine does.
# - A program whose image is the largest Windows loads must compile, and
#   one a page larger must be refused.
# - tests/win/start.aiw must start programs of Windows, with their output
#   in a file, a limit of time and an argument that has to be quoted.
# - tests/win/inherit.aiw must find that a child got the descriptors it
#   was given and no other handle, and tests/win/holder.aiw that a held
#   child ends with the process that started it.
# - tests/win/stale.aiw must find that a watch which waited while its
#   socket was closed watches nothing.
# - tests/win/pipe.aiw must find that a pipe as its input and one as
#   its output have no place, and that fstat says of each that it is
#   no file.
# - tests/win/link.aiw must find that openat follows no junction, which
#   cmd makes for it, and that a directory it opened keeps its name. It
#   is skipped where cmd makes no junction.
# - tests/win/access.aiw must find that access follows a junction: 0
#   for one that leads to a directory and -2 for one whose directory
#   is gone. It is skipped where cmd makes no junction.
# - tests/win/private.aiw must make a file and a directory that are
#   the user's alone, with 0x1000000 of openat, in a directory that
#   hands down a right to everybody: icacls of Windows says the rights.
#   What is there and everybody may change is refused with that flag.
#   It is skipped where there is no icacls or no whoami.
# - The command ail must build a package for Windows and run its tests
#   there (docs/cli.md, --target): the executable with its ending, a
#   test that finds its directory and starts the executable, and a test
#   that tests/windows-x86_64.skip names left out.
# - The command ail as a program of Windows (build/windows-x86_64/ail.exe),
#   in an installation of tools/install.sh with the compiler and the
#   formatter of Windows, must make a package, build it, run it, test
#   it, check its format and clean it.
# - The row of ccall in the target file must be the bytes the assembler
#   wrote for its instructions (kept here as hex).
# - The tests of tests/ that have no sys statement, that the compiler for
#   Windows compiles and that tests/win.skip does not name must give
#   their output and status there too: one in twenty of them, or with
#   "all" every one, which takes a few minutes.
set -u
cd "$(dirname "$0")/.." || exit 1
wc=build/ailc-windows-x86_64
pk="target=build/target/windows-x86_64 rt=build/rt/windows-x86_64"
if ! command -v wine > /dev/null 2>&1; then echo "skip win (no wine)"; exit 0; fi
[ -x $wc ] || { echo "FAIL win: no $wc (make $wc)"; exit 1; }
export WINEDEBUG=-all
mkdir -p build/tests
tmp=$(mktemp -d build/tests/win.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
fail=0
limit=20

say() {
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

$wc < examples/hello.aiw > $tmp/hello.exe
[ "$(timeout $limit wine $tmp/hello.exe 2> /dev/null)" = "hello world" ]
say win_hello $?

$wc $pk < compiler/ailc.aiw > $tmp/ailc.exe
r=0
timeout $limit wine $tmp/ailc.exe < examples/hello.aiw > $tmp/hello2.exe 2> /dev/null || r=1
cmp -s $tmp/hello.exe $tmp/hello2.exe || r=1
say win_compiler_runs $r

# the size of its image, at 144 of the file: Windows loads no image above
# 0x77000000 bytes, and Wine loads any
[ "$(od -An -tu4 -j144 -N4 $tmp/ailc.exe | tr -d ' ')" -le 1996488704 ]
say win_compiler_loads $?

# a program too: one whose buffers end at that size is compiled, with the
# size in its header, and one a page above is refused
r=0
echo 'buf a 4096' | $wc > $tmp/small.exe || r=1
s=$(od -An -tu4 -j144 -N4 $tmp/small.exe | tr -d ' ')
n=$((1996488704 - s + 4096))
echo "buf a $n" | $wc > $tmp/top.exe || r=1
[ "$(od -An -tu4 -j144 -N4 $tmp/top.exe | tr -d ' ')" -eq 1996488704 ] || r=1
echo "buf a $((n + 4096))" | $wc > $tmp/over.exe 2> $tmp/err
[ $? -eq 1 ] && [ "$(cat $tmp/err)" = "ailc: buffers too big" ] && [ ! -s $tmp/over.exe ] || r=1
say win_image_limit $r

# the header lets Windows choose where the image is: the characteristics
# at 86 do not say that relocations were taken out (1), and those of
# the loader at 158 say any address (0x40) of 64 bits (0x20)
r=0
[ $(($(od -An -tu2 -j86 -N2 $tmp/hello.exe | tr -d ' ') & 1)) -eq 0 ] || r=1
[ $(($(od -An -tu2 -j158 -N2 $tmp/hello.exe | tr -d ' ') & 96)) -eq 96 ] || r=1
say win_image_moves $r
r=0
$wc < tests/win/moved.aiw > $tmp/moved.exe || r=1
timeout $limit wine $tmp/moved.exe > /dev/null 2>&1
c=$?
if [ $c -eq 77 ]; then
    echo "skip win_image_moved (loaded where the header names)"
else
    [ $c -eq 1 ] || r=1
    say win_image_moved $r
fi

echo frob | timeout $limit wine $tmp/ailc.exe > /dev/null 2> $tmp/err
[ $? -eq 1 ] && [ "$(tr -d '\r' < $tmp/err)" = "ailc: 1: unknown statement" ]
say win_compiler_reports $?

r=0
timeout 120 wine $tmp/ailc.exe $pk < compiler/ailc.aiw > $tmp/ailc2.exe 2> /dev/null || r=1
cmp -s $tmp/ailc.exe $tmp/ailc2.exe || r=1
say win_fixed_point $r

# mov r11, rax / mov r10, rdi / mov rcx, rsi / push rbp / mov rbp, rsp /
# mov eax, 4 / cmp rcx, rax / cmovb rcx, rax / lea rax, [rcx*8+15] /
# and rax, -16 / and rsp, -16 / sub rsp, rax / mov rcx, rsi /
# mov rsi, r10 / mov rdi, rsp / rep movsq / mov rcx, [rsp] /
# mov rdx, [rsp+8] / mov r8, [rsp+16] / mov r9, [rsp+24] / call r11 / leave
want=4989c34989fa4889f1554889e5b8040000004839c1480f42c8488d04cd0f0000004883e0f04883e4f04829c44889f14c89d64889e7f348a5488b0c24488b5424084c8b4424104c8b4c241841ffd3c9
got=$(sed -n 's/^data tccrow 3 0 0 [0-9]* //p' compiler/windows-x86_64/target.aiw | tr ' ' '\n' | while read b; do printf '%02x' "$b"; done)
[ "$got" = "$want" ]
say win_ccall_row $?

# the services of processes, with programs of Windows to start
r=0
for t in sleeper echoarg start; do $wc < tests/win/$t.aiw > $tmp/$t.exe || r=1; done
timeout 60 wine $tmp/start.exe $tmp/hello.exe $tmp/sleeper.exe $tmp/echoarg.exe $tmp/out.txt > /dev/null 2>&1
[ $? -eq 63 ] || r=1
say win_processes $r

# a child inherits what it was given and nothing else
r=0
for t in probe inherit; do $wc < tests/win/$t.aiw > $tmp/$t.exe || r=1; done
timeout 60 wine $tmp/inherit.exe $tmp/hello.exe $tmp/probe.exe $tmp/one.txt $tmp/two.txt > /dev/null 2>&1
[ $? -eq 31 ] || r=1
say win_inherits $r

# a held child ends with the process that started it, and one that is
# not held goes on
r=0
for t in late holder; do $wc < tests/win/$t.aiw > $tmp/$t.exe || r=1; done
timeout 60 wine $tmp/holder.exe 1 $tmp/late.exe $tmp/held.txt > /dev/null 2>&1
[ $? -eq 1 ] || r=1
timeout 60 wine $tmp/holder.exe 0 $tmp/late.exe $tmp/free.txt > /dev/null 2>&1
[ $? -eq 1 ] || r=1
i=0
while [ ! -f $tmp/free.txt ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
[ -f $tmp/free.txt ] || r=1
[ ! -f $tmp/held.txt ] || r=1
say win_held $r

# a watch that waits for its poller while the socket is closed
r=0
$wc < tests/win/stale.aiw > $tmp/stale.exe || r=1
timeout 60 wine $tmp/stale.exe > /dev/null 2>&1
[ $? -eq 3 ] || r=1
say win_stale_watch $r

# seek, pwrite and fstat of a pipe, which the program has as its input
# and its output
r=0
$wc < tests/win/pipe.aiw > $tmp/pipe.exe || r=1
{ echo p | timeout 60 wine $tmp/pipe.exe 2> /dev/null; echo $? > $tmp/pipe.code; } | cat > /dev/null
[ "$(cat $tmp/pipe.code)" = 127 ] || r=1
say win_pipe $r

# no link is followed below an open directory: a junction, which cmd
# makes; the program ends with 77 if it made none
r=0
$wc < tests/win/link.aiw > $tmp/link.exe || r=1
timeout 60 wine $tmp/link.exe $tmp/lk > /dev/null 2>&1
c=$?
if [ $c -eq 77 ]; then
    echo "skip win_openat_link (no junction made)"
else
    [ $c -eq 63 ] || r=1
    say win_openat_link $r
fi

# access follows a junction, to a directory or to nothing; the program
# ends with 77 if cmd made none
r=0
$wc < tests/win/access.aiw > $tmp/access.exe || r=1
timeout 60 wine $tmp/access.exe $tmp/ac > /dev/null 2>&1
c=$?
if [ $c -eq 77 ]; then
    echo "skip win_access_link (no junction made)"
else
    [ $c -eq 63 ] || r=1
    say win_access_link $r
fi

# what openat makes with 0x1000000 is the user's alone: in a directory
# that hands down a right to read to everybody (S-1-1-0), which icacls
# of Windows sets and says; skipped where there is no icacls, as under
# Wine. A thing made without the flag has the entry of everybody (WD),
# one made with it has one entry, for one user, and is protected (P),
# and what is made in such a directory has that entry handed down (ID).
# What is opened with the flag must be the user's alone to change: a
# directory and a file that everybody may read are, and a directory and
# a file that everybody may change (M) are refused. The directory of
# the check takes nothing over from the one above it, where other
# accounts may have a right to change: it has the entry of everybody
# and one for the user, whom whoami of Windows names
r=0
# whoami of Windows, beside its icacls: another whoami.exe may be found first
who=$(dirname "$(command -v icacls.exe 2> /dev/null)" 2> /dev/null)/whoami.exe
if command -v icacls.exe > /dev/null 2>&1 && [ -x "$who" ]; then
    $wc < tests/win/private.aiw > $tmp/private.exe || r=1
    rm -rf $tmp/pv
    mkdir -p $tmp/pv
    me=$("$who" /user /fo csv /nh 2> /dev/null | tr -d '\r"' | cut -d, -f2)
    (cd $tmp && icacls.exe pv /inheritance:r /grant:r "*$me:(OI)(CI)F" '*S-1-1-0:(OI)(CI)R' > /dev/null 2>&1) || r=1
    mkdir $tmp/pv/seen $tmp/pv/loose
    printf 'keep
' > $tmp/pv/read
    printf 'keep
' > $tmp/pv/shared
    (cd $tmp/pv && icacls.exe loose /grant '*S-1-1-0:(OI)(CI)M' > /dev/null 2>&1 && icacls.exe shared /grant '*S-1-1-0:M' > /dev/null 2>&1) || r=1
    timeout 60 wine $tmp/private.exe $tmp/pv > /dev/null 2>&1
    [ $? -eq 127 ] || r=1
    # the rights of the name $2 in the directory $1, as icacls saves them
    acl() { (cd $1 && icacls.exe $2 /save acl.txt > /dev/null 2>&1 && tr -d '\000\r' < acl.txt | sed -n 2p); }
    case "$(acl $tmp/pv plain)" in *';WD)'*) ;; *) r=1 ;; esac
    case "$(acl $tmp/pv file)" in 'D:P(A;;FA;;;S-1-'*')('*) r=1 ;; 'D:P(A;;FA;;;S-1-'*')') ;; *) r=1 ;; esac
    case "$(acl $tmp/pv dir)" in 'D:P(A;OICI;FA;;;S-1-'*')('*) r=1 ;; 'D:P(A;OICI;FA;;;S-1-'*')') ;; *) r=1 ;; esac
    case "$(acl $tmp/pv/dir in)" in 'D:(A;ID;FA;;;S-1-'*')('*) r=1 ;; 'D:(A;ID;FA;;;S-1-'*')') ;; *) r=1 ;; esac
    say win_private $r
else
    echo "skip win_private (no icacls or no whoami)"
fi

# a package built and tested for Windows by the command ail
r=0
mkdir -p $tmp/pkg/src $tmp/pkg/tests
printf 'name pkg\nversion 0.1.0\nbin pkg src/main.aiw\n' > $tmp/pkg/Ailfile
printf 'use "lib/std/io.aiw"\ncall print "pkg\\n"\n' > $tmp/pkg/src/main.aiw
cat > $tmp/pkg/tests/starts.aiw << 'EOF'
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
use "lib/std/file.aiw"
use "lib/std/proc.aiw"
buf b 24
buf av 16
data exe "build/windows-x86_64/pkg.exe" 0
# the directory of the test, named from the top of the package
call procvar "AIL_TMP" as p n
call print p n
call print "\n"
call byadd b p n
call byadd b "/made"
load b as q
load b+8 as m
call fileopen q m 0x241 420 as fd
ifslt fd 0
	rt exit 1
end
rt close fd
# the executable of the package, built for the same target
store av exe
store av+8 0
call procstart av -1 -1 -1 as pid
call procwait pid 0 as st
rt exit st
EOF
printf 'build/windows-x86_64/tests/starts.tmp\npkg\n' > $tmp/pkg/tests/starts.out
printf 'sys exit 0\n' > $tmp/pkg/tests/linux.aiw
printf '# has a sys\nlinux\n' > $tmp/pkg/tests/windows-x86_64.skip
(cd $tmp/pkg && ../../../ail build --target windows-x86_64) > /dev/null 2>&1 || r=1
[ "$(head -c 2 $tmp/pkg/build/windows-x86_64/pkg.exe)" = MZ ] || r=1
got=$(cd $tmp/pkg && timeout 120 ../../../ail test --target windows-x86_64 2> /dev/null) || r=1
[ "$got" = "skip linux
ok   starts
1 test, 0 failed, 1 skipped" ] || r=1
say win_package $r

# AIL installed for Windows: the command makes a package and works on it
r=0
tools/install.sh build $tmp/wp windows > /dev/null 2>&1 || r=1
wa=$PWD/$tmp/wp/bin/ail.exe
chmod +x $tmp/wp/bin/ail.exe $tmp/wp/lib/ail/*.exe 2> /dev/null
(
    unset AIL_HOME
    mkdir $tmp/wk && cd $tmp/wk || exit 1
    v=$(sed -n 's/^version //p' ../../../../Ailfile)
    [ "$(timeout 60 wine $wa version 2> /dev/null | tr -d '\r')" = "ail $v" ] || exit 1
    timeout 60 wine $wa new demo > /dev/null 2>&1 || exit 1
    cd demo || exit 1
    timeout 60 wine $wa build > /dev/null 2>&1 || exit 1
    [ -f build/demo.exe ] || exit 1
    [ "$(timeout 60 wine $wa run 2> /dev/null | tr -d '\r')" = "hello from demo" ] || exit 1
    [ "$(timeout 60 wine $wa test 2> /dev/null | tr -d '\r')" = "ok   hello
1 test, 0 failed" ] || exit 1
    timeout 60 wine $wa fmt --check > /dev/null 2>&1 || exit 1
    timeout 60 wine $wa clean > /dev/null 2>&1 || exit 1
    [ ! -e build ] || exit 1
) || r=1
say win_ail $r

# tests that are run whatever the count: threads that open at once,
# pollers that share nothing or a waker, a watch and a close at once,
# a long time of reap, threads that reap one child, and the number of
# a child that was taken, and the services of the directory, the
# executable, the lock, a program in place of the process and a group
# of processes. One of them that does not compile fails the
# suite; any other test that does not compile is left out
always="rt_open_threads rt_poll_two rt_poll_shared rt_watch_close rt_reap_long rt_reap_many rt_reap_again rt_cwd rt_self rt_kind rt_chmod rt_pid rt_lock rt_become rt_group rt_group_fds rt_seek rt_stat rt_pwrite rt_fstat_dir rt_pwrite_threads rt_time rt_random rt_platform rt_trylock rt_map rt_map_replace rt_lock_device rt_anon rt_kill rt_openat rt_fdpath rt_lockfd rt_sync_dir rt_openat_look rt_openat_kept rt_access rt_temp"
# each of them has to be a test the loop below finds and takes
for t in $always; do
    why=
    [ -f tests/$t.out ] || why="no tests/$t.out"
    [ -f tests/$t.aiw ] || why="no tests/$t.aiw"
    [ -n "$why" ] || ! grep -q '^[[:space:]]*sys ' tests/$t.aiw || why="has a sys"
    ! grep -q "^$t\$" tests/win.skip || why="named in tests/win.skip"
    [ -z "$why" ] || { echo "FAIL win $t (not run: $why)"; fail=1; }
done
n=0
ran=0
for f in tests/*.out; do
    t=$(basename $f .out)
    [ -f tests/$t.aiw ] || continue
    grep -q '^[[:space:]]*sys ' tests/$t.aiw && continue
    grep -q "^$t\$" tests/win.skip && continue
    n=$((n + 1))
    must=0
    case " $always " in *" $t "*) must=1 ;; *) [ "${1:-}" = all ] || [ $((n % 20)) -eq 0 ] || continue ;; esac
    if ! $wc < tests/$t.aiw > $tmp/t.exe 2> $tmp/cerr; then
        # a test of the list has to compile: what the compiler said is
        # shown and the suite fails
        [ $must -eq 1 ] || continue
        cat $tmp/cerr
        echo "FAIL win $t (does not compile)"; fail=1
        continue
    fi
    want=0
    [ -f tests/$t.code ] && want=$(cat tests/$t.code)
    ran=$((ran + 1))
    # twice before it has failed: under Wine a start now and then fails
    # where the program is not at fault
    for try in 1 2; do
        timeout $limit wine $tmp/t.exe < /dev/null > $tmp/got 2> /dev/null
        got=$?
        [ "$got" = "$want" ] && cmp -s $tmp/got tests/$t.out && continue 2
    done
    echo "FAIL win $t"; fail=1
done
[ $ran -gt 0 ]
say "win_tests ($ran run)" $?
exit $fail

#!/bin/sh
# usage: tests/install.sh
#
# An installation, as make install and make dist leave it: a package is
# made, built, run, tested and formatted with nothing but what was
# installed, in a directory outside this checkout and with AIL_HOME not
# set. A command still running after 60 seconds is killed, which fails
# its case.
cd "$(dirname "$0")/.." || exit 1
top=$PWD
version=$(sed -n 's/^version //p' ail.pkg)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
unset AIL_HOME
fail=0

# yes <name> command...: the command, a test of the shell, holds
yes() {
    name=$1
    shift
    if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi
}
# says <name> <stdout> command...: the command ends with status 0, has
# written the text to stdout and nothing to stderr
says() {
    name=$1 want=$2
    shift 2
    "$@" > "$tmp/out" 2> "$tmp/err"
    if [ $? -eq 0 ] && [ "$(cat "$tmp/out")" = "$want" ] && [ ! -s "$tmp/err" ]
    then echo "ok   $name"
    else echo "FAIL $name"; fail=1
    fi
}
# works <name> <prefix>: the installation under the prefix does all of it
works() {
    ail="timeout --signal=KILL 60 $2/bin/ail"
    rm -rf "$tmp/work" && mkdir "$tmp/work" && cd "$tmp/work" || exit 1
    says $1_version "ail $version" $ail version
    $ail new demo > /dev/null && cd demo || exit 1
    says $1_run "hello from demo" $ail run
    says $1_test "ok   hello
1 test, 0 failed" $ail test
    says $1_fmt "" $ail fmt --check
    cd "$top" || exit 1
}

make -s install PREFIX="$tmp/p" > "$tmp/said" 2>&1
yes install_make [ $? -eq 0 ]
yes install_files [ "$(cd "$tmp/p" && find . -type f ! -path './lib/ail/lib/*' | LC_ALL=C sort | tr '\n' ' ')" = "./bin/ail ./lib/ail/LICENSE ./lib/ail/ail.pkg ./lib/ail/ailc ./lib/ail/indent " ]
yes install_library [ "$(cd "$tmp/p/lib/ail" && find lib -type f | sort)" = "$(find lib -type f -name '*.aiw' | sort)" ]
works install "$tmp/p"
# a second time over the first, and with DESTDIR before the prefix
make -s install PREFIX="$tmp/p" > "$tmp/said" 2>&1
yes install_again [ $? -eq 0 ]
make -s install DESTDIR="$tmp/d" PREFIX=/opt/ail > "$tmp/said" 2>&1
yes install_destdir_make [ $? -eq 0 ]
yes install_destdir [ -x "$tmp/d/opt/ail/bin/ail" ] && yes install_destdir_whole [ -x "$tmp/d/opt/ail/lib/ail/ailc" ] && [ -f "$tmp/d/opt/ail/lib/ail/lib/std/io.aiw" ]

# under a mask that keeps new files to their owner, the directories are
# still for everyone, as the files are
(umask 077; make -s install PREFIX="$tmp/m" > "$tmp/said" 2>&1)
yes install_mask_make [ $? -eq 0 ]
yes install_mask_directories [ -z "$(find "$tmp/m" -type d ! -perm 755)" ]
yes install_mask_files [ -z "$(find "$tmp/m" -type f ! -perm 644 ! -perm 755)" ]

# the file of make dist, unpacked elsewhere
# one of a run before is not taken for the one of this run
file=build/ail-$version-x86_64-linux.tar.gz
rm -f "$file"
make -s dist > "$tmp/said" 2>&1
yes dist_make [ $? -eq 0 ]
yes dist_file [ -f "$file" ]
mkdir "$tmp/u" && tar -C "$tmp/u" -xzf "$file"
yes dist_one_directory [ "$(ls "$tmp/u")" = "ail-$version-x86_64-linux" ]
works dist "$tmp/u/ail-$version-x86_64-linux"
rm -f "$file"
exit $fail

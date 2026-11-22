#!/bin/sh
# usage: tests/cli.sh
#
# The command ail, build/ail, on packages it makes in a directory of its
# own: what each command leaves, prints and returns. AIL is found from
# the place of the executable, the checkout this script is in, but for
# the cases that set AIL_HOME. A command still running after 10 seconds
# is killed, which fails its case.
cd "$(dirname "$0")/.." || exit 1
top=$PWD
ail="timeout --signal=KILL 10 $top/build/ail"
version=$(sed -n 's/^version //p' ail.pkg)
mkdir -p build/tests
tmp=$(mktemp -d "$top/build/tests/cli.XXXXXX") || exit 1
away=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp" "$away"' EXIT
trap 'exit 1' HUP INT TERM
unset AIL_HOME
cd "$tmp" || exit 1
fail=0

# is <name> <status> <stdout> <first line of stderr> command...: the
# command ends with the status and has written the two texts
is() {
    name=$1 st=$2 out=$3 err=$4
    shift 4
    "$@" > "$tmp/out" 2> "$tmp/err"
    rc=$?
    if [ $rc -eq "$st" ] && [ "$(cat "$tmp/out")" = "$out" ] && [ "$(head -n 1 "$tmp/err")" = "$err" ]
    then echo "ok   $name"
    else echo "FAIL $name"; fail=1
    fi
}
# yes <name> command...: the command, a test of the shell, holds
yes() {
    name=$1
    shift
    if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi
}

is cli_version 0 "ail $version" "" $ail version
is cli_no_command 2 "" "usage: ail COMMAND" $ail
is cli_unknown_command 2 "" "usage: ail COMMAND" $ail frob
$ail help > "$tmp/help"
yes cli_help_names_every_command sh -c "for c in new init build run clean version help; do grep -q \"^  \$c\" '$tmp/help' || exit 1; done"

# ---- new
is cli_new 0 "created the package demo in demo/" "" $ail new demo
yes cli_new_manifest [ "$(cat demo/ail.pkg)" = "name demo
version 0.1.0
ail $version

bin demo src/main.aiw" ]
yes cli_new_source [ "$(cat demo/src/main.aiw)" = 'use "lib/std/io.aiw"
call print "hello from demo\n"' ]
yes cli_new_gitignore [ "$(cat demo/.gitignore)" = "build/
deps/" ]
is cli_new_twice 4 "" "ail: there is something called that already: demo" $ail new demo
is cli_new_bad_name 2 "" "ail: the name of a package is small letters, digits, - and _, at most 64: not Demo" $ail new Demo
is cli_new_no_name 2 "" "usage: ail COMMAND" $ail new
yes cli_new_bad_name_made_nothing [ ! -e Demo ]

# ---- build, run, clean
cd demo || exit 1
is cli_build 0 "" "" $ail build
yes cli_build_made_the_executable [ -x build/demo ]
yes cli_build_left_no_other_file [ "$(ls build)" = demo ]
is cli_run 0 "hello from demo" "" $ail run
is cli_run_named 0 "hello from demo" "" $ail run demo
is cli_run_unknown 3 "" "ail: ail.pkg has no executable other" $ail run other
is cli_run_two_names 2 "" "usage: ail COMMAND" $ail run demo other
is cli_build_unknown 3 "" "ail: ail.pkg has no executable other" $ail build other
is cli_clean 0 "" "" $ail clean
yes cli_clean_removed_build [ ! -e build ]
is cli_clean_twice 0 "" "" $ail clean
is cli_run_builds 0 "hello from demo" "" $ail run

# a program that says its arguments and where it runs, and ends with 7
cat > src/main.aiw <<'END'
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
use "lib/std/file.aiw"
buf b 24
call argc as c
i=1
while i<c
	call argv i as p n
	call print p n
	call print "\n"
	i+=1
end
call fileread "here" b as r
load b as p
load b+8 as n
call print p n
sys exit_group 7
END
mkdir -p sub/dir
echo "in sub/dir" > sub/dir/here
cd sub/dir || exit 1
is cli_run_arguments_directory_status 7 "one
--
two words
in sub/dir" "" $ail run -- one -- "two words"
is cli_run_named_arguments 7 "x
in sub/dir" "" $ail run demo -- x
cd ../.. || exit 1
yes cli_build_from_below_is_in_the_root [ -x build/demo ] && yes cli_no_build_below [ ! -e sub/dir/build ]

# a source that does not compile: the status 1, what the compiler says,
# the executable of before, and no file left beside it
cp build/demo "$tmp/before"
echo "frob" >> src/main.aiw
is cli_build_error 1 "" "ailc: 18: unknown statement" $ail build
yes cli_build_error_keeps_the_executable cmp -s build/demo "$tmp/before"
yes cli_build_error_leaves_no_file [ "$(ls build)" = demo ]
is cli_run_error 1 "" "ailc: 18: unknown statement" $ail run
rm src/main.aiw
is cli_build_no_source 4 "" "ail: cannot read src/main.aiw" $ail build

# several executables, and one built for the tests only
printf 'use "lib/std/io.aiw"\ncall print "one\\n"\n' > src/one.aiw
printf 'use "lib/std/io.aiw"\ncall print "two\\n"\n' > src/two.aiw
printf 'name demo\nversion 0.1.0\nbin one src/one.aiw\nbin two src/two.aiw\ntestbin three src/two.aiw\n' > ail.pkg
$ail clean
is cli_build_all 0 "" "" $ail build
yes cli_build_all_but_testbin [ "$(ls build | tr '\n' ' ')" = "one two " ]
is cli_build_one_testbin 0 "" "" $ail build three
yes cli_build_testbin_made [ -x build/three ]
is cli_run_ambiguous 2 "" "ail: ail.pkg has more than one executable; name the one to run" $ail run
is cli_run_one_of_two 0 "two" "" $ail run two
is cli_build_two_names 2 "" "usage: ail COMMAND" $ail build one two

# ---- the manifest
printf 'name demo\nversion 0.1.0\n' > ail.pkg
is cli_build_no_bin 0 "" "ail: ail.pkg names no executable to build" $ail build
is cli_run_no_bin 3 "" "ail: ail.pkg names no executable to run" $ail run
printf 'name demo\nversion 0.1.0\nlicense MIT\n' > ail.pkg
is cli_manifest_wrong 3 "" "ail: ail.pkg:3: a key that is none of name, version, ail, bin, testbin and dep" $ail build
printf 'version 0.1.0\n' > ail.pkg
is cli_manifest_no_name 3 "" "ail: ail.pkg: no line with the name" $ail build
printf 'name demo\nversion 0.1.0\nail 999.0.0\nbin one src/one.aiw\n' > ail.pkg
is cli_manifest_newer_ail 3 "" "ail: ail.pkg asks for AIL 999.0.0, which AIL $version is not" $ail build
printf 'name demo\nversion 0.1.0\nail 0.0.1\nbin one src/one.aiw\n' > ail.pkg
is cli_manifest_older_ail 0 "one" "" $ail run
# no manifest in a directory or above it: one outside this checkout,
# which has the manifest of AIL at its top
cd "$away" || exit 1
is cli_no_manifest 3 "" "ail: no ail.pkg in this directory or in one above it" $ail build

# ---- init
cd "$tmp" || exit 1
mkdir fresh && cd fresh || exit 1
is cli_init 0 "created the package fresh in this directory" "" $ail init
is cli_init_runs 0 "hello from fresh" "" $ail run
is cli_init_twice 4 "" "ail: this directory has an ail.pkg already" $ail init
cd "$tmp" && mkdir Odd && cd Odd || exit 1
is cli_init_bad_directory_name 2 "" "ail: the name of a package is small letters, digits, - and _, at most 64: not Odd" $ail init
yes cli_init_bad_name_made_nothing [ -z "$(ls -A)" ]
mkdir src && echo "# mine" > src/main.aiw && echo "mine" > .gitignore
is cli_init_named 0 "created the package odd in this directory" "" $ail init odd
yes cli_init_keeps_a_source [ "$(cat src/main.aiw)" = "# mine" ]
yes cli_init_keeps_gitignore [ "$(cat .gitignore)" = "mine" ]
yes cli_init_named_manifest grep -q "^name odd$" ail.pkg

# ---- where AIL is
cd "$tmp/fresh" || exit 1
is cli_home_named 0 "ail $version" "" env AIL_HOME="$top" $ail version
is cli_home_relative 0 "hello from fresh" "" env AIL_HOME="../../../.." $ail run
is cli_home_wrong 4 "" "ail: AIL is not where this command looks for it; AIL_HOME names its directory" env AIL_HOME="$tmp" $ail version
# an installation: the command in bin/, the rest in lib/ail/
mkdir -p "$tmp/inst/bin" "$tmp/inst/lib/ail"
cp "$top/build/ail" "$tmp/inst/bin/ail"
cp "$top/build/ailc" "$top/ail.pkg" "$tmp/inst/lib/ail/"
cp -r "$top/lib" "$tmp/inst/lib/ail/lib"
is cli_home_installed 0 "hello from fresh" "" "$tmp/inst/bin/ail" run
exit $fail

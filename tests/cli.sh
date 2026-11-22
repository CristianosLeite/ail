#!/bin/sh
# usage: tests/cli.sh
#
# The command ail, build/ail, on packages it makes in a directory of its
# own: what each command leaves, prints and returns. AIL is found from
# the place of the executable, the checkout this script is in, but for
# the cases that set AIL_HOME. A command still running after 60 seconds
# is killed, which fails its case; one case waits the 10 seconds that a
# test of a package may run.
cd "$(dirname "$0")/.." || exit 1
top=$PWD
ail="timeout --signal=KILL 60 $top/build/ail"
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
    else echo "FAIL $name"; fail=1;
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
yes cli_help_names_every_command sh -c "for c in new init add remove update build run test fmt clean version help; do grep -q \"^  \$c\" '$tmp/help' || exit 1; done"

# ---- new
is cli_new 0 "created the package demo in demo/" "" $ail new demo
yes cli_new_manifest [ "$(cat demo/ail.pkg)" = "name demo
version 0.1.0
ail $version

bin demo src/main.aiw" ]
yes cli_new_source [ "$(cat demo/src/main.aiw)" = 'use "lib/std/io.aiw"
call print "hello from demo\n"' ]
yes cli_new_test [ "$(cat demo/tests/hello.aiw | tail -n 2)" = 'use "lib/std/io.aiw"
call print "a test of demo\n"' ] && yes cli_new_test_output [ "$(cat demo/tests/hello.out)" = "a test of demo" ]
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
# an executable can be run whatever mask the user has for new files
is cli_build_mask 0 "" "" sh -c "umask 0177; $ail build"
yes cli_build_mask_executable [ -x build/demo ]
is cli_run_mask 0 "hello from demo" "" sh -c "umask 0177; $ail run"
# with its input closed, and its output: the files it opens do not take
# their numbers
$ail clean
is cli_build_input_closed 0 "" "" sh -c "$ail build <&-"
yes cli_build_input_closed_made [ -x build/demo ]
is cli_run_input_closed 0 "hello from demo" "" sh -c "$ail run <&-"
$ail clean
sh -c "$ail build >&-" 2> "$tmp/err"
yes cli_build_output_closed [ $? -eq 0 ] && yes cli_build_output_closed_made [ -x build/demo ]
is cli_clean 0 "" "" $ail clean
yes cli_clean_removed_build [ ! -e build ]
is cli_clean_twice 0 "" "" $ail clean
is cli_run_builds 0 "hello from demo" "" $ail run

# ---- test and fmt, on the package as new made it
is cli_test_new 0 "ok   hello
1 test, 0 failed" "" $ail test
is cli_fmt_check_new 0 "" "" $ail fmt --check
mkdir -p "$tmp/keep" && cp -r tests "$tmp/keep/tests"
# a test for each thing a test can expect, and each way to fail it
printf 'frob\n' > tests/refused.aiw
printf 'ailc: 1: unknown statement\n' > tests/refused.err
printf 'frob\n' > tests/refused_otherwise.aiw
printf 'ailc: 1: syntax error\n' > tests/refused_otherwise.err
printf 'set 1 as x\n' > tests/not_refused.aiw
printf 'ailc: 1: syntax error\n' > tests/not_refused.err
printf 'use "lib/std/io.aiw"\ncall print "out\\n"\ncall eprint "to stderr\\n"\nsys exit_group 3\n' > tests/status.aiw
echo out > tests/status.out
echo 3 > tests/status.code
cp tests/status.aiw tests/status_other.aiw
echo out > tests/status_other.out
cp tests/status.aiw tests/output_other.aiw
echo 3 > tests/output_other.code
echo other > tests/output_other.out
printf 'frob\n' > tests/no_compile.aiw
printf 'store 0 1\n' > tests/signal.aiw
printf 'label a\njmp a\n' > tests/spin.aiw
# one that writes into its directory, which is empty and is its own
cat > tests/tmp.aiw <<'END'
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
use "lib/std/file.aiw"
use "lib/std/proc.aiw"
buf b 24
call procvar "AIL_TMP" as p n
call filenames p n b as k
call putn k
call byadd b p n
call byadd b "/made"
load b as q
load b+8 as m
call filewrite q m "x" as r
call putn r
# the directory is build/tests/tmp.tmp of the package
call print p+n-20 20
call print "\n"
# and AIL_HOME names the directory of AIL, which has its manifest
call procvar "AIL_HOME" as p n
call bycut b 0
call byadd b p n
call byadd b "/ail.pkg"
load b as q
load b+8 as m
buf t 24
call fileread q m t as r
# an error is a number below zero, which is no number above it
x=0
ifsgt r 0
	x=1
end
call putn x
call print "\n"
END
printf '00/build/tests/tmp.tmp\n1\n' > tests/tmp.out
mkdir tests/lib && printf '# no test: a file that tests use\nfrob\n' > tests/lib/part.aiw
is cli_test_all 1 "ok   hello
FAIL no_compile
FAIL not_refused
FAIL output_other
ok   refused
FAIL refused_otherwise
FAIL signal
FAIL spin
ok   status
FAIL status_other
ok   tmp
11 tests, 7 failed" "ail: it does not compile, see build/tests/no_compile.err" $ail test
yes cli_test_says_why [ "$(cat "$tmp/err")" = "ail: it does not compile, see build/tests/no_compile.err
ail: the compiler was to refuse it as tests/not_refused.err says, and said build/tests/not_refused.err
ail: it was to print what tests/output_other.out has, and printed build/tests/output_other.out
ail: the compiler was to refuse it as tests/refused_otherwise.err says, and said build/tests/refused_otherwise.err
ail: it ended with the signal 11, not with the status 0
ail: it still ran after 10 seconds and was killed
ail: it ended with the status 3, not with the status 0" ]
yes cli_test_keeps_what_was_printed [ "$(cat build/tests/output_other.out)" = out ] && yes cli_test_keeps_stderr [ "$(cat build/tests/status.log)" = "to stderr" ]
yes cli_test_removes_its_directory [ ! -e build/tests/tmp.tmp ]
is cli_test_named 0 "ok   refused
ok   status
2 tests, 0 failed" "" $ail test status refused
is cli_test_named_missing 1 "FAIL nope
1 test, 1 failed" "ail: there is no test tests/nope.aiw" $ail test nope
# two tests of which one is called like a file of the other
printf 'use "lib/std/io.aiw"\ncall print "first\\n"\n' > tests/a.aiw && echo first > tests/a.out
printf 'use "lib/std/io.aiw"\ncall print "second\\n"\n' > tests/a.out.aiw && echo second > tests/a.out.out
is cli_test_names_overlap 0 "ok   a
ok   a.out
2 tests, 0 failed" "" $ail test a a.out
yes cli_test_names_overlap_kept [ "$(cat build/tests/a.out)" = first ]
rm tests/a.*
# a test that the compiler never comes back from: a file it uses is a
# pipe that nothing writes to
mkdir -p tests/lib && mkfifo tests/lib/pipe.aiw
printf 'use "tests/lib/pipe.aiw"\n' > tests/hang.aiw
is cli_test_compiler_deadline 1 "FAIL hang
1 test, 1 failed" "ail: the compiler still ran after 10 seconds and was killed" $ail test hang
rm tests/hang.aiw tests/lib/pipe.aiw
# two runs at the same time: a test that writes into its directory, waits
# and reads it again finds its file both times
cat > tests/slow.aiw <<'END'
use "lib/std/io.aiw"
use "lib/std/bytes.aiw"
use "lib/std/file.aiw"
use "lib/std/proc.aiw"
buf b 24
buf t 16
buf got 24
call procvar "AIL_TMP" as p n
call byadd b p n
call byadd b "/mine"
load b as q
load b+8 as m
call filewrite q m "x" as r
store t 1
sys nanosleep t 0
call fileread q m got as r
call putn r==1
call print "\n"
END
echo 1 > tests/slow.out
$ail test slow > "$tmp/one" 2>&1 &
other=$!
is cli_test_two_runs 0 "ok   slow
1 test, 0 failed" "" $ail test slow
wait $other
yes cli_test_two_runs_other_status [ $? -eq 0 ]
yes cli_test_two_runs_other [ "$(cat "$tmp/one")" = "ok   slow
1 test, 0 failed" ]
rm tests/slow.*
# what a test expects is there and cannot be read: the test has failed,
# also where it does what a test without that file is to do
printf 'sys exit_group 0\n' > tests/quiet.aiw && echo 0 > tests/quiet.code && chmod 000 tests/quiet.code
is cli_test_code_unreadable 1 "FAIL quiet
1 test, 1 failed" "ail: cannot read tests/quiet.code" $ail test quiet
chmod 600 tests/quiet.code && rm tests/quiet.code && : > tests/quiet.out && chmod 000 tests/quiet.out
is cli_test_out_unreadable 1 "FAIL quiet
1 test, 1 failed" "ail: it was to print what tests/quiet.out has, and printed build/tests/quiet.out" $ail test quiet
chmod 600 tests/quiet.out && rm tests/quiet.*
# AIL_TMP and AIL_HOME are in the environment of a test once each, also
# when the command was started with them set
cat > tests/once.aiw <<'END'
use "lib/std/io.aiw"
use "lib/std/proc.aiw"
call procenv as e
tmps=0
homes=0
label next
load e as s
if s
	load s as x
	# "AIL_TMP=" and "AIL_HOME" as the eight bytes are read
	if x==0x3d504d545f4c4941
		tmps+=1
	end
	if x==0x454d4f485f4c4941
		homes+=1
	end
	e+=8
	jmp next
end
call putn tmps
call putn homes
call print "\n"
END
echo 11 > tests/once.out
is cli_test_environment_once 0 "ok   once
1 test, 0 failed" "" env AIL_TMP=elsewhere AIL_HOME="$top" $ail test once
rm tests/once.*
# a package without tests/, and one whose tests/ cannot be read
mv tests "$tmp/keep/moved"
is cli_test_no_directory 0 "0 tests, 0 failed" "" $ail test
mkdir tests && chmod 000 tests
is cli_test_directory_unreadable 4 "" "ail: cannot read the directory tests" $ail test
chmod 700 tests && rmdir tests && mv "$tmp/keep/moved" tests
# a name that is a path is no name of a test: nothing outside tests/
# is read, and nothing outside build/tests/ written or removed
mkdir -p victim.tmp && printf 'sys exit_group 0\n' > outside.aiw
is cli_test_name_path 2 "" "ail: the name of a test is that of its file in tests/, without a /: not ../outside" $ail test ../outside
is cli_test_name_empty 2 "" "ail: the name of a test is that of its file in tests/, without a /: not " $ail test ""
yes cli_test_name_path_removed_nothing [ -d victim.tmp ] && yes cli_test_name_path_wrote_nothing [ ! -e build/outside ]
rm -r victim.tmp outside.aiw
# fmt: the lines that are not indented, then the files written again; a
# file below a directory with a dot, in build/ or in deps/ is not looked at
printf 'fn f\ncall g\nend\n' > src/x.aiw
mkdir -p .hidden deps/d build && cp src/x.aiw .hidden/ && cp src/x.aiw deps/d/ && cp src/x.aiw build/x.aiw
# a link to a directory or to a source is not followed
mkdir "$tmp/elsewhere" && cp src/x.aiw "$tmp/elsewhere/y.aiw"
ln -s "$tmp/elsewhere" linked && ln -s "$tmp/elsewhere/y.aiw" src/z.aiw
is cli_fmt_check 1 "src/x.aiw:2" "" $ail fmt --check
is cli_fmt 0 "" "" $ail fmt
yes cli_fmt_wrote [ "$(cat src/x.aiw)" = "fn f
	call g
end" ]
yes cli_fmt_left_the_rest cmp -s .hidden/x.aiw deps/d/x.aiw
yes cli_fmt_left_what_a_link_names cmp -s .hidden/x.aiw "$tmp/elsewhere/y.aiw"
rm linked src/z.aiw
# a directory that cannot be read is not passed over as one without sources
mkdir src/closed && cp .hidden/x.aiw src/closed/ && chmod 000 src/closed
is cli_fmt_check_unreadable 4 "" "ail: cannot read the directories of the package" $ail fmt --check
is cli_fmt_unreadable 4 "" "ail: cannot read the directories of the package" $ail fmt
chmod 700 src/closed && rm -r src/closed
is cli_fmt_check_after 0 "" "" $ail fmt --check
is cli_fmt_usage 2 "" "usage: ail COMMAND" $ail fmt --all
rm -rf tests src/x.aiw .hidden deps && cp -r "$tmp/keep/tests" tests
# the executables are built before the tests: a test runs one
printf 'use "lib/std/io.aiw"\nuse "lib/std/bytes.aiw"\nuse "lib/std/file.aiw"\nbuf b 24\ncall fileread "build/demo" b as r\nx=0\nifsgt r 0\n\tx=1\nend\ncall putn x\ncall print "\\n"\n' > tests/has_bin.aiw
echo 1 > tests/has_bin.out
$ail clean
is cli_test_builds_first 0 "ok   has_bin
ok   hello
2 tests, 0 failed" "" $ail test
rm tests/has_bin.*
$ail clean && $ail build

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

# a manifest that cannot be read is not passed over for one above it
mkdir -p inner && echo "name inner" > inner/ail.pkg && chmod 000 inner/ail.pkg
cd inner || exit 1
is cli_manifest_unreadable 4 "" "ail: cannot read ail.pkg" $ail build
is cli_manifest_unreadable_clean 4 "" "ail: cannot read ail.pkg" $ail clean
cd .. || exit 1
yes cli_manifest_unreadable_left_build [ -d build ]
chmod 600 inner/ail.pkg && rm -r inner

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
# a file that is there and cannot be read is there
cd "$tmp" && mkdir locked && cd locked || exit 1
mkdir src && echo "# mine" > src/main.aiw && chmod 200 src/main.aiw
is cli_init_unreadable_source 0 "created the package locked in this directory" "" $ail init
chmod 600 src/main.aiw
yes cli_init_kept_unreadable_source [ "$(cat src/main.aiw)" = "# mine" ]
echo "name mine" > ail.pkg && chmod 200 ail.pkg
is cli_init_unreadable_manifest 4 "" "ail: this directory has an ail.pkg already" $ail init
chmod 600 ail.pkg
yes cli_init_kept_unreadable_manifest [ "$(cat ail.pkg)" = "name mine" ]

# a package that is called ail, as AIL is, builds: its name is not given
# to the compiler beside the library of that name
cd "$tmp" || exit 1
is cli_new_called_ail 0 "created the package ail in ail/" "" $ail new ail
cd ail || exit 1
is cli_run_called_ail 0 "hello from ail" "" $ail run
is cli_test_called_ail 0 "ok   hello
1 test, 0 failed" "" $ail test

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

# ---- dependencies, from repositories of git made here: none of it
# reaches a network
if ! git --version > /dev/null 2>&1; then
    echo "skip cli_deps (no git)"
    exit $fail
fi
g="git -c user.name=test -c user.email=test@example.invalid -c init.defaultBranch=main -c advice.detachedHead=false"
# lastis <name> <status> <last line of stderr> command...: for a command
# whose first lines on stderr are those of git
lastis() {
    name=$1 st=$2 err=$3
    shift 3
    "$@" > "$tmp/out" 2> "$tmp/err"
    rc=$?
    if [ $rc -eq "$st" ] && [ "$(tail -n 1 "$tmp/err")" = "$err" ]
    then echo "ok   $name"
    else echo "FAIL $name"; fail=1
    fi
}
mkdir "$tmp/d" && cd "$tmp/d" || exit 1
r=$tmp/d
# base: 1.0.0 at a plain tag, 1.1.0 at a tag with a message, and a tag
# that is no version
$ail new base > /dev/null && cd base || exit 1
mkdir src/lib
printf 'fn basehi\n\tcall print "base 1.0.0\\n"\nend\n' > src/lib/hi.aiw
sed -i 's/^version .*/version 1.0.0/' ail.pkg
$g add -A && $g commit -qm one && $g tag v1.0.0 && $g tag other
sed -i 's/1\.0\.0/1.1.0/' src/lib/hi.aiw ail.pkg
$g commit -qam two && $g tag -a v1.1.0 -m "with a message"
base10=$($g rev-parse 'v1.0.0^{commit}') base11=$($g rev-parse 'v1.1.0^{commit}')
# mid uses base 1.0.0 and is 0.3.0
cd "$r" && $ail new mid > /dev/null && cd mid || exit 1
is cli_add_version 0 "added base 1.0.0" "" $ail add "$r/base" 1.0.0
mkdir src/lib
printf 'use "lib/std/io.aiw"\nuse "base:src/lib/hi.aiw"\nfn midhi\n\tcall print "mid\\n"\n\tcall basehi\nend\n' > src/lib/mid.aiw
sed -i 's/^version .*/version 0.3.0/' ail.pkg
$g add -A && $g commit -qm one && $g tag v0.3.0
mid03=$($g rev-parse 'v0.3.0^{commit}')
yes cli_add_ignores_deps_in_git [ -z "$($g status --porcelain)" ]

# app uses mid, and base through it
cd "$r" && $ail new app > /dev/null && cd app || exit 1
is cli_add_latest 0 "added mid 0.3.0" "" $ail add "$r/mid"
yes cli_add_manifest_line [ "$(tail -n 1 ail.pkg)" = "dep mid 0.3.0 $r/mid" ]
yes cli_add_lock [ "$(cat ail.lock)" = "# The revisions of the dependencies, written by ail; keep it with the sources.
mid 0.3.0 $mid03 $r/mid
base 1.0.0 $base10 $r/base" ]
yes cli_add_fetched [ -f deps/mid/ail.pkg ] && yes cli_add_fetched_its_dependency [ -f deps/base/ail.pkg ]
yes cli_add_left_no_other_file [ "$(ls -A deps | tr '\n' ' ')" = "base mid " ]
printf 'use "lib/std/io.aiw"\nuse "mid:src/lib/mid.aiw"\ncall midhi\n' > src/main.aiw
is cli_deps_run 0 "mid
base 1.0.0" "" $ail run
# a file of a dependency is not named without it, and a test has them too
printf 'use "lib/std/io.aiw"\nuse "base:src/lib/hi.aiw"\ncall basehi\n' > tests/dep.aiw
echo "base 1.0.0" > tests/dep.out
is cli_deps_test 0 "ok   dep
ok   hello
2 tests, 0 failed" "" $ail test
rm tests/dep.*
# built again without git: what is in deps/ at its revision is not asked for
is cli_deps_no_git_needed 0 "mid
base 1.0.0" "" timeout --signal=KILL 60 env PATH=/nonexistent "$top/build/ail" run
# the lock decides, not the tag: the tag moved, the clones gone
$g -C "$r/base" tag -f v1.0.0 "$base11" > /dev/null
rm -rf deps
is cli_deps_lock_decides 0 "mid
base 1.0.0" "" $ail run
yes cli_deps_lock_unchanged grep -q "^base 1.0.0 $base10 " ail.lock
$g -C "$r/base" tag -f v1.0.0 "$base10" > /dev/null
# a clone at another revision is brought to that of the lock
$g -C deps/base checkout -q "$base11"
is cli_deps_clone_moved 0 "mid
base 1.0.0" "" $ail run
# without a lock it is written again from the tags
rm ail.lock
is cli_deps_lock_rewritten 0 "" "" $ail build
yes cli_deps_lock_same grep -q "^base 1.0.0 $base10 $r/base$" ail.lock
# the same package in two versions: refused, and nothing is changed
cp ail.pkg "$tmp/pkg" && cp ail.lock "$tmp/lock"
is cli_add_conflict 3 "" "ail: the package base is asked for twice, and not as the same version or directory" $ail add "$r/base"
yes cli_add_conflict_manifest cmp -s ail.pkg "$tmp/pkg" && yes cli_add_conflict_lock cmp -s ail.lock "$tmp/lock"
is cli_add_same_version 0 "added base 1.0.0" "" $ail add "$r/base" 1.0.0
is cli_update_conflict 3 "" "ail: the package base is asked for twice, and not as the same version or directory" $ail update base
yes cli_update_conflict_manifest grep -q "^dep base 1.0.0 " ail.pkg
is cli_remove 0 "removed base" "" $ail remove base
yes cli_remove_manifest [ "$(grep -c '^dep ' ail.pkg)" = 1 ]
# mid still uses base: its clone stays, and nothing is fetched again
yes cli_remove_keeps_a_clone_in_use [ -f deps/base/ail.pkg ]
is cli_remove_still_runs 0 "mid
base 1.0.0" "" timeout --signal=KILL 60 env PATH=/nonexistent "$top/build/ail" run
is cli_remove_unknown 3 "" "ail: ail.pkg has no dependency base" $ail remove base
is cli_remove_last 0 "removed mid" "" $ail remove mid
yes cli_remove_no_lock [ ! -e ail.lock ] && yes cli_remove_clone [ ! -e deps/mid ]
is cli_remove_no_name 2 "" "usage: ail COMMAND" $ail remove

# update: to the latest tag, in the manifest and in the lock
is cli_update_setup 0 "added base 1.0.0" "" $ail add "$r/base" 1.0.0
printf 'use "lib/std/io.aiw"\nuse "base:src/lib/hi.aiw"\ncall basehi\n' > src/main.aiw
is cli_update_before 0 "base 1.0.0" "" $ail run
is cli_update 0 "base 1.0.0 -> 1.1.0" "" $ail update
yes cli_update_manifest [ "$(tail -n 1 ail.pkg)" = "dep base 1.1.0 $r/base" ]
yes cli_update_lock grep -q "^base 1.1.0 $base11 $r/base$" ail.lock
is cli_update_after 0 "base 1.1.0" "" $ail run
is cli_update_latest 0 "base 1.1.0 is the latest" "" $ail update base
is cli_update_unknown 3 "" "ail: ail.pkg has no dependency from a repository called nope" $ail update nope
$ail remove base > /dev/null

# a package in a directory, with the one it fetches
is cli_add_path 0 "added mid from ../mid" "" $ail add --path ../mid
yes cli_add_path_manifest [ "$(tail -n 1 ail.pkg)" = "dep mid ../mid" ]
printf 'use "lib/std/io.aiw"\nuse "mid:src/lib/mid.aiw"\ncall midhi\n' > src/main.aiw
is cli_path_run 0 "mid
base 1.0.0" "" $ail run
yes cli_path_lock_has_only_git [ "$(grep -c . ail.lock)" = 2 ] && yes cli_path_not_copied [ ! -e deps/mid ]
$ail remove mid > /dev/null
cd src || exit 1
is cli_add_path_from_below 0 "added mid from $r/app/src/../../mid" "" $ail add --path ../../mid
cd .. || exit 1
is cli_path_from_below_runs 0 "mid
base 1.0.0" "" $ail run
$ail remove mid > /dev/null

# one directory under two paths is one package: shared is named by app
# as ../shared and by user, a package beside it, as ../shared from there
mkdir -p "$r/shared/src" "$r/user/src"
printf 'name shared\nversion 1.0.0\n' > "$r/shared/ail.pkg"
printf 'fn sharedhi\n\tcall print "shared\\n"\nend\n' > "$r/shared/src/hi.aiw"
printf 'name user\nversion 1.0.0\ndep shared ../shared\n' > "$r/user/ail.pkg"
printf 'use "lib/std/io.aiw"\nuse "shared:src/hi.aiw"\nfn userhi\n\tcall sharedhi\nend\n' > "$r/user/src/hi.aiw"
$ail add --path ../shared > /dev/null
is cli_path_same_directory 0 "added user from ../user" "" $ail add --path ../user
printf 'use "lib/std/io.aiw"\nuse "user:src/hi.aiw"\nuse "shared:src/hi.aiw"\ncall userhi\ncall sharedhi\n' > src/main.aiw
is cli_path_same_directory_runs 0 "shared
shared" "" $ail run
# another directory under the same name is still refused
mkdir "$r/elsewhere" && cp -r "$r/shared" "$r/elsewhere/shared"
sed -i 's|^dep shared .*|dep shared ../elsewhere/shared|' ail.pkg
is cli_path_other_directory 3 "" "ail: the package shared is asked for twice, and not as the same version or directory" $ail build
# the same in a package whose directory may be entered and not listed
chmod 333 .
is cli_path_other_directory_unlisted 3 "" "ail: the package shared is asked for twice, and not as the same version or directory" $ail build
chmod 755 .
sed -i '/^dep /d' ail.pkg

# a build that has to write the lock and cannot leaves the lock whole:
# the manifest asks for another version than the lock has
$ail add "$r/base" 1.0.0 > /dev/null
cp ail.lock "$tmp/lock" && sed -i 's|^dep base 1.0.0|dep base 1.1.0|' ail.pkg && mkdir ail.lock.new
is cli_build_lock_unwritable 4 "" "ail: cannot write ail.lock" $ail build
yes cli_build_lock_unwritable_whole cmp -s ail.lock "$tmp/lock"
rmdir ail.lock.new && $ail remove base > /dev/null

# a manifest written by hand, with no lock, is enough
printf 'dep base 1.1.0 %s\n' "$r/base" >> ail.pkg
printf 'use "lib/std/io.aiw"\nuse "base:src/lib/hi.aiw"\ncall basehi\n' > src/main.aiw
rm -rf deps ail.lock
is cli_deps_by_hand 0 "base 1.1.0" "" $ail run
yes cli_deps_by_hand_lock grep -q "^base 1.1.0 $base11 $r/base$" ail.lock
$ail remove base > /dev/null

# a failure after the manifest was written puts it back: here the lock
# cannot be written, since its name with ".new" is taken by a directory
is cli_undo_setup 0 "added base 1.0.0" "" $ail add "$r/base" 1.0.0
cp ail.pkg "$tmp/pkg" && cp ail.lock "$tmp/lock" && mkdir ail.lock.new
is cli_update_lock_unwritable 4 "" "ail: cannot write ail.lock" $ail update
yes cli_update_lock_unwritable_manifest cmp -s ail.pkg "$tmp/pkg" && yes cli_update_lock_unwritable_lock cmp -s ail.lock "$tmp/lock"
rmdir ail.lock.new && $ail remove base > /dev/null

# nor is the file a manifest or a lock is written to before it gets the
# name: a link there is replaced, and what it named is as it was
echo precious > "$tmp/precious"
ln -s "$tmp/precious" ail.pkg.new && ln -s "$tmp/precious" ail.lock.new
is cli_write_through_no_link 0 "added base 1.0.0" "" $ail add "$r/base" 1.0.0
yes cli_write_through_no_link_target [ "$(cat "$tmp/precious")" = precious ]
yes cli_write_through_no_link_files [ ! -L ail.pkg ] && yes cli_write_through_no_link_left [ ! -e ail.pkg.new ]
yes cli_write_through_no_link_lock [ ! -L ail.lock ] && yes cli_write_through_no_link_lock_left [ ! -e ail.lock.new ]
$ail remove base > /dev/null
# the file that the words of git are kept in is never a link to another
echo precious > "$tmp/precious" && mkdir -p deps && ln -s "$tmp/precious" deps/.git-said
is cli_git_output_link 0 "added base 1.0.0" "" $ail add "$r/base" 1.0.0
yes cli_git_output_link_target [ "$(cat "$tmp/precious")" = precious ]
$ail remove base > /dev/null

# a lock that is there and cannot be read is not taken for none: the
# revisions it has are not replaced by what the tags name now
$ail add "$r/base" 1.0.0 > /dev/null
cp ail.pkg "$tmp/pkg" && cp ail.lock "$tmp/lock" && chmod 000 ail.lock
is cli_lock_unreadable_build 4 "" "ail: cannot read ail.lock" $ail build
is cli_lock_unreadable_update 4 "" "ail: cannot read ail.lock" $ail update
is cli_lock_unreadable_add 4 "" "ail: cannot read ail.lock" $ail add "$r/mid"
is cli_lock_unreadable_remove 4 "" "ail: cannot read ail.lock" $ail remove base
chmod 600 ail.lock
yes cli_lock_unreadable_made_no_clone [ ! -e deps/.new ]
yes cli_lock_unreadable_fetched_nothing [ ! -e deps/mid ]
yes cli_lock_unreadable_manifest cmp -s ail.pkg "$tmp/pkg" && yes cli_lock_unreadable_lock cmp -s ail.lock "$tmp/lock"
$ail remove base > /dev/null

# what is refused
cp ail.pkg "$tmp/pkg"
is cli_add_usage 2 "" "usage: ail COMMAND" $ail add
is cli_add_option 2 "" "ail: an address or a directory in a manifest has no space and does not start with # or -: not --frob" $ail add --frob x
mkdir "$r/two words" && cp "$r/mid/ail.pkg" "$r/two words/"
is cli_add_path_with_space 2 "" "ail: an address or a directory in a manifest has no space and does not start with # or -: not ../two words" $ail add --path "../two words"
is cli_add_address_comment 2 "" "ail: an address or a directory in a manifest has no space and does not start with # or -: not #base" $ail add "#base"
is cli_add_address_empty 2 "" "ail: an address or a directory in a manifest has no space and does not start with # or -: not " $ail add ""
is cli_add_bad_version 2 "" "ail: a version is three numbers with dots between, as 1.2.3: not 1.0" $ail add "$r/base" 1.0
is cli_add_no_such_tag 4 "" "ail: $r/base has no tag v9.9.9" $ail add "$r/base" 9.9.9
lastis cli_add_no_repository 4 "ail: cannot read the tags of $r/nothing" $ail add "$r/nothing"
$g init -q "$r/untagged" && $g -C "$r/untagged" commit -q --allow-empty -m one
is cli_add_no_tags 4 "" "ail: $r/untagged has no tag of the form v1.2.3" $ail add "$r/untagged"
# a tag whose manifest has another version, and one without a manifest
$g -C "$r/base" tag v2.0.0 "$base10" && $g -C "$r/untagged" tag v1.0.0
is cli_add_tag_other_version 3 "" "ail: the tag v2.0.0 of base has the version 1.0.0 in its ail.pkg" $ail add "$r/base" 2.0.0
$g -C "$r/base" tag -d v2.0.0 > /dev/null
is cli_add_no_manifest 4 "" "ail: deps/.new has no ail.pkg" $ail add "$r/untagged"
is cli_add_path_no_manifest 4 "" "ail: $r/untagged has no ail.pkg" $ail add --path "$r/untagged"
is cli_add_itself 3 "" "ail: a package does not use itself: app" $ail add --path .
yes cli_add_refused_changes_nothing cmp -s ail.pkg "$tmp/pkg" && yes cli_add_refused_leaves_no_clone [ ! -e deps/.new ] && yes cli_add_refused_no_lock [ ! -e ail.lock ]
# a manifest by hand that names what is not there
printf 'name app\nversion 0.1.0\nbin app src/main.aiw\ndep other ../mid\n' > ail.pkg
is cli_deps_other_name 3 "" "ail: the package in ../mid is called mid, not other" $ail build
printf 'name app\nversion 0.1.0\nbin app src/main.aiw\ndep gone ../gone\n' > ail.pkg
is cli_deps_no_directory 4 "" "ail: ../gone has no ail.pkg" $ail build
mkdir "$r/newer" && printf 'name newer\nversion 1.0.0\nail 999.0.0\n' > "$r/newer/ail.pkg"
printf 'name app\nversion 0.1.0\nbin app src/main.aiw\ndep newer ../newer\n' > ail.pkg
is cli_deps_newer_ail 3 "" "ail: the package newer asks for AIL 999.0.0, which AIL $version is not" $ail build
mkdir "$r/broken" && printf 'name broken\nversion one\n' > "$r/broken/ail.pkg"
printf 'name app\nversion 0.1.0\nbin app src/main.aiw\ndep broken ../broken\n' > ail.pkg
is cli_deps_broken_manifest 3 "" "ail: ../broken/ail.pkg:2: a version that is not three numbers with dots between, as 1.2.3" $ail build
printf 'name app\nversion 0.1.0\nbin app src/main.aiw\n' > ail.pkg
echo "base 1.0.0 short url" > ail.lock
is cli_lock_wrong 3 "" "ail: ail.lock:1: a revision that is not forty digits of base sixteen" $ail build
exit $fail

use "lib/io.aw"
call print "hello\n" as ok
call eprint "to stderr\n" as ok2
add ok ok2 as ok
sys exit ok

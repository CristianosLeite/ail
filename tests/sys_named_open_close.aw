# open, read and close a file of the repository by name; a string is two
# values in sys, so the path goes through a variable
buf b 16
set "tests/lib/nonewline.aw\0" as path
sys open path 0 0 as fd
jslt fd 0 bad
sys read fd b 16 as n
sys close fd as c
add n c as n
sys exit n
label bad
sys exit 99

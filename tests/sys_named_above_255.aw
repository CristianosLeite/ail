# a number above 255: openat is 257, and -100 stands for the current
# directory
set "tests/lib/nonewline.aw\0" as path
sys openat -100 path 0 0 as fd
jslt fd 0 bad
sys close fd as c
sys exit c
label bad
sys exit 9

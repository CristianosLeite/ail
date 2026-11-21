# the top-level statements of the file run where the use stands
sys 1 1 "before\n"
use "tests/lib/hello.aw"
sys 1 1 "after\n"
use "tests/lib/hello.aw"
sys 60 count

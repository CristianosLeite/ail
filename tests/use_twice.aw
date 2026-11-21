# a path is compiled once: the second use adds nothing and is no duplicate
use "tests/lib/twice.aw"
use "tests/lib/twice.aw"
call twice 4 as r
sys 60 r

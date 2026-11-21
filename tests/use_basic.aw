# another file is compiled in place: its function, constant and data are
# then names of this program
use "tests/lib/twice.aw"
call twice seven as r
sys 1 1 word 4
sys 60 r

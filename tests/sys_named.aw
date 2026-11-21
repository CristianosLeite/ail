# sys takes a name for the common syscall numbers
sys write 1 "named\n" as n
sys getpid as p
sys getpid as q
sub p q as p
add n p as n
sys exit n

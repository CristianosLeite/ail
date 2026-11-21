# A body compiled in place adds its calls and its uses of global names to
# tables that are sized for a source read once: 600000 calls of a
# function with 4 calls and 8 uses of a buffer would be 2.4 million
# entries of calls, which holds 2097154, and 4.8 million of refs, which
# holds 4194305. The compiler must stop compiling the body in place
# before a table is full, and call the function from there on. h stands
# behind its calls, so that they are calls.
printf 'buf b 8\nfn f\ncall h\ncall h\ncall h\ncall h\nx=b+b+b+b+b+b+b+b\nstoreb b 7\nend\nfn g\n'
yes 'call f' | head -n 600000
printf 'end\nfn h\nend\ncall g\nloadb b as r\nsys exit r\n'

# A body compiled in place adds its calls and its uses of global names to
# tables that are sized for a source read once, with room behind that
# for such bodies: 1048576 entries of calls and 2097152 of refs. 600000
# calls of a function with 4 calls and 8 uses of a buffer would be 2.4
# million of the one and 4.8 million of the other. The compiler must stop
# compiling the body in place when that room is taken, and call the
# function from there on, so that the 600000 lines still have their own.
# h stands behind its calls, so that they are calls. tests/bytes.sh
# computes the whole file of such a program.
printf 'buf b 8\nfn f\ncall h\ncall h\ncall h\ncall h\nx=b+b+b+b+b+b+b+b\nstoreb b 7\nend\nfn g\n'
yes 'call f' | head -n 600000
printf 'end\nfn h\nend\ncall g\nloadb b as r\nsys exit r\n'

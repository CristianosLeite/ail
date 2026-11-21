# The same as inline_fills_tables with a body between: g has the body of
# f in place, and 600000 calls of g would bring that body's four calls
# and eight uses of a buffer 600000 times. Where the tables would not
# hold a body of g, g is called; where they would hold it but not the
# body of f inside it, that one is a call, which the entry of g allowed
# for.
printf 'buf b 8\nfn f\ncall h\ncall h\ncall h\ncall h\nx=b+b+b+b+b+b+b+b\nstoreb b 7\nend\nfn g\ncall f\nend\nfn k\n'
yes 'call g' | head -n 600000
printf 'end\nfn h\nend\ncall k\nloadb b as r\nsys exit r\n'

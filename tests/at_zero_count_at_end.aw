# no bytes at the end of the object is not an access
buf b 16
at b 16 0 as p
sub p b as d
sys 60 d

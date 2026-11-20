# store the new value only if memory holds the expected one
buf c 8
store c 12
cas c 12 99 as yes
cas c 12 50 as no
load c as v
shl yes 7 as yes
add v yes as v
add v no as v
sys exit v

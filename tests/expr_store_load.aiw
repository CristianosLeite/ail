# loads and stores through computed addresses
buf a 80
i=0
label fill
store a+i*8 i*i+1
i+=1
jlt i 10 fill
load a+8*7 as x
load a+(i-1)*8 as y
sys exit x+y

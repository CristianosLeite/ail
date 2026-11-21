# a function with one variable saves one register and has no frame code:
# 24 bytes lie between the two data bytes
data a 1
fn f x
	ret x
end
data b 1
sub b a as n
sys 60 n

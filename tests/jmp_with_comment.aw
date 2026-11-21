jmp a# glued comment
sys 60 1
	label a   # indented, blanks before the comment
jz 0	b	# tabs
sys 60 2
  label b# glued
sys 1 1 "ok\n"

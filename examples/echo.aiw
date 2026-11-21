# copy up to 4096 bytes of stdin to stdout; exit status 1 if either fails
buf b 4096
sys 0 0 b 4096 as n     # n = bytes read, or a negative error
jgt n 4096 fail         # unsigned: a negative n is far above 4096
sys 1 1 b n as w        # w = bytes written, or a negative error
jne w n fail            # a short write counts as a failure
sys 60 0
label fail
sys 60 1

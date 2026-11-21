# CRLF ends a comment on its own line and after a statement
printf '# note\r\nsys 1 1 "a\\n" # note\r\nsys 60 3\r\n'

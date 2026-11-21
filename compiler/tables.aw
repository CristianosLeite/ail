# ailc -- the read-only tables of compiler/ailc.aw, which compiles this
# file in place with use. This file is their definition: a row is edited
# here, one row a line. tests/tables.sh checks its form and tests/insn.sh
# the instruction bytes, against bytes written by an assembler; a new or
# changed row needs its case in tests/insn.cases.
# the ELF header (type 3: loaded anywhere) and the two program headers
data hdr 127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0
data 3 0 62 0 1 0 0 0 176 0 0 0 0 0 0 0
data 64 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
data 0 0 0 0 64 0 56 0 2 0 64 0 0 0 0 0
data 1 0 0 0 5 0 0 0 0 0 0 0 0 0 0 0
data 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
data 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
data 0 16 0 0 0 0 0 0 1 0 0 0 6 0 0 0
data 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
data 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
data 0 0 0 0 0 0 0 0 0 16 0 0 0 0 0 0
# statements: name length, name, operand count, flags (two bytes), code
# length, code. Flags 255 mark a statement parsed on its own, numbered by
# its operand count.
data optab 3 "sys" 0 4 0 2 15 5
data 3 "set" 1 1 0 0
data 3 "add" 2 1 0 3 72 1 248
data 3 "sub" 2 1 0 3 72 41 248
data 3 "mul" 2 1 0 4 72 15 175 199
data 3 "div" 2 1 0 5 49 210 72 247 247
data 3 "mod" 2 1 0 8 49 210 72 247 247 72 137 208
data 3 "and" 2 1 0 3 72 33 248
data 2 "or" 2 1 0 3 72 9 248
data 3 "xor" 2 1 0 3 72 49 248
data 3 "shl" 2 1 0 6 72 137 249 72 211 224
data 3 "shr" 2 1 0 6 72 137 249 72 211 232
data 2 "eq" 2 1 0 9 72 57 248 15 148 192 15 182 192
data 2 "ne" 2 1 0 9 72 57 248 15 149 192 15 182 192
data 2 "lt" 2 1 0 9 72 57 248 15 146 192 15 182 192
data 2 "le" 2 1 0 9 72 57 248 15 150 192 15 182 192
data 2 "gt" 2 1 0 9 72 57 248 15 151 192 15 182 192
data 2 "ge" 2 1 0 9 72 57 248 15 147 192 15 182 192
data 4 "sdiv" 2 1 0 5 72 153 72 247 255
data 4 "smod" 2 1 0 8 72 153 72 247 255 72 137 208
data 3 "sar" 2 1 0 6 72 137 249 72 211 248
data 3 "slt" 2 1 0 9 72 57 248 15 156 192 15 182 192
data 3 "sle" 2 1 0 9 72 57 248 15 158 192 15 182 192
data 3 "sgt" 2 1 0 9 72 57 248 15 159 192 15 182 192
data 3 "sge" 2 1 0 9 72 57 248 15 157 192 15 182 192
data 4 "args" 0 1 16 3 72 137 224
data 3 "len" 1 65 0 0
data 4 "load" 1 129 0 3 72 139 0
data 5 "loadb" 1 129 0 3 15 182 0
data 5 "load2" 1 129 0 3 15 183 0
data 5 "load4" 1 129 0 2 139 0
data 5 "store" 2 130 0 3 72 137 56
data 6 "storeb" 2 130 0 3 64 136 56
data 6 "store2" 2 130 0 3 102 137 56
data 6 "store4" 2 130 0 2 137 56
data 4 "fadd" 2 1 0 19 102 72 15 110 192 102 72 15 110 207 242 15 88 193 102 72 15 126 192
data 4 "fsub" 2 1 0 19 102 72 15 110 192 102 72 15 110 207 242 15 92 193 102 72 15 126 192
data 4 "fmul" 2 1 0 19 102 72 15 110 192 102 72 15 110 207 242 15 89 193 102 72 15 126 192
data 4 "fdiv" 2 1 0 19 102 72 15 110 192 102 72 15 110 207 242 15 94 193 102 72 15 126 192
data 5 "fsqrt" 1 1 0 14 102 72 15 110 192 242 15 81 192 102 72 15 126 192
data 4 "itof" 1 1 0 10 242 72 15 42 192 102 72 15 126 192
data 4 "ftoi" 1 1 0 10 102 72 15 110 192 242 72 15 44 192
data 3 "flt" 2 1 0 20 102 72 15 110 192 102 72 15 110 207 102 15 46 200 15 151 192 15 182 192
data 3 "fle" 2 1 0 20 102 72 15 110 192 102 72 15 110 207 102 15 46 200 15 147 192 15 182 192
data 3 "feq" 2 1 0 25 102 72 15 110 192 102 72 15 110 207 102 15 46 193 15 155 193 15 148 192 32 200 15 182 192
data 4 "padd" 3 2 0 16 102 15 16 7 102 15 16 14 102 15 88 193 102 15 17 0
data 4 "psub" 3 2 0 16 102 15 16 7 102 15 16 14 102 15 92 193 102 15 17 0
data 4 "pmul" 3 2 0 16 102 15 16 7 102 15 16 14 102 15 89 193 102 15 17 0
data 4 "pdiv" 3 2 0 16 102 15 16 7 102 15 16 14 102 15 94 193 102 15 17 0
data 5 "pmadd" 3 2 0 24 102 15 16 7 102 15 16 14 102 15 89 193 102 15 16 8 102 15 88 200 102 15 17 8
data 4 "xadd" 2 129 0 8 240 72 15 193 56 72 137 248
data 3 "cas" 3 129 0 17 72 137 193 72 137 248 240 72 15 177 49 15 148 192 15 182 192
data 2 "at" 4 1 1 17 72 1 242 114 10 72 57 250 119 5 72 1 240 235 2 15 11
data 5 "alloc" 1 1 0 58 72 61 0 240 255 255 115 48 72 141 112 16 49 255 186 3 0 0 0 65 186 34 0 0 0 73 131 200 255 69 49 201 184 9 0 0 0 15 5 72 61 0 240 255 255 119 9 72 137 48 72 131 192 16 235 2 49 192
data 4 "free" 1 2 0 19 72 133 192 116 14 72 141 120 240 72 139 55 184 11 0 0 0 15 5
data 3 "jmp" 0 10 0 1 233
data 2 "jz" 1 10 0 5 72 133 192 15 132
data 3 "jnz" 1 10 0 5 72 133 192 15 133
data 3 "jeq" 2 10 0 5 72 57 248 15 132
data 3 "jne" 2 10 0 5 72 57 248 15 133
data 3 "jlt" 2 10 0 5 72 57 248 15 130
data 3 "jle" 2 10 0 5 72 57 248 15 134
data 3 "jgt" 2 10 0 5 72 57 248 15 135
data 3 "jge" 2 10 0 5 72 57 248 15 131
data 4 "jslt" 2 10 0 5 72 57 248 15 140
data 4 "jsle" 2 10 0 5 72 57 248 15 142
data 4 "jsgt" 2 10 0 5 72 57 248 15 143
data 4 "jsge" 2 10 0 5 72 57 248 15 141
data 2 "if" 1 2 8 5 72 133 192 15 132
data 3 "ifz" 1 2 8 5 72 133 192 15 133
data 4 "ifeq" 2 2 8 5 72 57 248 15 133
data 4 "ifne" 2 2 8 5 72 57 248 15 132
data 4 "iflt" 2 2 8 5 72 57 248 15 131
data 4 "ifle" 2 2 8 5 72 57 248 15 135
data 4 "ifgt" 2 2 8 5 72 57 248 15 134
data 4 "ifge" 2 2 8 5 72 57 248 15 130
data 5 "ifslt" 2 2 8 5 72 57 248 15 141
data 5 "ifsle" 2 2 8 5 72 57 248 15 143
data 5 "ifsgt" 2 2 8 5 72 57 248 15 142
data 5 "ifsge" 2 2 8 5 72 57 248 15 140
data 4 "call" 0 16 0 1 232
data 3 "ref" 0 17 2 3 72 141 5
data 5 "callp" 0 0 4 2 255 209
data 3 "ret" 1 34 0 11 65 95 65 94 65 93 65 92 93 91 195
data 4 "tail" 0 50 0 11 65 95 65 94 65 93 65 92 93 91 233
# spawn and join call the function of the program that has their name
data 5 "spawn" 0 17 34 3 72 141 5
data 4 "join" 0 16 32 1 232
data 5 "await" 0 16 96 0
data 2 "fn" 1 255 0 0
data 3 "buf" 2 255 0 0
data 3 "end" 3 255 0 0
data 5 "label" 4 255 0 0
data 4 "data" 5 255 0 0
data 3 "var" 6 255 0 0
data 5 "const" 7 255 0 0
data 5 "local" 8 255 0 0
data 3 "use" 9 255 0 0
data 4 "else" 10 255 0 0
data 5 "while" 11 255 0 0
data 5 "async" 12 255 0 0
data 0
# names that sys accepts for a syscall number, unless the program has a
# const of that name: name length, name, number as two bytes
data sysnames 4 "read" 0 0
data 5 "write" 1 0
data 4 "open" 2 0
data 5 "close" 3 0
data 4 "stat" 4 0
data 5 "fstat" 5 0
data 5 "lseek" 8 0
data 4 "mmap" 9 0
data 8 "mprotect" 10 0
data 6 "munmap" 11 0
data 3 "brk" 12 0
data 12 "rt_sigaction" 13 0
data 5 "ioctl" 16 0
data 4 "pipe" 22 0
data 9 "nanosleep" 35 0
data 6 "getpid" 39 0
data 6 "socket" 41 0
data 7 "connect" 42 0
data 6 "accept" 43 0
data 4 "bind" 49 0
data 6 "listen" 50 0
data 5 "clone" 56 0
data 4 "fork" 57 0
data 6 "execve" 59 0
data 4 "exit" 60 0
data 5 "wait4" 61 0
data 4 "kill" 62 0
data 6 "rename" 82 0
data 5 "mkdir" 83 0
data 5 "rmdir" 84 0
data 6 "unlink" 87 0
data 5 "chmod" 90 0
data 12 "gettimeofday" 96 0
data 6 "getuid" 102 0
data 5 "futex" 202 0
data 17 "sched_getaffinity" 204 0
data 13 "clock_gettime" 228 0
data 10 "exit_group" 231 0
data 6 "openat" 1 1
data 9 "getrandom" 62 1
data 0
# the code of ret: six pops and ret
data retc 65 95 65 94 65 93 65 92 93 91 195
# function entry: six pushes
# an async function: test rax, rax and jz over the stores of its
# parameters, in the code that makes its task; the entry of its poll
# function, push rbx, mov rbx, rax, mov rax, [rbx+8], test rax, rax,
# jz +2, jmp rax; and its return, mov [rbx+16], rax, mov eax, 1, pop rbx,
# ret
data asytst 72 133 192 116 0
data asypoll 83 72 137 195 72 139 67 8 72 133 192 116 2 255 224
data asyret 72 137 67 16 184 1 0 0 0 91 195
# await in an async function, with the handle in rax: mov [rbx+48], rax,
# lea rax, [rip+4], mov [rbx+8], rax, which is the place to go on at, the
# next instruction; there mov rax, [rbx+48], mov rdi, rbx, call. Behind
# the call test rdi, rdi, jnz +4, and for a task that is not done
# xor eax, eax, pop rbx, ret
data asyawt 72 137 67 48 72 141 5 4 0 0 0 72 137 67 8 72 139 67 48 72 137 223 232
data asysus 72 133 255 117 4 49 192 91 195
data fnpush 83 85 65 84 65 85 65 86 65 87
# xor eax,eax ; xor edi,edi ; xor esi,esi ; xor edx,edx ; xor r10d,r10d ;
# xor r8d,r8d -- and how many of those bytes clear the first n results
data zeroes 49 192 49 255 49 246 49 210 69 49 210 69 49 192
data zerolen 2 4 6 8 11 14
# bytes of fnpush that save the first n registers; 10 minus that many bytes
# of the pops restore all but those
data pushlen 0 1 2 4 6 8 10
# sub rsp, <frame> for a frame of a page or more, a page at a time with a
# touch of each; the frame is the four bytes at offset 2
data probe 65 187 255 255 255 127 72 129 236 0 16 0 0 72 133 36 36 73 129 235 0 16 0 0 73 129 251 0 16 0 0 115 229 76 41 220
# per argument: REX prefix or 0, mov opcode
data regtab 0 184 0 191 0 190 0 186 65 186 65 184 65 185 65 187 0 185
# per argument: x86 register number
data argnum 0 7 6 2 10 8 9 11 1
# per variable: x86 register number
data varnum 3 5 12 13 14 15
# mov eax,231 ; xor edi,edi ; syscall: exit_group, which ends every thread
data exit0 184 231 0 0 0 49 255 15 5
# the names of the comparisons, by operator number, three bytes each: the
# statements that compare and jump are named with them
data exkw "muldivmodaddsubshlshrandxoror_eq_ne_lt_le_gt_ge_"
# per operator of an expression, three bytes: the opcode "r/m64, r64", the
# opcode "r64, r/m64", and the digit of the instruction in the groups 81/83
# (arithmetic) or C1/D3 (shifts), or for a comparison the byte of its setcc
data xopc 0 175 0 0 0 0 0 0 0 1 3 0 41 43 5 0 0 4 0 0 5 33 35 4
data 49 51 6 9 11 1 57 59 148 57 59 149 57 59 146 57 59 150 57 59 151 57 59 147
# the order in which registers are taken for the values of an expression
data xord 0 7 6 8 9 10 11 3 5 12 13 14 15

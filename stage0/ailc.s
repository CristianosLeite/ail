# ailc stage0 -- AIL bootstrap compiler, x86-64 Linux, GNU as.
# usage: ailc < prog.ai > prog      (emits a static ELF64 directly, no linker)
#
# Single pass; jumps and calls are patched afterwards. Register roles:
#   rsi = input cursor   r15 = input end
#   rdi = output cursor  r14 = output base
#   ebx = syscall arg index of the statement being compiled
#   ebp = number of variables defined so far in the current scope
# curop points at the optab entry of the statement being compiled.

.intel_syntax noprefix

.equ BASE,   0x400000
.equ BSS,    0x10000000         # address of the writable segment (buffers)
.equ HDRSZ,  176                # ELF header (64) + two program headers (56 each)
.equ INSZ,   0x10000
.equ OUTSZ,  0x100000           # worst case expansion is ~3x input
.equ NVARS,  6                  # size of the variable register pool
.equ NBUFS,  16                 # size of the buffer table
.equ NLABELS, INSZ / 8 + 1      # "label a\n" is 8 bytes: the source cannot hold more
.equ NFIX,   INSZ / 6 + 1       # "jmp a\n" is 6 bytes
.equ NFUNCS, INSZ / 9 + 1       # "fn a\nend\n" is 9 bytes
.equ NCALLS, INSZ / 7 + 1       # "call a\n" is 7 bytes
.equ AS_REQ,  1                 # optab flags: "as name" is required,
.equ AS_NONE, 2                 # is not allowed,
.equ IS_SYS,  4                 # the statement is sys
.equ IS_JMP,  8                 # a label name follows the operands
.equ IS_CALL, 16                # a function name precedes the operands
.equ IS_RET,  32                # the statement is ret: only inside a function

.bss
inbuf:  .skip INSZ + 1          # one spare byte tells "exactly INSZ" from "too big"
inend:
outbuf: .skip OUTSZ
vars:   .skip 2 * NVARS * 16    # per variable: name address in inbuf, name length;
                                # top level first, then the open function
bufs:   .skip NBUFS * 16        # per buffer: the same
bufaddr: .skip NBUFS * 4        # per buffer: its address
nbufs:  .skip 4                 # number of buffers defined so far
bsssz:  .skip 8                 # bytes reserved in the writable segment
curop:  .skip 8                 # optab entry (at its nargs byte) of this statement
labels: .skip NLABELS * 16      # per label: name address in inbuf, name length
labaddr: .skip NLABELS * 8      # per label: its address in outbuf
nlabels: .skip 4                # number of labels defined so far
nfix:   .skip 4                 # number of jumps emitted so far
fixs:   .skip NFIX * 24         # per jump: label name address and length,
                                # address of its rel32 in outbuf
infn:   .skip 4                 # 1 between fn and end
topvars: .skip 4                # top-level variable count while in a function
fnskip: .skip 8                 # rel32 of the jump over the open function
labbase: .skip 4                # first label of the current scope
fixbase: .skip 4                # first jump of the current scope
callname: .skip 16              # function name of this call: address, length
funcs:  .skip NFUNCS * 16       # per function: name address in inbuf, name length
funaddr: .skip NFUNCS * 8       # per function: its entry address in outbuf
funargs: .skip NFUNCS           # per function: number of parameters
nfuncs: .skip 4                 # number of functions defined so far
calls:  .skip NCALLS * 32       # per call: function name address and length,
                                # address of its rel32 in outbuf, value count
ncalls: .skip 4                 # number of calls emitted so far

.section .rodata
ignore: .quad 1, 0, 0, 0        # struct sigaction: SIG_IGN, no flags, restorer or mask
hdr:
    .byte 0x7f,'E','L','F',2,1,1,0, 0,0,0,0,0,0,0,0
    .word 2                     # ET_EXEC
    .word 62                    # EM_X86_64
    .long 1
    .quad BASE + HDRSZ          # entry
    .quad 64                    # phoff
    .quad 0                     # shoff
    .long 0                     # flags
    .word 64, 56, 2, 64, 0, 0   # ehsize phentsize phnum shentsize shnum shstrndx
    .long 1                     # PT_LOAD
    .long 5                     # R+X
    .quad 0                     # file offset
    .quad BASE                  # vaddr
    .quad BASE                  # paddr
    .quad 0                     # filesz (patched)
    .quad 0                     # memsz  (patched)
    .quad 0x1000                # align
    .long 1                     # PT_LOAD: buffers, no bytes in the file
    .long 6                     # R+W
    .quad 0                     # file offset
    .quad BSS                   # vaddr
    .quad BSS                   # paddr
    .quad 0                     # filesz
    .quad 0                     # memsz  (patched)
    .quad 0x1000                # align

# statements: name length, name, operand count, flags, code length, code.
# Operands arrive in rax then rdi; the code leaves its result in rax.
optab:
    .byte 3
    .ascii "sys"
    .byte 0, IS_SYS, 2,  0x0F,0x05                  # syscall
    .byte 3
    .ascii "set"
    .byte 1, AS_REQ, 0
    .byte 3
    .ascii "add"
    .byte 2, AS_REQ, 3,  0x48,0x01,0xF8             # add rax, rdi
    .byte 3
    .ascii "sub"
    .byte 2, AS_REQ, 3,  0x48,0x29,0xF8             # sub rax, rdi
    .byte 3
    .ascii "mul"
    .byte 2, AS_REQ, 4,  0x48,0x0F,0xAF,0xC7        # imul rax, rdi
    .byte 3
    .ascii "div"
    .byte 2, AS_REQ, 5,  0x31,0xD2, 0x48,0xF7,0xF7  # xor edx, edx ; div rdi
    .byte 3
    .ascii "mod"                                    # ... ; mov rax, rdx
    .byte 2, AS_REQ, 8,  0x31,0xD2, 0x48,0xF7,0xF7, 0x48,0x89,0xD0
    .byte 3
    .ascii "and"
    .byte 2, AS_REQ, 3,  0x48,0x21,0xF8             # and rax, rdi
    .byte 2
    .ascii "or"
    .byte 2, AS_REQ, 3,  0x48,0x09,0xF8             # or rax, rdi
    .byte 3
    .ascii "xor"
    .byte 2, AS_REQ, 3,  0x48,0x31,0xF8             # xor rax, rdi
    .byte 3
    .ascii "shl"                                    # mov rcx, rdi ; shl rax, cl
    .byte 2, AS_REQ, 6,  0x48,0x89,0xF9, 0x48,0xD3,0xE0
    .byte 3
    .ascii "shr"                                    # mov rcx, rdi ; shr rax, cl
    .byte 2, AS_REQ, 6,  0x48,0x89,0xF9, 0x48,0xD3,0xE8
    # comparisons: cmp rax, rdi ; setcc al ; movzx eax, al (unsigned order)
    .byte 2
    .ascii "eq"                                     # sete
    .byte 2, AS_REQ, 9,  0x48,0x39,0xF8, 0x0F,0x94,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "ne"                                     # setne
    .byte 2, AS_REQ, 9,  0x48,0x39,0xF8, 0x0F,0x95,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "lt"                                     # setb
    .byte 2, AS_REQ, 9,  0x48,0x39,0xF8, 0x0F,0x92,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "le"                                     # setbe
    .byte 2, AS_REQ, 9,  0x48,0x39,0xF8, 0x0F,0x96,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "gt"                                     # seta
    .byte 2, AS_REQ, 9,  0x48,0x39,0xF8, 0x0F,0x97,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "ge"                                     # setae
    .byte 2, AS_REQ, 9,  0x48,0x39,0xF8, 0x0F,0x93,0xC0, 0x0F,0xB6,0xC0
    .byte 4
    .ascii "load"
    .byte 1, AS_REQ, 3,  0x48,0x8B,0x00             # mov rax, [rax]
    .byte 5
    .ascii "loadb"
    .byte 1, AS_REQ, 3,  0x0F,0xB6,0x00             # movzx eax, byte ptr [rax]
    .byte 5
    .ascii "store"
    .byte 2, AS_NONE, 3, 0x48,0x89,0x38             # mov [rax], rdi
    .byte 6
    .ascii "storeb"
    .byte 2, AS_NONE, 3, 0x40,0x88,0x38             # mov [rax], dil
    # jumps: the code ends where the rel32 of the label goes
    .byte 3
    .ascii "jmp"
    .byte 0, AS_NONE | IS_JMP, 1,  0xE9             # jmp rel32
    .byte 2
    .ascii "jz"                                     # test rax, rax ; jz rel32
    .byte 1, AS_NONE | IS_JMP, 5,  0x48,0x85,0xC0, 0x0F,0x84
    .byte 3
    .ascii "jnz"                                    # test rax, rax ; jnz rel32
    .byte 1, AS_NONE | IS_JMP, 5,  0x48,0x85,0xC0, 0x0F,0x85
    # functions: the code of call ends where the rel32 of the function goes
    .byte 4
    .ascii "call"
    .byte 0, IS_CALL, 1,  0xE8                      # call rel32
    .byte 3
    .ascii "ret"
    .byte 1, AS_NONE | IS_RET, 11
retcode:                        # pop r15 ; pop r14 ; pop r13 ; pop r12 ;
    .byte 0x41,0x5F, 0x41,0x5E, 0x41,0x5D, 0x41,0x5C, 0x5D, 0x5B, 0xC3
.equ RETSZ, . - retcode         # pop rbp ; pop rbx ; ret
    .byte 0

# function entry: push rbx ; push rbp ; push r12 ; push r13 ; push r14 ; push r15
fnpush:
    .byte 0x53, 0x55, 0x41,0x54, 0x41,0x55, 0x41,0x56, 0x41,0x57
.equ FNPUSHSZ, . - fnpush

# syscall arg index -> (REX prefix or 0, "mov r32, imm32" opcode)
regtab:
    .byte 0,    0xB8            # rax
    .byte 0,    0xBF            # rdi
    .byte 0,    0xBE            # rsi
    .byte 0,    0xBA            # rdx
    .byte 0x41, 0xBA            # r10
    .byte 0x41, 0xB8            # r8
    .byte 0x41, 0xB9            # r9

# syscall arg index -> x86 register number, parallel to regtab
argnum: .byte 0, 7, 6, 2, 10, 8, 9
# variable index -> x86 register number: rbx rbp r12 r13 r14 r15
varnum: .byte 3, 5, 12, 13, 14, 15

exit0:                          # mov eax,60 ; xor edi,edi ; syscall
    .byte 0xB8,60,0,0,0, 0x31,0xFF, 0x0F,0x05
.equ EXIT0SZ, . - exit0

m_syntax: .ascii "ailc: syntax error\n"
.equ M_SYNTAX_SZ, . - m_syntax
m_big:    .ascii "ailc: source too big\n"
.equ M_BIG_SZ, . - m_big
m_undef:  .ascii "ailc: undefined variable\n"
.equ M_UNDEF_SZ, . - m_undef
m_vars:   .ascii "ailc: too many variables\n"
.equ M_VARS_SZ, . - m_vars
m_dup:    .ascii "ailc: duplicate name\n"
.equ M_DUP_SZ, . - m_dup
m_bufs:   .ascii "ailc: too many buffers\n"
.equ M_BUFS_SZ, . - m_bufs
m_label:  .ascii "ailc: undefined label\n"
.equ M_LABEL_SZ, . - m_label
m_fn:     .ascii "ailc: undefined function\n"
.equ M_FN_SZ, . - m_fn
m_argc:   .ascii "ailc: wrong argument count\n"
.equ M_ARGC_SZ, . - m_argc
m_read:   .ascii "ailc: read error\n"
.equ M_READ_SZ, . - m_read
m_write:  .ascii "ailc: write error\n"
.equ M_WRITE_SZ, . - m_write

.text
.globl _start
_start:
    # ---- a closed output pipe must be a write error, not a silent death
    mov eax, 13                 # rt_sigaction(SIGPIPE, &ignore, 0, 8)
    mov edi, 13
    lea rsi, [rip+ignore]
    xor edx, edx
    mov r10d, 8
    syscall
    # ---- read all of stdin
    lea r15, [rip+inbuf]
1:  xor eax, eax
    xor edi, edi
    mov rsi, r15
    lea rdx, [rip+inend]
    sub rdx, r15
    jz err_big                  # buffer full: more than INSZ bytes
    syscall
    test rax, rax
    js err_read
    jz 2f
    add r15, rax
    jmp 1b
2:
    # ---- header template
    lea r14, [rip+outbuf]
    mov rdi, r14
    lea rsi, [rip+hdr]
    mov ecx, HDRSZ
    rep movsb
    lea rsi, [rip+inbuf]
    xor ebp, ebp

# ---- statement
next:
    cmp rsi, r15
    jae fin
    mov al, [rsi]
    cmp al, ' '                 # indentation and blank lines
    je 1f
    cmp al, 9
    je 1f
    cmp al, 10
    je 1f
    cmp al, '#'
    je 2f
    cmp al, 13
    jne 4f
    call crlf
    jmp 1f
4:  sub al, 'a'                 # a statement starts with its keyword
    cmp al, 'z' - 'a'
    ja err
    call name
    cmp r9, 2
    jne 5f
    cmp word ptr [r8], 0x6e66   # "fn"
    je fndef
5:  cmp r9, 3
    jne 5f
    cmp word ptr [r8], 0x7562   # "bu"
    jne 4f
    cmp byte ptr [r8+2], 'f'
    je bufdef
4:  cmp word ptr [r8], 0x6e65   # "en"
    jne 5f
    cmp byte ptr [r8+2], 'd'
    je fnend
5:  cmp r9, 5
    jne 5f
    cmp dword ptr [r8], 0x6562616c  # "labe"
    jne 5f
    cmp byte ptr [r8+4], 'l'
    je labdef
5:  lea rdx, [rip+optab]
6:  movzx ecx, byte ptr [rdx]   # length of this entry's name
    test ecx, ecx
    jz err                      # end of table: unknown keyword
    cmp rcx, r9
    jne 8f
    xor eax, eax
7:  mov r10b, [r8+rax]
    cmp r10b, [rdx+rax+1]
    jne 8f
    inc eax
    cmp eax, ecx
    jb 7b
    lea rdx, [rdx+rcx+1]
    mov [rip+curop], rdx
    jmp 9f
8:  movzx eax, byte ptr [rdx+rcx+3]
    lea rdx, [rdx+rcx+4]        # skip name, counts and code
    add rdx, rax
    jmp 6b
9:  xor ebx, ebx
    cmp rsi, r15                # keyword must be followed by a blank
    jae err
    mov al, [rsi]
    cmp al, ' '
    je 3f
    cmp al, 9
    jne err
3:  call blanks
    test byte ptr [rdx+1], IS_RET
    jz 4f
    cmp dword ptr [rip+infn], 0 # ret: only between fn and end
    je err
4:  test byte ptr [rdx+1], IS_CALL
    jz 4f
    cmp rsi, r15                # call: the function name comes first
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja err
    call name
    mov [rip+callname], r8
    mov [rip+callname+8], r9
    jmp tokend
4:  test byte ptr [rdx+1], IS_SYS
    jz arg
    cmp rsi, r15                # sys: the syscall number must be a literal
    jae err
    mov al, [rsi]
    sub al, '0'
    cmp al, 9
    ja err
    jmp num
1:  inc rsi
    jmp next
2:  inc rsi                     # comment: skip to end of line
    cmp rsi, r15
    jae fin
    cmp byte ptr [rsi], 10
    jne 2b
    jmp next

# a CR at rsi must be the first half of a CRLF line end
crlf:
    lea rax, [rsi+1]
    cmp rax, r15
    jae err
    cmp byte ptr [rax], 10
    jne err
    ret

# ---- arguments
# every token must be followed by a space, tab, comment or end of line
tokend:
    cmp rsi, r15
    jae arg
    mov al, [rsi]
    cmp al, ' '
    je arg
    cmp al, 9
    je arg
    cmp al, 10
    je arg
    cmp al, 13
    je arg
    cmp al, '#'
    jne err

arg:
    cmp rsi, r15
    jae 1f
    mov al, [rsi]
    cmp al, 10
    je 1f
    cmp al, '#'
    je 1f
    cmp al, ' '
    je 2f
    cmp al, 9
    je 2f
    cmp al, 13
    je 4f
    cmp al, '"'
    je str
    cmp al, 'a'
    jb 3f
    cmp al, 'z'
    jbe ident
3:  sub al, '0'
    cmp al, 9
    jbe num
    jmp err
4:  call crlf
1:  mov rdx, [rip+curop]        # end of statement without "as" or a label
    test byte ptr [rdx+1], AS_REQ | IS_JMP
    jnz err
    call emit_op
    jmp next
2:  inc rsi
    jmp arg

num:
    xor eax, eax
1:  cmp rsi, r15
    jae 2f
    movzx ecx, byte ptr [rsi]
    sub ecx, '0'
    cmp ecx, 9
    ja 2f
    imul eax, eax, 10
    add eax, ecx
    inc rsi
    jmp 1b
2:  call emit_mov
    jmp tokend

# string: bytes are inlined in the code stream behind a jmp, then passed
# as two args (address, length)
str:
    mov rdx, [rip+curop]        # only sys takes an address and length pair
    test byte ptr [rdx+1], IS_SYS
    jz err
    inc rsi
    mov byte ptr [rdi], 0xE9    # jmp rel32
    lea r12, [rdi+1]            # rel32 slot
    add rdi, 5
    mov r13, rdi                # string start
1:  cmp rsi, r15
    jae err
    lodsb
    cmp al, '"'
    je 4f
    cmp al, '\\'
    jne 3f
    cmp rsi, r15
    jae err
    lodsb
    cmp al, 'n'
    jne 2f
    mov al, 10
    jmp 3f
2:  cmp al, 't'
    jne 2f
    mov al, 9
    jmp 3f
2:  cmp al, '0'
    jne 3f                      # anything else is literal: \\ \"
    xor eax, eax
3:  stosb
    jmp 1b
4:  mov rax, rdi
    sub rax, r13                # length
    mov [r12], eax
    push rax
    mov rax, r13
    sub rax, r14
    add rax, BASE
    call emit_mov               # address
    pop rax
    call emit_mov               # length
    jmp tokend

# ---- variables
# a name as an argument: either a variable to pass, or "as" ending the
# statement, or the label of a jump once its operands are in
ident:
    call name
    mov rdx, [rip+curop]
    test byte ptr [rdx+1], IS_JMP
    jz 3f
    cmp bl, [rdx]
    jae jtarget
3:  cmp r9, 2
    jne 1f
    cmp word ptr [r8], 0x7361   # "as"
    je capture
1:  call lookup_var
    jc 2f
    cmp ebx, 7
    jae err
    lea rcx, [rip+varnum]
    movzx eax, byte ptr [rcx+rax]
    lea rcx, [rip+argnum]
    movzx ecx, byte ptr [rcx+rbx]
    call emit_mov_rr            # mov <arg reg>, <variable reg>
    inc ebx
    jmp tokend
2:  call lookup_buf             # not a variable: a buffer name is its address
    jc err_undef
    lea rcx, [rip+bufaddr]
    mov eax, [rcx+rax*4]
    call emit_mov
    jmp tokend

# "as <name>" then end of line: emit the statement's code and keep rax in
# the variable
capture:
    mov rdx, [rip+curop]
    test byte ptr [rdx+1], AS_NONE
    jnz err
    call blanks
    call defvar
    lea rcx, [rip+varnum]
    movzx r8d, byte ptr [rcx+rax]
    call eol
    call emit_op
    mov ecx, r8d
    xor eax, eax
    call emit_mov_rr            # mov <variable reg>, rax
    jmp next

# read a variable name at rsi and find it in the pool of the current scope,
# or add it: eax = its index
defvar:
    cmp rsi, r15
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja err
    call name
    cmp r9, 2
    jne 1f
    cmp word ptr [r8], 0x7361   # "as" is reserved
    je err
1:  call lookup_buf
    jnc err_dup
    call lookup_var
    jnc 2f
    cmp ebp, NVARS              # new name: take the next register of the pool
    jae err_vars
    mov [r10], r8
    mov [r10+8], r9
    mov eax, ebp
    inc ebp
2:  ret

# ---- buffers
# "buf <name> <size>": reserve zero-filled bytes in the writable segment
bufdef:
    call blank1
    cmp rsi, r15
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja err
    call name
    cmp r9, 2
    jne 1f
    cmp word ptr [r8], 0x7361   # "as" is reserved
    je err
1:  call lookup_var
    jnc err_dup
    call lookup_topvar          # a buffer is global: no top-level variable
    jnc err_dup                 # may have its name either
    call lookup_buf
    jnc err_dup
    cmp dword ptr [rip+nbufs], NBUFS
    jae err_bufs
    mov [r10], r8
    mov [r10+8], r9
    call blank1
    cmp rsi, r15
    jae err
    movzx eax, byte ptr [rsi]
    sub eax, '0'
    cmp eax, 9
    ja err
    xor eax, eax
    mov rdx, 0x100000000 - BSS  # room in the 32-bit address range
2:  cmp rsi, r15
    jae 3f
    movzx ecx, byte ptr [rsi]
    sub ecx, '0'
    cmp ecx, 9
    ja 3f
    imul rax, rax, 10
    add rax, rcx
    cmp rax, rdx
    ja err_bufs
    inc rsi
    jmp 2b
3:  test rax, rax
    jz err
    push rax
    call eol
    pop rax
    add rax, 7                  # keep every buffer 8-byte aligned
    and rax, -8
    mov rcx, [rip+bsssz]
    add rax, rcx                # new total
    cmp rax, rdx
    ja err_bufs
    mov [rip+bsssz], rax
    add rcx, BSS                # address of this buffer
    mov eax, [rip+nbufs]
    lea r10, [rip+bufaddr]
    mov [r10+rax*4], ecx
    inc dword ptr [rip+nbufs]
    jmp next

# ---- labels and jumps
# "label <name>": remember the output position under the name
labdef:
    call blank1
    cmp rsi, r15
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja err
    call name
    call eol
    call lookup_label
    jnc err_dup
    mov [r10], r8
    mov [r10+8], r9
    mov eax, [rip+nlabels]
    lea rcx, [rip+labaddr]
    mov [rcx+rax*8], rdi
    inc dword ptr [rip+nlabels]
    jmp next

# the label name r8/r9 ends a jump: emit the statement's code, leave room
# for the rel32 and record it for fin, since the label may come later
jtarget:
    call eol
    call emit_op
    mov eax, [rip+nfix]
    lea rax, [rax+rax*2]
    lea rcx, [rip+fixs]
    lea rcx, [rcx+rax*8]
    mov [rcx], r8
    mov [rcx+8], r9
    mov [rcx+16], rdi
    add rdi, 4
    inc dword ptr [rip+nfix]
    jmp next

# ---- functions
# "fn <name> <parameter>...": jump over the body, save the caller's variable
# registers and open a scope whose first variables are the parameters
fndef:
    cmp dword ptr [rip+infn], 0 # functions do not nest
    jne err
    call blank1
    cmp rsi, r15
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja err
    call name
    call lookup_fn
    jnc err_dup
    mov [r10], r8
    mov [r10+8], r9
    mov byte ptr [rdi], 0xE9    # jmp rel32, filled in by end
    inc rdi
    mov [rip+fnskip], rdi
    add rdi, 4
    mov eax, [rip+nfuncs]
    lea rcx, [rip+funaddr]
    mov [rcx+rax*8], rdi
    push rsi
    lea rsi, [rip+fnpush]
    mov ecx, FNPUSHSZ
    rep movsb
    pop rsi
    mov [rip+topvars], ebp
    xor ebp, ebp
    mov dword ptr [rip+infn], 1
    mov eax, [rip+nlabels]
    mov [rip+labbase], eax
    mov eax, [rip+nfix]
    mov [rip+fixbase], eax
1:  call blanks                 # parameters, up to the end of the line
    cmp rsi, r15
    jae 2f
    mov al, [rsi]
    cmp al, 10
    je 2f
    cmp al, 13
    je 2f
    cmp al, '#'
    je 2f
    push rbp
    call defvar
    pop rcx
    cmp ecx, ebp                # the pool did not grow: a repeated name
    je err_dup
    lea rcx, [rip+varnum]
    movzx ecx, byte ptr [rcx+rax]
    lea rdx, [rip+argnum]
    movzx eax, byte ptr [rdx+rax]
    call emit_mov_rr            # mov <variable reg>, <argument reg>
    jmp 1b
2:  call eol
    mov eax, [rip+nfuncs]
    lea rcx, [rip+funargs]
    mov [rcx+rax], bpl
    inc dword ptr [rip+nfuncs]
    jmp next

# "end": return zero, resolve the jumps of the function and drop its labels,
# variables and jumps
fnend:
    cmp dword ptr [rip+infn], 0
    je err
    call eol
    mov word ptr [rdi], 0xC031  # xor eax, eax
    add rdi, 2
    push rsi
    lea rsi, [rip+retcode]
    mov ecx, RETSZ
    rep movsb
    pop rsi
    call resolve
    mov eax, [rip+fixbase]
    mov [rip+nfix], eax
    mov eax, [rip+labbase]
    mov [rip+nlabels], eax
    xor eax, eax
    mov [rip+fixbase], eax
    mov [rip+labbase], eax
    mov [rip+infn], eax
    mov rcx, [rip+fnskip]       # top-level code continues here
    mov rax, rdi
    sub rax, rcx
    sub rax, 4
    mov [rcx], eax
    mov ebp, [rip+topvars]
    jmp next

# fill in the jumps of the current scope, now that all its labels are known
resolve:
    push rbx
    push rbp
    mov eax, [rip+fixbase]
    mov ebp, [rip+nfix]
    sub ebp, eax
    lea rax, [rax+rax*2]
    lea rbx, [rip+fixs]
    lea rbx, [rbx+rax*8]
1:  test ebp, ebp
    jz 2f
    mov r8, [rbx]
    mov r9, [rbx+8]
    call lookup_label
    jc err_label
    add eax, [rip+labbase]
    lea rcx, [rip+labaddr]
    mov rax, [rcx+rax*8]
    mov rcx, [rbx+16]
    sub rax, rcx
    sub rax, 4                  # relative to the end of the rel32
    mov [rcx], eax
    add rbx, 24
    dec ebp
    jmp 1b
2:  pop rbp
    pop rbx
    ret

# require one space or tab at rsi, then skip the rest of them
blank1:
    cmp rsi, r15
    jae err
    mov al, [rsi]
    cmp al, ' '
    je blanks
    cmp al, 9
    jne err

# skip spaces and tabs
blanks:
    cmp rsi, r15
    jae 1f
    mov al, [rsi]
    cmp al, ' '
    je 2f
    cmp al, 9
    jne 1f
2:  inc rsi
    jmp blanks
1:  ret

# after the last token of a statement: only blanks, then a comment or line end
eol:
    call blanks
    cmp rsi, r15
    jae 1f
    mov al, [rsi]
    cmp al, 10
    je 1f
    cmp al, '#'
    je 1f
    cmp al, 13
    jne err
    call crlf
1:  ret

# read a name [a-z0-9_]* at rsi: r8 = start, r9 = length
name:
    mov r8, rsi
1:  cmp rsi, r15
    jae 3f
    mov al, [rsi]
    cmp al, '_'
    je 2f
    cmp al, '0'
    jb 3f
    cmp al, '9'
    jbe 2f
    cmp al, 'a'
    jb 3f
    cmp al, 'z'
    ja 3f
2:  inc rsi
    jmp 1b
3:  mov r9, rsi
    sub r9, r8
    ret

# find the name r8/r9 among the variables or the labels of the current
# scope, the functions or the buffers: eax = its index (for a label, counted
# from labbase), or carry set if it is not defined, with r10 = the free
# table slot
lookup_var:
    lea r10, [rip+vars]
    cmp dword ptr [rip+infn], 0
    je 1f
    add r10, NVARS * 16         # the pool of the open function
1:  mov edx, ebp
    jmp lookup
lookup_topvar:                  # the top-level variables, from inside a function
    lea r10, [rip+vars]
    mov edx, [rip+topvars]
    cmp dword ptr [rip+infn], 0
    jne lookup
    mov edx, ebp
    jmp lookup
lookup_label:
    mov eax, [rip+labbase]
    mov edx, [rip+nlabels]
    sub edx, eax
    shl eax, 4
    lea r10, [rip+labels]
    add r10, rax
    jmp lookup
lookup_fn:
    lea r10, [rip+funcs]
    mov edx, [rip+nfuncs]
    jmp lookup
lookup_buf:
    lea r10, [rip+bufs]
    mov edx, [rip+nbufs]
lookup:
    xor eax, eax
1:  cmp eax, edx
    jae 4f
    cmp r9, [r10+8]
    jne 3f
    mov r11, [r10]
    xor ecx, ecx
2:  mov r12b, [r8+rcx]
    cmp r12b, [r11+rcx]
    jne 3f
    inc rcx
    cmp rcx, r9
    jb 2b
    clc
    ret
3:  add r10, 16
    inc eax
    jmp 1b
4:  stc
    ret

# emit the code of the current statement, after checking its operand count;
# a call also leaves room for its rel32 and records it for fin. Keeps r8.
emit_op:
    mov rdx, [rip+curop]
    test byte ptr [rdx+1], IS_SYS | IS_CALL
    jnz 1f                      # sys and call take any number of arguments
    cmp bl, [rdx]
    jne err
1:  movzx ecx, byte ptr [rdx+2]
    push rsi
    lea rsi, [rdx+3]
    rep movsb
    pop rsi
    test byte ptr [rdx+1], IS_CALL
    jz 2f
    cmp ebx, 6                  # a function has at most six parameters
    ja err
    mov eax, [rip+ncalls]
    shl eax, 5
    lea rcx, [rip+calls]
    add rcx, rax
    mov rax, [rip+callname]
    mov [rcx], rax
    mov rax, [rip+callname+8]
    mov [rcx+8], rax
    mov [rcx+16], rdi
    mov [rcx+24], ebx
    add rdi, 4
    inc dword ptr [rip+ncalls]
2:  ret

# emit the 64-bit "mov <reg ecx>, <reg eax>" (x86 register numbers)
emit_mov_rr:
    mov edx, eax
    shr edx, 3
    shl edx, 2                  # REX.R: source is r8-r15
    mov r9d, ecx
    shr r9d, 3                  # REX.B: destination is r8-r15
    or edx, r9d
    or edx, 0x48                # REX.W
    mov [rdi], dl
    mov byte ptr [rdi+1], 0x89  # mov r/m64, r64
    and eax, 7
    shl eax, 3
    and ecx, 7
    or eax, ecx
    or al, 0xC0
    mov [rdi+2], al
    add rdi, 3
    ret

# emit "mov <arg reg ebx>, eax" and advance ebx
emit_mov:
    cmp ebx, 7
    jae err
    lea rcx, [rip+regtab]
    movzx edx, byte ptr [rcx+rbx*2]
    test edx, edx
    jz 1f
    mov [rdi], dl
    inc rdi
1:  mov dl, [rcx+rbx*2+1]
    mov [rdi], dl
    mov [rdi+1], eax
    add rdi, 5
    inc ebx
    ret

# ---- implicit exit(0), patch jumps, calls and sizes, write ELF to stdout
fin:
    cmp dword ptr [rip+infn], 0 # a function without its end
    jne err
    lea rsi, [rip+exit0]
    mov ecx, EXIT0SZ
    rep movsb
    call resolve                # the top-level jumps
    lea rbx, [rip+calls]        # every function is known now: fill in the calls
    mov ebp, [rip+ncalls]
1:  test ebp, ebp
    jz 2f
    mov r8, [rbx]
    mov r9, [rbx+8]
    call lookup_fn
    jc err_fn
    lea rcx, [rip+funargs]
    movzx ecx, byte ptr [rcx+rax]
    cmp ecx, [rbx+24]
    jne err_argc
    lea rcx, [rip+funaddr]
    mov rax, [rcx+rax*8]
    mov rcx, [rbx+16]
    sub rax, rcx
    sub rax, 4                  # relative to the end of the rel32
    mov [rcx], eax
    add rbx, 32
    dec ebp
    jmp 1b
2:
    mov r13, rdi
    sub r13, r14                # file size
    mov [r14+64+32], r13
    mov [r14+64+40], r13
    mov rax, [rip+bsssz]
    mov [r14+64+56+40], rax     # memory size of the writable segment
    mov r12, r14
1:  mov eax, 1
    mov edi, 1
    mov rsi, r12
    mov rdx, r13
    syscall
    test rax, rax
    jle err_write
    add r12, rax
    sub r13, rax
    jnz 1b
    mov eax, 60
    xor edi, edi
    syscall

# ---- errors: source problems exit 1, I/O problems exit 2
err:
    lea rsi, [rip+m_syntax]
    mov edx, M_SYNTAX_SZ
    mov ebx, 1
    jmp die
err_big:
    lea rsi, [rip+m_big]
    mov edx, M_BIG_SZ
    mov ebx, 1
    jmp die
err_undef:
    lea rsi, [rip+m_undef]
    mov edx, M_UNDEF_SZ
    mov ebx, 1
    jmp die
err_vars:
    lea rsi, [rip+m_vars]
    mov edx, M_VARS_SZ
    mov ebx, 1
    jmp die
err_dup:
    lea rsi, [rip+m_dup]
    mov edx, M_DUP_SZ
    mov ebx, 1
    jmp die
err_bufs:
    lea rsi, [rip+m_bufs]
    mov edx, M_BUFS_SZ
    mov ebx, 1
    jmp die
err_label:
    lea rsi, [rip+m_label]
    mov edx, M_LABEL_SZ
    mov ebx, 1
    jmp die
err_fn:
    lea rsi, [rip+m_fn]
    mov edx, M_FN_SZ
    mov ebx, 1
    jmp die
err_argc:
    lea rsi, [rip+m_argc]
    mov edx, M_ARGC_SZ
    mov ebx, 1
    jmp die
err_read:
    lea rsi, [rip+m_read]
    mov edx, M_READ_SZ
    mov ebx, 2
    jmp die
err_write:
    lea rsi, [rip+m_write]
    mov edx, M_WRITE_SZ
    mov ebx, 2
die:
    mov eax, 1
    mov edi, 2
    syscall
    mov eax, 60
    mov edi, ebx
    syscall

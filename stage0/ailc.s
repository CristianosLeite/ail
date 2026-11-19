# ailc stage0 -- AIL bootstrap compiler, x86-64 Linux, GNU as.
# usage: ailc < prog.ai > prog      (emits a static ELF64 directly, no linker)
#
# Single pass. Register roles:
#   rsi = input cursor   r15 = input end
#   rdi = output cursor  r14 = output base
#   ebx = syscall arg index of the statement being compiled
#   ebp = number of variables defined so far

.intel_syntax noprefix

.equ BASE,   0x400000
.equ HDRSZ,  120                # ELF header (64) + one program header (56)
.equ INSZ,   0x10000
.equ OUTSZ,  0x100000           # worst case expansion is ~3x input
.equ NVARS,  6                  # size of the variable register pool

.bss
inbuf:  .skip INSZ + 1          # one spare byte tells "exactly INSZ" from "too big"
inend:
outbuf: .skip OUTSZ
vars:   .skip NVARS * 16        # per variable: name address in inbuf, name length

.section .rodata
hdr:
    .byte 0x7f,'E','L','F',2,1,1,0, 0,0,0,0,0,0,0,0
    .word 2                     # ET_EXEC
    .word 62                    # EM_X86_64
    .long 1
    .quad BASE + HDRSZ          # entry
    .quad 64                    # phoff
    .quad 0                     # shoff
    .long 0                     # flags
    .word 64, 56, 1, 64, 0, 0   # ehsize phentsize phnum shentsize shnum shstrndx
    .long 1                     # PT_LOAD
    .long 5                     # R+X
    .quad 0                     # file offset
    .quad BASE                  # vaddr
    .quad BASE                  # paddr
    .quad 0                     # filesz (patched)
    .quad 0                     # memsz  (patched)
    .quad 0x1000                # align

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
m_read:   .ascii "ailc: read error\n"
.equ M_READ_SZ, . - m_read
m_write:  .ascii "ailc: write error\n"
.equ M_WRITE_SZ, . - m_write

.text
.globl _start
_start:
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
4:  lea rax, [rsi+3]            # only statement so far: sys <number> ...
    cmp rax, r15
    ja err
    cmp word ptr [rsi], 0x7973  # "sy"
    jne err
    cmp byte ptr [rsi+2], 's'
    jne err
    add rsi, 3
    xor ebx, ebx
    cmp rsi, r15                # keyword must be followed by a blank...
    jae err
    mov al, [rsi]
    cmp al, ' '
    je 3f
    cmp al, 9
    jne err
3:  inc rsi                     # ...and then the syscall number
    cmp rsi, r15
    jae err
    mov al, [rsi]
    cmp al, ' '
    je 3b
    cmp al, 9
    je 3b
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
1:  mov word ptr [rdi], 0x050F  # syscall
    add rdi, 2
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
# a name as an argument: either a variable to pass, or "as" ending the statement
ident:
    call name
    cmp r9, 2
    jne 1f
    cmp word ptr [r8], 0x7361   # "as"
    je capture
1:  call lookup
    jc err_undef
    cmp ebx, 7
    jae err
    lea rcx, [rip+argnum]
    movzx ecx, byte ptr [rcx+rbx]
    call emit_mov_rr            # mov <arg reg>, <variable reg>
    inc ebx
    jmp tokend

# "as <name>" then end of line: emit the syscall and keep rax in the variable
capture:
    call blanks
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
1:  call lookup
    jnc 2f
    cmp ebp, NVARS              # new name: take the next register of the pool
    jae err_vars
    mov [r10], r8
    mov [r10+8], r9
    lea rcx, [rip+varnum]
    movzx eax, byte ptr [rcx+rbp]
    inc ebp
2:  mov r8d, eax
    call blanks
    cmp rsi, r15
    jae 3f
    mov al, [rsi]
    cmp al, 10
    je 3f
    cmp al, '#'
    je 3f
    cmp al, 13
    jne err
    call crlf
3:  mov word ptr [rdi], 0x050F  # syscall
    add rdi, 2
    mov ecx, r8d
    xor eax, eax
    call emit_mov_rr            # mov <variable reg>, rax
    jmp next

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

# find the name r8/r9: eax = its x86 register number, or carry set if it is
# not defined, with r10 = the free table slot
lookup:
    xor edx, edx
    lea r10, [rip+vars]
1:  cmp edx, ebp
    jae 4f
    cmp r9, [r10+8]
    jne 3f
    mov r11, [r10]
    xor ecx, ecx
2:  mov al, [r8+rcx]
    cmp al, [r11+rcx]
    jne 3f
    inc rcx
    cmp rcx, r9
    jb 2b
    lea rcx, [rip+varnum]
    movzx eax, byte ptr [rcx+rdx]
    clc
    ret
3:  add r10, 16
    inc edx
    jmp 1b
4:  stc
    ret

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

# ---- implicit exit(0), patch sizes, write ELF to stdout
fin:
    lea rsi, [rip+exit0]
    mov ecx, EXIT0SZ
    rep movsb
    mov r13, rdi
    sub r13, r14                # file size
    mov [r14+64+32], r13
    mov [r14+64+40], r13
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

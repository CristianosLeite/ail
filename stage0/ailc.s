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
.equ NVARS,  64                 # most variables in one scope
.equ NREGS,  6                  # size of the variable register pool
.equ NGLOB,  INSZ / 2 + 1       # "var a b c" declares a global name every 2 bytes
.equ NREFS,  INSZ / 2 + 1       # a name used as a value takes 2 bytes at least
.equ G_ADDR, 0                  # kinds of global name: a buffer or data, an address;
.equ G_VAR,  1                  # a var, a cell read and written through its address;
.equ G_CONST, 2                 # a const, a number
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
.equ IS_LEN,  64                # the operand is a buffer, data or string: its length
.equ IS_MEM,  128               # a load or a store: the first operand is an address
.equ IS_AT,   256               # at: the first operand is a name, passed as address
                                # and size; in the second flag byte, as 1
.equ IS_REF,  512               # ref: the address of the function, not a call of it
.equ IS_PTR,  1024              # callp: the first value is the function's address
.equ IS_IF,   2048              # opens a block: the code ends where the rel32 of
                                # the jump past the block goes
.equ IS_TOP,  4096              # args: only outside functions
.equ NBLK,   INSZ / 5 + 1       # "if a\n" is 5 bytes
.equ K_CONST, 1                 # what is known of a value: a number,
.equ K_ADDR,  2                 # a global name plus a number,
.equ K_LIT,   3                 # or the bytes of a string
.equ NCHKS,  INSZ / 8 + 1       # "load a as b\n" is longer than 8 bytes
.equ NRUNS,  INSZ / 9 + 1       # "data a 1\n" is 9 bytes
.equ NUSES,  INSZ / 7 + 1       # use "a" and its line end are 8 bytes
.equ PATHSZ, 4096               # longest path of a use, with its NUL

.bss
inbuf:  .skip INSZ + 1          # one spare byte tells "exactly INSZ" from "too big"
inend:
outbuf: .skip OUTSZ
vars:   .skip 2 * NVARS * 16    # per variable: name address in inbuf, name length;
                                # top level first, then the open function
topcell: .skip NVARS * 4        # per top-level variable after the sixth: its cell
vfirst: .skip NVARS * 8         # per variable of the function: where the source
vlast:  .skip NVARS * 8         # defines it, and mentions it last
fnloc:  .skip NVARS             # its place: a register 0-5, or 6 + a stack slot
locfree: .skip (NREGS + NVARS) * 8  # per place: the last mention of its variable
fnslots: .skip 4                # stack slots of the function
fnregs: .skip 4                 # how many of the six registers it uses
vlocal: .skip NVARS * 4         # per variable of the function that is a local:
                                # 1 + its offset among the locals
vlocsz: .skip NVARS * 4         # per local: its size as declared
loccur: .skip 4                 # bytes of locals declared so far in this pass
fnlocal: .skip 4                # bytes of locals of the function, after pass 1
pushed: .skip 4                 # bytes of call values pushed so far in this statement
fnnpar: .skip 4                 # parameters of the function, known after pass 1
immpos: .skip 8                 # where emit_mov wrote its last imm32
pass:   .skip 4                 # 1 while a function is compiled to measure its
                                # variables, 2 when it is compiled again for good
loops:  .skip NFIX * 16         # per backward jump of the function: where the
nloops: .skip 4                 # source has its label, and the jump
labpos: .skip NLABELS * 8       # per label: where the source defines it
snap:   .skip 12 * 8            # the state to return to after the first pass
opd:    .skip 3 * 32            # what is known of the first two values of the
                                # statement: kind, then a number, or a name
                                # (address, length) and a number; third: scratch
vk:     .skip NVARS * 32        # the same per variable of the current scope
chks:   .skip NCHKS * 32        # per load or store through a known name: name
                                # address and length, offset, width + 256 for a store
nchks:  .skip 4
bufrun: .skip NGLOB * 4         # per data name: 1 + its run of data statements
runend: .skip NRUNS * 4         # per run: the address after its last byte
nruns:  .skip 4
blks:   .skip NBLK * 24         # per open block: address of the rel32 that jumps
                                # past it, then asg and (4 bytes each) 1 for an
                                # else part and dead, as noted where it began
nblk:   .skip 4                 # open blocks
blkbase: .skip 4                # those of them opened outside the open function
topblk: .skip 4                 # blkbase of the top level, in a function
srcend: .skip 8                 # end of all source read so far, in inbuf
uses:   .skip NUSES * 16        # per file compiled through use: the path as
nuses:  .skip 4                 # written (address in inbuf, length)
ustack: .skip NUSES * 16        # per use being compiled: where its line ended
nustk:  .skip 4                 # in the unit that has it, and that unit's end
pathbuf: .skip PATHSZ           # the path of a use, with a NUL for open
bufs:   .skip NGLOB * 16        # per global name (buf, data, var, const): the same
bufaddr: .skip NGLOB * 4        # per global name: its address
bufsize: .skip NGLOB * 8        # its length in bytes, or the value of a const
bufkind: .skip NGLOB            # its kind: G_ADDR, G_VAR or G_CONST
nbufs:  .skip 4                 # number of global names defined so far
nvars:  .skip 4                 # number of those that are vars
dataend: .skip 8                # output cursor after the last data statement
datarel: .skip 8                # rel32 of the jump over that data
bsssz:  .skip 8                 # bytes reserved in the writable segment
curop:  .skip 8                 # optab entry (at its nargs byte) of this statement
labels: .skip NLABELS * 16      # per label: name address in inbuf, name length
labaddr: .skip NLABELS * 8      # per label: its address in outbuf
nlabels: .skip 4                # number of labels defined so far
nfix:   .skip 4                 # number of jumps emitted so far
fixs:   .skip NFIX * 32         # per jump: label name address and length,
                                # address of its rel32 in outbuf, and the
                                # variables assigned where the jump is
labmask: .skip NLABELS * 8      # per label: the variables assigned on every way to it
asg:    .skip 8                 # bit i: variable i of the scope is assigned on
                                # every way to this point; all ones where no way leads
dead:   .skip 4                 # 1 after jmp or ret, until the next label
jmask:  .skip 8                 # asg as it was when dead was set
topasg: .skip 24                # asg, dead and jmask of the top level, in a function
infn:   .skip 4                 # 1 between fn and end
topvars: .skip 4                # top-level variable count while in a function
fnskip: .skip 8                 # rel32 of the jump over the open function
labbase: .skip 4                # first label of the current scope
fixbase: .skip 4                # first jump of the current scope
callname: .skip 16              # function name of this call: address, length
funcs:  .skip NFUNCS * 16       # per function: name address in inbuf, name length
funaddr: .skip NFUNCS * 8       # per function: its entry address in outbuf
funargs: .skip NFUNCS           # per function: number of parameters
funres: .skip NFUNCS            # per function: number of results
fnres:  .skip 4                 # results of the open function, 0 until its first ret
fntail: .skip 4                 # 1 once the open function has a tail
caps:   .skip 6 * 16            # the names after "as": 0 and a variable, or 1 and
ncap:   .skip 4                 # the cell of a var; and how many
nfuncs: .skip 4                 # number of functions defined so far
calls:  .skip NCALLS * 32       # per call: function name address and length,
                                # address of its rel32 in outbuf, value count
ncalls: .skip 4                 # number of calls emitted so far
refs:   .skip NREFS * 32        # per use of a name not declared yet: name address
                                # and length, address of its imm32 in outbuf,
                                # 0 for the address of the name or 1 for its length
nrefs:  .skip 4                 # number of such uses so far

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

# statements: name length, name, operand count, flags (two bytes), code
# length, code.
# Operands arrive in rax then rdi; the code leaves its result in rax.
optab:
    .byte 3
    .ascii "sys"
    .byte 0
    .word IS_SYS
    .byte 2,  0x0F,0x05                  # syscall
    .byte 3
    .ascii "set"
    .byte 1
    .word AS_REQ
    .byte 0
    .byte 3
    .ascii "add"
    .byte 2
    .word AS_REQ
    .byte 3,  0x48,0x01,0xF8             # add rax, rdi
    .byte 3
    .ascii "sub"
    .byte 2
    .word AS_REQ
    .byte 3,  0x48,0x29,0xF8             # sub rax, rdi
    .byte 3
    .ascii "mul"
    .byte 2
    .word AS_REQ
    .byte 4,  0x48,0x0F,0xAF,0xC7        # imul rax, rdi
    .byte 3
    .ascii "div"
    .byte 2
    .word AS_REQ
    .byte 5,  0x31,0xD2, 0x48,0xF7,0xF7  # xor edx, edx ; div rdi
    .byte 3
    .ascii "mod"                                    # ... ; mov rax, rdx
    .byte 2
    .word AS_REQ
    .byte 8,  0x31,0xD2, 0x48,0xF7,0xF7, 0x48,0x89,0xD0
    .byte 3
    .ascii "and"
    .byte 2
    .word AS_REQ
    .byte 3,  0x48,0x21,0xF8             # and rax, rdi
    .byte 2
    .ascii "or"
    .byte 2
    .word AS_REQ
    .byte 3,  0x48,0x09,0xF8             # or rax, rdi
    .byte 3
    .ascii "xor"
    .byte 2
    .word AS_REQ
    .byte 3,  0x48,0x31,0xF8             # xor rax, rdi
    .byte 3
    .ascii "shl"                                    # mov rcx, rdi ; shl rax, cl
    .byte 2
    .word AS_REQ
    .byte 6,  0x48,0x89,0xF9, 0x48,0xD3,0xE0
    .byte 3
    .ascii "shr"                                    # mov rcx, rdi ; shr rax, cl
    .byte 2
    .word AS_REQ
    .byte 6,  0x48,0x89,0xF9, 0x48,0xD3,0xE8
    # comparisons: cmp rax, rdi ; setcc al ; movzx eax, al (unsigned order)
    .byte 2
    .ascii "eq"                                     # sete
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x94,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "ne"                                     # setne
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x95,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "lt"                                     # setb
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x92,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "le"                                     # setbe
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x96,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "gt"                                     # seta
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x97,0xC0, 0x0F,0xB6,0xC0
    .byte 2
    .ascii "ge"                                     # setae
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x93,0xC0, 0x0F,0xB6,0xC0
    # signed: cqo ; idiv rdi -- and cmp with the signed conditions
    .byte 4
    .ascii "sdiv"
    .byte 2
    .word AS_REQ
    .byte 5,  0x48,0x99, 0x48,0xF7,0xFF
    .byte 4
    .ascii "smod"                                   # ... ; mov rax, rdx
    .byte 2
    .word AS_REQ
    .byte 8,  0x48,0x99, 0x48,0xF7,0xFF, 0x48,0x89,0xD0
    .byte 3
    .ascii "sar"                                    # mov rcx, rdi ; sar rax, cl
    .byte 2
    .word AS_REQ
    .byte 6,  0x48,0x89,0xF9, 0x48,0xD3,0xF8
    .byte 3
    .ascii "slt"                                    # setl
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x9C,0xC0, 0x0F,0xB6,0xC0
    .byte 3
    .ascii "sle"                                    # setle
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x9E,0xC0, 0x0F,0xB6,0xC0
    .byte 3
    .ascii "sgt"                                    # setg
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x9F,0xC0, 0x0F,0xB6,0xC0
    .byte 3
    .ascii "sge"                                    # setge
    .byte 2
    .word AS_REQ
    .byte 9,  0x48,0x39,0xF8, 0x0F,0x9D,0xC0, 0x0F,0xB6,0xC0
    .byte 4
    .ascii "args"                                   # mov rax, rsp
    .byte 0
    .word AS_REQ | IS_TOP
    .byte 3,  0x48,0x89,0xE0
    .byte 3
    .ascii "len"                                    # mov eax, <length>
    .byte 1
    .word AS_REQ | IS_LEN
    .byte 0
    .byte 4
    .ascii "load"
    .byte 1
    .word AS_REQ | IS_MEM
    .byte 3,  0x48,0x8B,0x00             # mov rax, [rax]
    .byte 5
    .ascii "loadb"
    .byte 1
    .word AS_REQ | IS_MEM
    .byte 3,  0x0F,0xB6,0x00             # movzx eax, byte ptr [rax]
    .byte 5
    .ascii "load2"
    .byte 1
    .word AS_REQ | IS_MEM
    .byte 3,  0x0F,0xB7,0x00             # movzx eax, word ptr [rax]
    .byte 5
    .ascii "load4"
    .byte 1
    .word AS_REQ | IS_MEM
    .byte 2,  0x8B,0x00                  # mov eax, [rax]
    .byte 5
    .ascii "store"
    .byte 2
    .word AS_NONE | IS_MEM
    .byte 3, 0x48,0x89,0x38             # mov [rax], rdi
    .byte 6
    .ascii "storeb"
    .byte 2
    .word AS_NONE | IS_MEM
    .byte 3, 0x40,0x88,0x38             # mov [rax], dil
    .byte 6
    .ascii "store2"
    .byte 2
    .word AS_NONE | IS_MEM
    .byte 3, 0x66,0x89,0x38             # mov [rax], di
    .byte 6
    .ascii "store4"
    .byte 2
    .word AS_NONE | IS_MEM
    .byte 2, 0x89,0x38                  # mov [rax], edi
    # at: rax = address and rdi = size of the name, rsi = offset, rdx = count.
    # The address of the offset, or a trap if offset + count leaves the size
    .byte 2
    .ascii "at"
    .byte 4
    .word AS_REQ | IS_AT
    .byte at_end - at_code
at_code:
    add rdx, rsi
    jc 1f
    cmp rdx, rdi
    ja 1f
    add rax, rsi
    jmp 2f
1:  ud2
2:
at_end:
    # run-time storage: alloc maps the size plus a 16-byte header that keeps
    # the length for free, and gives 0 if the kernel refuses
    .byte 5
    .ascii "alloc"
    .byte 1
    .word AS_REQ
    .byte alloc_end - alloc_code
alloc_code:
    cmp rax, -4096              # a size that would wrap with the header
    jae 1f
    lea rsi, [rax+16]
    xor edi, edi
    mov edx, 3                  # PROT_READ | PROT_WRITE
    mov r10d, 0x22              # MAP_PRIVATE | MAP_ANONYMOUS
    or r8, -1
    xor r9d, r9d
    mov eax, 9                  # mmap
    syscall
    cmp rax, -4096
    ja 1f
    mov [rax], rsi
    add rax, 16
    jmp 2f
1:  xor eax, eax
2:
alloc_end:
    .byte 4
    .ascii "free"
    .byte 1
    .word AS_NONE
    .byte free_end - free_code
free_code:
    test rax, rax               # free 0 does nothing
    jz 1f
    lea rdi, [rax-16]
    mov rsi, [rdi]
    mov eax, 11                 # munmap
    syscall
1:
free_end:
    # jumps: the code ends where the rel32 of the label goes
    .byte 3
    .ascii "jmp"
    .byte 0
    .word AS_NONE | IS_JMP
    .byte 1,  0xE9             # jmp rel32
    .byte 2
    .ascii "jz"                                     # test rax, rax ; jz rel32
    .byte 1
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x85,0xC0, 0x0F,0x84
    .byte 3
    .ascii "jnz"                                    # test rax, rax ; jnz rel32
    .byte 1
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x85,0xC0, 0x0F,0x85
    # a comparison and a jump in one: jump to the label if it holds
    .byte 3
    .ascii "jeq"                                     # cmp rax, rdi ; je rel32
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x84
    .byte 3
    .ascii "jne"                                     # jne
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x85
    .byte 3
    .ascii "jlt"                                     # jb
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x82
    .byte 3
    .ascii "jle"                                     # jbe
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x86
    .byte 3
    .ascii "jgt"                                     # ja
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x87
    .byte 3
    .ascii "jge"                                     # jae
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x83
    .byte 4
    .ascii "jslt"                                    # jl
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x8C
    .byte 4
    .ascii "jsle"                                    # jle
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x8E
    .byte 4
    .ascii "jsgt"                                    # jg
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x8F
    .byte 4
    .ascii "jsge"                                    # jge
    .byte 2
    .word AS_NONE | IS_JMP
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x8D
    # blocks: the statements up to the matching end, or else, run if the
    # value is not zero (if), is zero (ifz), or the comparison holds; the
    # code is the opposite jump, past the block
    .byte 2
    .ascii "if"                                      # test rax, rax ; jz rel32
    .byte 1
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x85,0xC0, 0x0F,0x84
    .byte 3
    .ascii "ifz"                                     # jnz
    .byte 1
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x85,0xC0, 0x0F,0x85
    .byte 4
    .ascii "ifeq"                                    # cmp rax, rdi ; jne rel32
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x85
    .byte 4
    .ascii "ifne"                                    # je
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x84
    .byte 4
    .ascii "iflt"                                    # jae
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x83
    .byte 4
    .ascii "ifle"                                    # ja
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x87
    .byte 4
    .ascii "ifgt"                                    # jbe
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x86
    .byte 4
    .ascii "ifge"                                    # jb
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x82
    .byte 5
    .ascii "ifslt"                                   # jge
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x8D
    .byte 5
    .ascii "ifsle"                                   # jg
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x8F
    .byte 5
    .ascii "ifsgt"                                   # jle
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x8E
    .byte 5
    .ascii "ifsge"                                   # jl
    .byte 2
    .word AS_NONE | IS_IF
    .byte 5,  0x48,0x39,0xF8, 0x0F,0x8C
    # functions: the code of call ends where the rel32 of the function goes
    .byte 4
    .ascii "call"
    .byte 0
    .word IS_CALL
    .byte 1,  0xE8                      # call rel32
    .byte 3
    .ascii "ref"                                    # mov eax, <address of the function>
    .byte 0
    .word AS_REQ | IS_CALL | IS_REF
    .byte 1,  0xB8
    .byte 5
    .ascii "callp"                                  # call rcx
    .byte 0
    .word IS_PTR
    .byte 2,  0xFF,0xD1
    .byte 3
    .ascii "ret"
    .byte 1
    .word AS_NONE | IS_RET
    .byte 11
retcode:                        # pop r15 ; pop r14 ; pop r13 ; pop r12 ;
    .byte 0x41,0x5F, 0x41,0x5E, 0x41,0x5D, 0x41,0x5C, 0x5D, 0x5B, 0xC3
.equ RETSZ, . - retcode         # pop rbp ; pop rbx ; ret
    # tail: the same pops, then jmp rel32 to the function instead of ret
    .byte 4
    .ascii "tail"
    .byte 0
    .word AS_NONE | IS_CALL | IS_RET
    .byte 11,  0x41,0x5F, 0x41,0x5E, 0x41,0x5D, 0x41,0x5C, 0x5D, 0x5B, 0xE9
    .byte 0

# names that sys accepts for a syscall number, unless the program has a
# const of that name: name length, name, number as two bytes
sysnames:
    .byte 4
    .ascii "read"
    .word 0
    .byte 5
    .ascii "write"
    .word 1
    .byte 4
    .ascii "open"
    .word 2
    .byte 5
    .ascii "close"
    .word 3
    .byte 4
    .ascii "stat"
    .word 4
    .byte 5
    .ascii "fstat"
    .word 5
    .byte 5
    .ascii "lseek"
    .word 8
    .byte 4
    .ascii "mmap"
    .word 9
    .byte 8
    .ascii "mprotect"
    .word 10
    .byte 6
    .ascii "munmap"
    .word 11
    .byte 3
    .ascii "brk"
    .word 12
    .byte 12
    .ascii "rt_sigaction"
    .word 13
    .byte 5
    .ascii "ioctl"
    .word 16
    .byte 4
    .ascii "pipe"
    .word 22
    .byte 9
    .ascii "nanosleep"
    .word 35
    .byte 6
    .ascii "getpid"
    .word 39
    .byte 6
    .ascii "socket"
    .word 41
    .byte 7
    .ascii "connect"
    .word 42
    .byte 6
    .ascii "accept"
    .word 43
    .byte 4
    .ascii "bind"
    .word 49
    .byte 6
    .ascii "listen"
    .word 50
    .byte 4
    .ascii "fork"
    .word 57
    .byte 6
    .ascii "execve"
    .word 59
    .byte 4
    .ascii "exit"
    .word 60
    .byte 5
    .ascii "wait4"
    .word 61
    .byte 4
    .ascii "kill"
    .word 62
    .byte 6
    .ascii "rename"
    .word 82
    .byte 5
    .ascii "mkdir"
    .word 83
    .byte 5
    .ascii "rmdir"
    .word 84
    .byte 6
    .ascii "unlink"
    .word 87
    .byte 5
    .ascii "chmod"
    .word 90
    .byte 12
    .ascii "gettimeofday"
    .word 96
    .byte 6
    .ascii "getuid"
    .word 102
    .byte 13
    .ascii "clock_gettime"
    .word 228
    .byte 10
    .ascii "exit_group"
    .word 231
    .byte 6
    .ascii "openat"
    .word 257
    .byte 9
    .ascii "getrandom"
    .word 318
    .byte 0

# function entry: push rbx ; push rbp ; push r12 ; push r13 ; push r14 ; push r15
fnpush:
    .byte 0x53, 0x55, 0x41,0x54, 0x41,0x55, 0x41,0x56, 0x41,0x57
.equ FNPUSHSZ, . - fnpush
# xor eax,eax ; xor edi,edi ; xor esi,esi ; xor edx,edx ; xor r10d,r10d ;
# xor r8d,r8d -- and how many of those bytes clear the first n results
zeroes: .byte 0x31,0xC0, 0x31,0xFF, 0x31,0xF6, 0x31,0xD2, 0x45,0x31,0xD2, 0x45,0x31,0xC0
zerolen: .byte 2, 4, 6, 8, 11, 14
# bytes of fnpush that save the first n registers; 10 minus that many bytes
# of the pops restore all but those
pushlen: .byte 0, 1, 2, 4, 6, 8, 10

# sub rsp, <frame> for a frame of a page or more: go down a page at a time
# and touch each one, so that a stack that is too small is found by its
# guard page and not passed over
probe:
    mov r11d, 0x7fffffff        # the frame (patched)
1:  sub rsp, 4096
    test [rsp], rsp
    sub r11, 4096
    cmp r11, 4096
    jae 1b
    sub rsp, r11
.equ PROBESZ, . - probe

# syscall arg index -> (REX prefix or 0, "mov r32, imm32" opcode)
regtab:
    .byte 0,    0xB8            # rax
    .byte 0,    0xBF            # rdi
    .byte 0,    0xBE            # rsi
    .byte 0,    0xBA            # rdx
    .byte 0x41, 0xBA            # r10
    .byte 0x41, 0xB8            # r8
    .byte 0x41, 0xB9            # r9
    .byte 0x41, 0xBB            # r11: a call value that goes on the stack
    .byte 0,    0xB9            # rcx: the function address of callp

# syscall arg index -> x86 register number, parallel to regtab
argnum: .byte 0, 7, 6, 2, 10, 8, 9, 11, 1
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
m_bufs:   .ascii "ailc: buffers too big\n"
.equ M_BUFS_SZ, . - m_bufs
m_unasg:  .ascii "ailc: unassigned variable\n"
.equ M_UNASG_SZ, . - m_unasg
m_acc:    .ascii "ailc: invalid access\n"
.equ M_ACC_SZ, . - m_acc
m_use:    .ascii "ailc: cannot read file\n"
.equ M_USE_SZ, . - m_use
m_res:    .ascii "ailc: wrong result count\n"
.equ M_RES_SZ, . - m_res
m_num:    .ascii "ailc: number too big\n"
.equ M_NUM_SZ, . - m_num
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
2:  mov [rip+srcend], r15
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
    jae unitend
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
    jne 4f
    cmp byte ptr [r8+2], 'd'
    je fnend
4:  cmp word ptr [r8], 0x6176   # "va"
    jne 4f
    cmp byte ptr [r8+2], 'r'
    je vardef
4:  cmp word ptr [r8], 0x7375   # "us"
    jne 5f
    cmp byte ptr [r8+2], 'e'
    je usedef
5:  cmp r9, 4
    jne 5f
    cmp dword ptr [r8], 0x61746164  # "data"
    je datadef
    cmp dword ptr [r8], 0x65736c65  # "else"
    je elsedef
5:  cmp r9, 5
    jne 5f
    cmp dword ptr [r8], 0x6562616c  # "labe"
    jne 4f
    cmp byte ptr [r8+4], 'l'
    je labdef
4:  cmp dword ptr [r8], 0x61636f6c  # "loca"
    jne 4f
    cmp byte ptr [r8+4], 'l'
    je localdef
4:  cmp dword ptr [r8], 0x736e6f63  # "cons"
    jne 5f
    cmp byte ptr [r8+4], 't'
    je constdef
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
8:  movzx eax, byte ptr [rdx+rcx+4]
    lea rdx, [rdx+rcx+5]        # skip name, counts and code
    add rdx, rax
    jmp 6b
9:  xor ebx, ebx
    mov dword ptr [rip+ncap], 0
    mov qword ptr [rip+opd], 0  # nothing known of the values yet
    mov qword ptr [rip+opd+32], 0
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
4:  test byte ptr [rdx+2], IS_TOP >> 8
    jz 4f
    cmp dword ptr [rip+infn], 0 # args: only outside them
    jne err
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
    cmp rsi, r15                # sys: the syscall number is a const or a literal
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja num
    call sysname
    call emit_mov
    jmp tokend
1:  inc rsi
    jmp next
2:  inc rsi                     # comment: skip to end of line
    cmp rsi, r15
    jae unitend
    mov al, [rsi]
    cmp al, 10
    je next
    cmp al, 13
    jne 2b
    call crlf                   # even here a CR needs its LF
    jmp 2b

# the end of a unit of source: go on after the use that named it, or finish
unitend:
    mov eax, [rip+nustk]
    test eax, eax
    jz fin
    cmp dword ptr [rip+infn], 0 # a function ends in the unit it starts in
    jne err
    dec eax
    mov [rip+nustk], eax
    shl eax, 4
    lea rcx, [rip+ustack]
    mov rsi, [rcx+rax]
    mov r15, [rcx+rax+8]
    jmp next

# "use "<path>"": read the file behind the source read so far and compile it
# here, unless a use with the same path was compiled before
usedef:
    cmp dword ptr [rip+infn], 0
    jne err
    call blank1
    cmp rsi, r15
    jae err
    cmp byte ptr [rsi], '"'
    jne err
    inc rsi
    mov r8, rsi
1:  cmp rsi, r15
    jae err
    mov al, [rsi]
    cmp al, '"'
    je 2f
    cmp al, 10                  # a path is on one line
    je err
    inc rsi
    jmp 1b
2:  mov r9, rsi
    sub r9, r8
    inc rsi
    call eol
    test r9, r9
    jz err
    cmp r9, PATHSZ - 1
    ja err
    lea r10, [rip+uses]
    mov edx, [rip+nuses]
    call lookup
    jnc next                    # compiled before: nothing to do
    mov [r10], r8
    mov [r10+8], r9
    inc dword ptr [rip+nuses]
    push rsi
    push rdi
    mov rsi, r8
    lea rdi, [rip+pathbuf]
    mov rcx, r9
    rep movsb
    mov byte ptr [rdi], 0
    mov eax, 2                  # open(path, O_RDONLY)
    lea rdi, [rip+pathbuf]
    xor esi, esi
    xor edx, edx
    syscall
    test rax, rax
    js err_use
    mov r12, rax
    mov r13, [rip+srcend]       # the unit starts here
3:  xor eax, eax                # read(fd, srcend, room left)
    mov rdi, r12
    mov rsi, [rip+srcend]
    lea rdx, [rip+inend]
    sub rdx, rsi
    jz err_big
    syscall
    test rax, rax
    js err_use
    jz 4f
    add [rip+srcend], rax
    jmp 3b
4:  mov eax, 3                  # close(fd)
    mov rdi, r12
    syscall
    pop rdi
    pop rsi
    mov eax, [rip+nustk]        # come back here at the end of the unit
    shl eax, 4
    lea rcx, [rip+ustack]
    mov [rcx+rax], rsi
    mov [rcx+rax+8], r15
    inc dword ptr [rip+nustk]
    mov rsi, r13
    mov r15, [rip+srcend]
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
    call tokchk

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
3:  cmp al, '-'
    je num
    sub al, '0'
    cmp al, 9
    jbe num
    jmp err
4:  call crlf
1:  mov rdx, [rip+curop]        # end of statement without "as" or a label
    test byte ptr [rdx+1], AS_REQ | IS_JMP
    jnz err
    call emit_op
    mov rdx, [rip+curop]
    test byte ptr [rdx+2], IS_IF >> 8
    jz next
    mov eax, [rip+nblk]         # a block opens: its jump is filled in at the
    lea rax, [rax+rax*2]        # matching else or end
    lea rcx, [rip+blks]
    lea rcx, [rcx+rax*8]
    mov [rcx], rdi
    mov rax, [rip+asg]          # what is assigned on the way past the block
    mov [rcx+8], rax
    mov qword ptr [rcx+16], 0
    add rdi, 4
    inc dword ptr [rip+nblk]
    jmp next
2:  inc rsi
    jmp arg

num:
    call atfirst
    call rdnum
    mov rdx, [rip+curop]        # len takes a name or a string
    test byte ptr [rdx+1], IS_LEN
    jnz err
    call opdptr
    mov qword ptr [rdx], K_CONST
    mov [rdx+8], rax
    call emit_mov
    jmp tokend

# the first value of at must be a name
atfirst:
    mov rdx, [rip+curop]
    test byte ptr [rdx+2], IS_AT >> 8
    jz 1f
    test ebx, ebx
    jz err
1:  ret

# rdx = where to note what is known of the next value. Keeps all but rcx.
opdptr:
    mov edx, ebx
    cmp edx, 2
    jb 1f
    mov edx, 2
1:  shl edx, 5
    lea rcx, [rip+opd]
    add rdx, rcx
    ret

# string: bytes are inlined in the code stream behind a jmp. sys and call
# get two values (address, length), len the length, the rest the address
str:
    call atfirst
    inc rsi
    mov byte ptr [rdi], 0xE9    # jmp rel32
    lea r12, [rdi+1]            # rel32 slot
    add rdi, 5
    mov r13, rdi                # string start
    call strbytes
    mov rax, rdi
    sub rax, r13                # length
    mov [r12], eax
    call opdptr
    mov qword ptr [rdx], K_LIT
    mov [rdx+8], rax
    mov rdx, [rip+curop]
    test byte ptr [rdx+1], IS_LEN
    jnz 1f
    push rax
    mov rax, r13
    sub rax, r14
    add rax, BASE
    call emit_mov               # address
    pop rax
    mov rdx, [rip+curop]
    test byte ptr [rdx+1], IS_SYS | IS_CALL
    jnz 1f
    test byte ptr [rdx+2], IS_PTR >> 8
    jz tokend
1:  call emit_mov               # length
    jmp tokend

# copy the bytes of a string, whose opening quote is behind rsi, to rdi
strbytes:
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
    jne 2f
    xor eax, eax
    jmp 3f
2:  cmp al, 'x'
    jne 3f                      # anything else is literal: \\ \"
    call hexdig                 # \xHH: the byte with that value
    shl eax, 4
    push rax
    call hexdig
    pop rcx
    or eax, ecx
3:  stosb
    jmp 1b
4:  ret

# eax = the value of the hexadecimal digit at rsi, which is consumed
hexdig:
    cmp rsi, r15
    jae err
    movzx eax, byte ptr [rsi]
    inc rsi
    mov edx, eax
    sub edx, '0'
    cmp edx, 9
    jbe 1f
    or eax, 0x20                # A-F as a-f
    sub eax, 'a'
    cmp eax, 5
    ja err
    lea edx, [rax+10]
1:  mov eax, edx
    ret

# rax = the number at rsi: decimal, or hexadecimal after "0x", either one
# after an optional "-". It must fit 64 bits, a negative one as two's complement
rdnum:
    xor r10d, r10d              # 1 for a negative number
    cmp rsi, r15
    jae err
    cmp byte ptr [rsi], '-'
    jne 1f
    inc rsi
    mov r10d, 1
1:  cmp rsi, r15
    jae err
    movzx ecx, byte ptr [rsi]
    sub ecx, '0'
    cmp ecx, 9
    ja err
    xor eax, eax
    test ecx, ecx
    jnz 5f
    lea rdx, [rsi+1]
    cmp rdx, r15
    jae 5f
    cmp byte ptr [rdx], 'x'
    jne 5f
    add rsi, 2
    xor r11d, r11d              # number of hexadecimal digits
2:  cmp rsi, r15
    jae 4f
    movzx ecx, byte ptr [rsi]
    mov edx, ecx
    sub edx, '0'
    cmp edx, 9
    jbe 3f
    or ecx, 0x20                # A-F as a-f
    sub ecx, 'a'
    cmp ecx, 5
    ja 4f
    lea edx, [rcx+10]
3:  inc r11d
    cmp r11d, 16
    ja err_num
    shl rax, 4
    or rax, rdx
    inc rsi
    jmp 2b
4:  test r11d, r11d             # "0x" needs a digit
    jz err
    jmp 8f
5:  cmp rsi, r15
    jae 8f
    movzx ecx, byte ptr [rsi]
    sub ecx, '0'
    cmp ecx, 9
    ja 8f
    mov edx, 10
    mul rdx
    jc err_num
    add rax, rcx
    jc err_num
    inc rsi
    jmp 5b
8:  test r10d, r10d
    jz 9f
    mov rdx, 0x8000000000000000
    cmp rax, rdx
    ja err_num
    neg rax
9:  ret

# rax = the syscall number named at rsi: a const of the program, or else
# one of the names in sysnames
sysname:
    call rdname
    call lookup_buf
    jc 1f
    lea rcx, [rip+bufkind]
    cmp byte ptr [rcx+rax], G_CONST
    jne err
    lea rcx, [rip+bufsize]
    mov rax, [rcx+rax*8]
    ret
1:  lea rdx, [rip+sysnames]
2:  movzx ecx, byte ptr [rdx]
    test ecx, ecx
    jz err                      # no such name
    cmp rcx, r9
    jne 4f
    xor eax, eax
3:  mov r10b, [r8+rax]
    cmp r10b, [rdx+rax+1]
    jne 4f
    inc eax
    cmp eax, ecx
    jb 3b
    movzx eax, word ptr [rdx+rcx+1]
    ret
4:  lea rdx, [rdx+rcx+3]
    jmp 2b

# rax = the value of the const whose name is at rsi
constname:
    call rdname
    call lookup_buf
    jc err
    lea rcx, [rip+bufkind]
    cmp byte ptr [rcx+rax], G_CONST
    jne err
    lea rcx, [rip+bufsize]
    mov rax, [rcx+rax*8]
    ret

# read a name at rsi that starts with a letter and is not "as": r8, r9
rdname:
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
1:  ret

# a token must be followed by a space, tab, comment or end of line
tokchk:
    cmp rsi, r15
    jae 1f
    mov al, [rsi]
    cmp al, ' '
    je 1f
    cmp al, 9
    je 1f
    cmp al, 10
    je 1f
    cmp al, 13
    je 1f
    cmp al, '#'
    jne err
1:  ret

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
1:  mov rdx, [rip+curop]
    test byte ptr [rdx+2], IS_AT >> 8
    jz 10f
    test ebx, ebx
    jz atname
10: test byte ptr [rdx+1], IS_LEN
    jz 4f
    call lookup_buf             # len: the length of a buffer or data name
    jc 9f
    lea rcx, [rip+bufkind]
    cmp byte ptr [rcx+rax], G_ADDR
    jne err
    lea rcx, [rip+bufsize]
    mov rax, [rcx+rax*8]
    call emit_mov
    jmp tokend
4:  call lookup_var
    jc 2f
    lea rcx, [rip+vlast]
    mov [rcx+rax*8], rsi
    bt [rip+asg], rax           # a way here that skipped its as?
    jnc err_unasg
    call opdptr                 # what is known of the variable is known of the value
    mov ecx, eax
    shl ecx, 5
    lea r10, [rip+vk]
    add r10, rcx
    mov rcx, [r10]
    mov [rdx], rcx
    mov rcx, [r10+8]
    mov [rdx+8], rcx
    mov rcx, [r10+16]
    mov [rdx+16], rcx
    mov rcx, [r10+24]
    mov [rdx+24], rcx
    call argidx
    lea rdx, [rip+argnum]
    movzx ecx, byte ptr [rdx+rcx]
    mov r9d, 0x8B
    call emit_varmov            # mov <arg reg>, <variable>
    call argnext
    jmp tokend
2:  call lookup_buf             # not a variable: a global name
    jc 7f
    lea rcx, [rip+bufkind]
    movzx ecx, byte ptr [rcx+rax]
    cmp ecx, G_VAR
    je 6f
    cmp ecx, G_CONST
    jne 5f
    lea rcx, [rip+bufsize]      # a const is its value
    mov rax, [rcx+rax*8]
    call opdptr
    mov qword ptr [rdx], K_CONST
    mov [rdx+8], rax
    call emit_mov
    jmp tokend
5:  lea rcx, [rip+bufaddr]      # a buffer or data name is its address
    mov eax, [rcx+rax*4]
    call opdaddr
    call emit_mov
    jmp tokend
6:  lea rcx, [rip+bufaddr]      # a var is read from its cell
    mov r8d, [rcx+rax*4]
    call argidx
    lea rdx, [rip+argnum]
    movzx eax, byte ptr [rdx+rcx]
    mov ecx, r8d
    mov edx, 1
    mov r9d, 0x8B
    call emit_mem               # mov <arg reg>, [cell]
    call argnext
    jmp tokend
7:  call opdaddr
    xor eax, eax                # not declared yet: a buffer or data name that
    call emit_mov               # comes later; fin fills in the value
    xor eax, eax
8:  call addref
    jmp tokend
9:  xor eax, eax                # the same for len
    call emit_mov
    mov eax, 1
    jmp 8b

# the name r8/r9 is the first value of at: pass its address and its size. A
# local has both now; for a buffer or data name fin fills in the size, since
# data reaches to the end of its run, and the address too if it comes later
atname:
    call lookup_var
    jc 2f
    lea rcx, [rip+vlocal]
    cmp dword ptr [rcx+rax*4], 0
    je err                      # a variable holds a value, not an object
    lea rcx, [rip+vlast]
    mov [rcx+rax*8], rsi
    push rax
    xor ecx, ecx
    mov r9d, 0x8B
    call emit_varmov            # lea rax, <local>
    inc ebx
    pop rax
    lea rcx, [rip+vlocsz]
    mov eax, [rcx+rax*4]
    call emit_mov
    jmp tokend
2:  call lookup_buf
    jc 3f
    lea rcx, [rip+bufkind]
    cmp byte ptr [rcx+rax], G_ADDR
    jne err
    lea rcx, [rip+bufaddr]
    mov eax, [rcx+rax*4]
    call emit_mov
    jmp 4f
3:  xor eax, eax
    call emit_mov
    xor eax, eax
    call addref
4:  xor eax, eax
    call emit_mov
    mov eax, 2
    call addref
    jmp tokend

# record that the imm32 just written stands for the name r8/r9: eax = 0 its
# address, 1 its length, 2 the bytes from it to the end of its object
addref:
    mov ecx, [rip+nrefs]
    shl ecx, 5
    lea rdx, [rip+refs]
    add rdx, rcx
    mov [rdx], r8
    mov [rdx+8], r9
    mov rcx, [rip+immpos]
    mov [rdx+16], rcx
    mov [rdx+24], eax
    inc dword ptr [rip+nrefs]
    ret

# "as <name>" then end of line: emit the statement's code and keep rax in
# the variable
capture:
    mov rdx, [rip+curop]
    test byte ptr [rdx+1], AS_NONE
    jnz err
1:  call blanks
    push rsi
    call rdname
    call lookup_buf
    jc 2f
    lea rcx, [rip+bufkind]
    cmp byte ptr [rcx+rax], G_VAR
    jne 2f
    pop rcx                     # a var: the result goes to its cell
    lea rcx, [rip+bufaddr]
    mov ecx, [rcx+rax*4]
    mov edx, 1
    jmp 3f
2:  pop rsi
    call defvar
    lea rcx, [rip+vlocal]       # a local is an address, not a variable to assign
    cmp dword ptr [rcx+rax*4], 0
    jne err_dup
    mov ecx, eax
    xor edx, edx
3:  mov eax, [rip+ncap]
    cmp eax, 6
    jae err
    shl eax, 4
    lea r10, [rip+caps]
    mov [r10+rax], rdx
    mov [r10+rax+8], rcx
    inc dword ptr [rip+ncap]
    call blanks                 # another name: a call may have several results
    cmp rsi, r15
    jae 4f
    mov al, [rsi]
    cmp al, 10
    je 4f
    cmp al, 13
    je 4f
    cmp al, '#'
    je 4f
    mov rdx, [rip+curop]
    test byte ptr [rdx+1], IS_CALL
    jnz 1b
    test byte ptr [rdx+2], IS_PTR >> 8
    jnz 1b
    jmp err
4:  call eol
    call emit_op
    xor r12d, r12d              # result k comes in the register of value k
5:  cmp r12d, [rip+ncap]
    jae next
    mov eax, r12d
    shl eax, 4
    lea r10, [rip+caps]
    mov rdx, [r10+rax]
    mov rcx, [r10+rax+8]
    lea r11, [rip+argnum]
    movzx r13d, byte ptr [r11+r12]
    test edx, edx
    jnz 6f
    mov eax, ecx
    bts [rip+asg], rax          # assigned from here on
    call propagate
    mov ecx, r13d
    mov r9d, 0x89
    call emit_varmov            # mov <variable>, <result register>
    jmp 7f
6:  mov eax, r13d
    mov edx, 1
    mov r9d, 0x89
    call emit_mem               # mov [cell], <result register>
7:  inc r12d
    jmp 5b

# note that the next value is the address of the global name r8/r9. Keeps rax.
opdaddr:
    call opdptr
    mov qword ptr [rdx], K_ADDR
    mov [rdx+8], r8
    mov [rdx+16], r9
    mov qword ptr [rdx+24], 0
    ret

# the statement assigns variable eax: note what is known of the new value.
# Only set, add and sub carry knowledge: a number, or a global name plus a
# number. Keeps rax.
propagate:
    push rax
    shl eax, 5
    lea r10, [rip+vk]
    add r10, rax
    mov qword ptr [r10], 0
    mov rdx, [rip+curop]
    lea rcx, [rip+opd]
    cmp word ptr [rdx+1], AS_REQ
    jne 9f
    cmp byte ptr [rdx+3], 0
    jne 1f
    cmp qword ptr [rcx], K_LIT  # set: the value itself
    je 9f
    xor r11d, r11d
    jmp 3f
1:  cmp byte ptr [rdx+3], 3
    jne 9f
    mov eax, [rdx+4]
    and eax, 0xFFFFFF
    cmp eax, 0xF80148           # add rax, rdi
    je 2f
    cmp eax, 0xF82948           # sub rax, rdi
    jne 9f
    cmp qword ptr [rcx+32], K_CONST
    jne 9f
    mov r11, [rcx+40]
    neg r11
    jmp 3f
2:  cmp qword ptr [rcx+32], K_CONST
    jne 4f
    mov r11, [rcx+40]
3:  mov rax, [rcx]              # the first value plus the number r11
    cmp rax, K_CONST
    je 5f
    cmp rax, K_ADDR
    jne 9f
    mov [r10], rax
    mov rax, [rcx+8]
    mov [r10+8], rax
    mov rax, [rcx+16]
    mov [r10+16], rax
    mov rax, [rcx+24]
    add rax, r11
    mov [r10+24], rax
    jmp 9f
5:  mov [r10], rax
    mov rax, [rcx+8]
    add rax, r11
    mov [r10+8], rax
    jmp 9f
4:  cmp qword ptr [rcx], K_CONST    # add number, name
    jne 9f
    cmp qword ptr [rcx+32], K_ADDR
    jne 9f
    mov r11, [rcx+8]
    mov qword ptr [r10], K_ADDR
    mov rax, [rcx+40]
    mov [r10+8], rax
    mov rax, [rcx+48]
    mov [r10+16], rax
    mov rax, [rcx+56]
    add rax, r11
    mov [r10+24], rax
9:  pop rax
    ret

# forget what is known of the variables: at a label, where another way may
# arrive, and at the end of a function. That also covers its start: the
# first pass may still see what the top level knew, but its checks are
# dropped with it, and the second pass starts after this
clrvk:
    lea rcx, [rip+vk]
    xor eax, eax
1:  mov qword ptr [rcx], 0
    add rcx, 32
    inc eax
    cmp eax, NVARS
    jb 1b
    ret

# a load or store (rdx = its row): if the address is a string, check the
# access now; if it is a global name plus a number, note it for fin, when the
# sizes of all names are known. Keeps rdx, r8 and r9.
memchk:
    movzx eax, byte ptr [rdx-1] # the last letter of the keyword gives the width
    mov ecx, 8
    cmp al, 'b'
    jne 1f
    mov ecx, 1
1:  cmp al, '2'
    jne 1f
    mov ecx, 2
1:  cmp al, '4'
    jne 1f
    mov ecx, 4
1:  test byte ptr [rdx+1], AS_NONE
    jz 1f
    or ecx, 0x100               # a store
1:  lea rax, [rip+opd]
    cmp qword ptr [rax], K_LIT
    jne 2f
    test ecx, 0x100             # a string is read-only
    jnz err_acc
    movzx ecx, cl
    cmp rcx, [rax+8]
    ja err_acc
    ret
2:  cmp qword ptr [rax], K_ADDR
    jne 3f
    mov r10d, [rip+nchks]
    shl r10d, 5
    lea r11, [rip+chks]
    add r10, r11
    mov r11, [rax+8]
    mov [r10], r11
    mov r11, [rax+16]
    mov [r10+8], r11
    mov r11, [rax+24]
    mov [r10+16], r11
    mov [r10+24], ecx
    inc dword ptr [rip+nchks]
3:  ret

# emit a 64-bit mov between the variable eax of the current scope and the
# register ecx: r9d = 0x8B to load the register, 0x89 to store it
emit_varmov:
    push rcx
    call varplace
    pop rax
    test edx, edx
    jz 1f
    cmp edx, 3
    jne emit_mem
    mov r9d, 0x8D               # a local: lea <register>, [rsp + distance]
    mov edx, 2
    jmp emit_mem
1:  cmp r9d, 0x8B
    jne emit_mov_rr             # store: from the register eax to the variable's
    xchg eax, ecx               # load: from the variable's register
    jmp emit_mov_rr

# emit a 64-bit mov between the register eax and memory: the address ecx
# (edx = 1) or rsp + ecx (edx = 2); r9d = 0x8B to load, 0x89 to store
emit_mem:
    mov r10d, eax
    shr r10d, 3
    shl r10d, 2                 # REX.R: the register is r8-r15
    or r10d, 0x48
    mov [rdi], r10b
    mov [rdi+1], r9b
    and eax, 7
    shl eax, 3
    cmp edx, 1
    jne 1f
    or al, 0x04                 # ModRM: no base, SIB follows; SIB: disp32 alone
    mov ah, 0x25
    jmp 2f
1:  or al, 0x84                 # ModRM: base + disp32, SIB follows; SIB: rsp
    mov ah, 0x24
2:  mov [rdi+2], ax
    mov [rdi+4], ecx
    add rdi, 8
    ret

# where the variable eax of the current scope lives: edx = 0 and ecx = its
# x86 register, edx = 1 and ecx = the address of its cell, edx = 2 and
# ecx = its distance from rsp, or for a local edx = 3 and ecx = the distance
# of its bytes from rsp. Keeps r9.
varplace:
    cmp dword ptr [rip+infn], 0
    jne 2f
    cmp eax, NREGS              # top level: six registers, then cells
    jae 1f
0:  lea rcx, [rip+varnum]
    movzx ecx, byte ptr [rcx+rax]
    xor edx, edx
    ret
1:  lea rcx, [rip+topcell]
    mov ecx, [rcx+rax*4]
    mov edx, 1
    ret
2:  lea rcx, [rip+vlocal]
    mov ecx, [rcx+rax*4]
    test ecx, ecx
    jz 4f
    dec ecx                     # a local: above the stack slots
    mov edx, [rip+fnslots]
    lea ecx, [rcx+rdx*8]
    add ecx, [rip+pushed]
    mov edx, 3
    ret
4:  cmp dword ptr [rip+pass], 1 # first pass: no places yet, the code is dropped
    jne 3f
    xor eax, eax
    jmp 0b
3:  lea rcx, [rip+fnloc]
    movzx eax, byte ptr [rcx+rax]
    cmp eax, NREGS
    jb 0b
    lea ecx, [rax*8-NREGS*8]
    add ecx, [rip+pushed]       # call values pushed since move the slots away
    mov edx, 2
    ret

# read a variable name at rsi and find it in the pool of the current scope,
# or add it: eax = its index
defvar:
    call rdname
    call lookup_buf
    jc 3f
    cmp dword ptr [rip+infn], 0 # at top level a global name is taken; in a
    je err_dup                  # function the variable hides it, except a var
    lea rcx, [rip+bufkind]
    cmp byte ptr [rcx+rax], G_VAR
    je err_dup
3:  call lookup_var
    jnc 2f
    cmp ebp, NVARS              # new name: the next variable of the scope
    jae err_vars
    mov [r10], r8
    mov [r10+8], r9
    mov eax, ebp
    inc ebp
    cmp dword ptr [rip+infn], 0
    jne 4f
    cmp eax, NREGS              # top level: after the registers, a cell below
    jb 5f                       # the buffers, like a var
    mov ecx, [rip+nvars]
    inc ecx
    mov [rip+nvars], ecx
    shl ecx, 3
    neg ecx
    add ecx, BSS
    lea rdx, [rip+topcell]
    mov [rdx+rax*4], ecx
5:  ret
4:  lea rdx, [rip+vfirst]       # in a function: note where it starts
    mov [rdx+rax*8], rsi
2:  lea rdx, [rip+vlast]        # and where it is mentioned last
    mov [rdx+rax*8], rsi
    ret

# ---- buffers
# "buf <name> <size>": reserve zero-filled bytes in the writable segment
bufdef:
    call blank1
    call rdname
    call newglob
    call blank1
    cmp rsi, r15
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja 1f
    call constname              # the size is a const
    jmp 3f
1:  call rdnum                  # or a number
3:  mov rdx, 0x100000000 - BSS  # room in the 32-bit address range
    cmp rax, rdx
    ja err_bufs
    push rax
    call eol
    pop rax
    mov rdx, 0x100000000 - BSS
    mov ecx, [rip+nbufs]
    lea r10, [rip+bufkind]
    mov byte ptr [r10+rcx], G_ADDR
    lea r10, [rip+bufrun]
    mov dword ptr [r10+rcx*4], 0
    lea r10, [rip+bufsize]
    mov [r10+rcx*8], rax        # len gives the size as declared
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

# "local <name> <size>": bytes in the frame of the open function, not
# initialised and gone when it returns. The name takes one of the function's
# variables, whose value is the address.
localdef:
    cmp dword ptr [rip+infn], 0
    je err
    call blank1
    push rbp
    call defvar
    pop rcx
    cmp ecx, ebp                # the name must be new in the function
    je err_dup
    push rax
    call blank1
    cmp rsi, r15
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja 1f
    call constname
    jmp 2f
1:  call rdnum
2:  cmp rax, 0x7ffffff0
    ja err_bufs
    push rax
    call eol
    pop rax
    mov rcx, [rsp]
    lea r10, [rip+vlocsz]
    mov [r10+rcx*4], eax        # at checks against the size as declared
    add rax, 7
    and rax, -8
    pop rcx                     # the variable
    mov edx, [rip+loccur]
    lea r10, [rip+vlocal]
    lea r11d, [rdx+1]
    mov [r10+rcx*4], r11d
    add rax, rdx
    cmp rax, 0x7ffffff0
    ja err_bufs
    mov [rip+loccur], eax
    bts [rip+asg], rcx          # its value, the address, is always there
    mov eax, ecx
    shl eax, 5
    lea r10, [rip+vk]
    mov qword ptr [r10+rax], 0
    jmp next

# the name r8/r9 must not be in use at top level or in the open function:
# enter it as the next global name, eax = its index (nbufs is not advanced)
newglob:
    call lookup_var
    jnc err_dup
    call lookup_topvar          # a global name outlives the function: no
    jnc err_dup                 # top-level variable may have it either
    call lookup_buf
    jnc err_dup
    mov [r10], r8
    mov [r10+8], r9
    mov eax, [rip+nbufs]
    ret

# "var <name>...": global 64-bit cells, zero at start. They lie below the
# buffers, the first one highest, so their number need not be known
vardef:
    call blank1
1:  call rdname
    call newglob
    lea rcx, [rip+bufkind]
    mov byte ptr [rcx+rax], G_VAR
    mov ecx, [rip+nvars]
    inc ecx
    mov [rip+nvars], ecx
    shl ecx, 3
    neg ecx
    add ecx, BSS                # BSS - 8 * (its number, from 1)
    lea rdx, [rip+bufaddr]
    mov [rdx+rax*4], ecx
    inc dword ptr [rip+nbufs]
    call tokchk
    call blanks
    cmp rsi, r15
    jae 2f
    mov al, [rsi]
    cmp al, 10
    je 2f
    cmp al, 13
    je 2f
    cmp al, '#'
    jne 1b
2:  call eol
    jmp next

# "const <name> <number>": a name for a number
constdef:
    call blank1
    call rdname
    call newglob
    call blank1
    call rdnum
    push rax
    call eol
    pop rax
    mov ecx, [rip+nbufs]
    lea rdx, [rip+bufsize]
    mov [rdx+rcx*8], rax
    lea rdx, [rip+bufkind]
    mov byte ptr [rdx+rcx], G_CONST
    inc dword ptr [rip+nbufs]
    jmp next

# "data [<name>] <item>...": read-only bytes in the code stream behind a jmp;
# an item is a string or a byte value. Data statements that follow each other
# share one jmp, so their bytes are contiguous and a name is optional.
datadef:
    call blank1
    xor r13d, r13d              # 1 if the statement has a name
    cmp rsi, r15
    jae err
    mov al, [rsi]
    sub al, 'a'
    cmp al, 'z' - 'a'
    ja 1f
    call rdname
    call newglob
    call tokchk
    mov r13d, 1
1:  cmp rdi, [rip+dataend]
    je 2f
    mov byte ptr [rdi], 0xE9    # jmp rel32 over the data
    inc rdi
    mov [rip+datarel], rdi
    add rdi, 4
    inc dword ptr [rip+nruns]   # a new run of data statements
2:  push rdi                    # the first byte of this statement
    xor ebx, ebx                # number of items
3:  call blanks
    cmp rsi, r15
    jae 6f
    movzx eax, byte ptr [rsi]
    cmp al, 10
    je 6f
    cmp al, 13
    je 6f
    cmp al, '#'
    je 6f
    cmp al, '"'
    jne 4f
    inc rsi
    call strbytes
    jmp 5f
4:  call rdnum
    cmp rax, 255                # one byte
    ja err
    stosb
5:  call tokchk
    inc ebx
    jmp 3b
6:  test ebx, ebx               # at least one item
    jz err
    call eol
    pop rax
    test r13d, r13d
    jz 9f
    mov ecx, [rip+nbufs]
    lea r10, [rip+bufkind]
    mov byte ptr [r10+rcx], G_ADDR
    mov edx, [rip+nruns]
    lea r10, [rip+bufrun]
    mov [r10+rcx*4], edx
    mov rdx, rdi
    sub rdx, rax
    lea r10, [rip+bufsize]
    mov [r10+rcx*8], rdx
    sub rax, r14
    add rax, BASE
    lea r10, [rip+bufaddr]
    mov [r10+rcx*4], eax
    inc dword ptr [rip+nbufs]
9:  mov rcx, [rip+datarel]
    mov rax, rdi
    sub rax, rcx
    sub rax, 4
    mov [rcx], eax
    mov [rip+dataend], rdi
    mov rax, rdi                # the run ends here, so far
    sub rax, r14
    add rax, BASE
    mov ecx, [rip+nruns]
    lea rdx, [rip+runend]
    mov [rdx+rcx*4-4], eax
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
    lea rcx, [rip+labpos]
    mov [rcx+rax*8], rsi
    call labasg
    call clrvk
    mov eax, [rip+nlabels]
    lea rcx, [rip+labmask]
    mov rdx, [rip+asg]
    mov [rcx+rax*8], rdx
    inc dword ptr [rip+nlabels]
    mov qword ptr [rip+dataend], 0  # data after a label gets its own jmp
    jmp next

# the label name r8/r9 ends a jump: emit the statement's code, leave room
# for the rel32 and record it for fin, since the label may come later
jtarget:
    call eol
    call lookup_label
    jc 1f
    add eax, [rip+labbase]      # a jump back: every variable that the code after
    lea rcx, [rip+labmask]      # the label takes as assigned must be assigned here
    mov rcx, [rcx+rax*8]
    mov rdx, [rip+asg]
    not rdx
    test rcx, rdx
    jnz err_unasg
    cmp dword ptr [rip+pass], 1
    jne 1f
    lea rcx, [rip+labpos]       # first pass: it also makes a loop
    mov rax, [rcx+rax*8]
    mov ecx, [rip+nloops]
    shl ecx, 4
    lea rdx, [rip+loops]
    mov [rdx+rcx], rax
    mov [rdx+rcx+8], rsi
    inc dword ptr [rip+nloops]
1:  call emit_op
    mov eax, [rip+nfix]
    shl eax, 5
    lea rcx, [rip+fixs]
    add rcx, rax
    mov [rcx], r8
    mov [rcx+8], r9
    mov [rcx+16], rdi
    mov rax, [rip+asg]
    mov [rcx+24], rax
    add rdi, 4
    inc dword ptr [rip+nfix]
    mov rdx, [rip+curop]
    cmp byte ptr [rdx], 0       # jmp: nothing falls through to the next line
    jne next
    call godead
    jmp next

# no way leads to the code that follows, until a label: remember what was
# assigned and take everything as assigned, so that such code gives no error
godead:
    cmp dword ptr [rip+dead], 0
    jne 1f
    mov rax, [rip+asg]
    mov [rip+jmask], rax
    mov dword ptr [rip+dead], 1
    mov qword ptr [rip+asg], -1
1:  ret

# the label r8/r9 is being defined: asg becomes what is assigned on every way
# to it, the line before (if it falls through) and each jump seen so far. A
# label that only later jumps reach starts from what was assigned before the
# code became unreachable; those jumps are then checked against it.
labasg:
    push rbx
    push rbp
    mov rbp, [rip+asg]
    xor r13d, r13d              # jumps found
    mov eax, [rip+fixbase]
    mov ebx, [rip+nfix]
    sub ebx, eax
    shl eax, 5
    lea rcx, [rip+fixs]
    lea rax, [rcx+rax]
1:  test ebx, ebx
    jz 3f
    push rax
    mov r10, rax
    mov edx, 1
    call lookup                 # is this jump to the label?
    pop rax
    jc 2f
    and rbp, [rax+24]
    inc r13d
2:  add rax, 32
    dec ebx
    jmp 1b
3:  cmp dword ptr [rip+dead], 0
    je 4f
    test r13d, r13d
    jnz 4f
    mov rbp, [rip+jmask]
4:  mov [rip+asg], rbp
    mov dword ptr [rip+dead], 0
    pop rbp
    pop rbx
    ret

# ---- functions
# "fn <name> <parameter>...": jump over the body, save the caller's variable
# registers and open a scope whose first variables are the parameters
fndef:
    cmp dword ptr [rip+infn], 0 # functions do not nest
    jne err
    cmp dword ptr [rip+pass], 0
    jne 1f
    lea rax, [rip+snap]         # first pass: remember where to come back to
    mov [rax], rsi
    mov [rax+8], rdi
    mov ecx, [rip+nbufs]
    mov [rax+16], rcx
    mov ecx, [rip+nvars]
    mov [rax+24], rcx
    mov rcx, [rip+bsssz]
    mov [rax+32], rcx
    mov ecx, [rip+ncalls]
    mov [rax+40], rcx
    mov ecx, [rip+nfuncs]
    mov [rax+48], rcx
    mov ecx, [rip+nrefs]
    mov [rax+56], rcx
    mov rcx, [rip+dataend]
    mov [rax+64], rcx
    mov rcx, [rip+datarel]
    mov [rax+72], rcx
    mov ecx, [rip+nchks]
    mov [rax+80], rcx
    mov ecx, [rip+nruns]
    mov [rax+88], rcx
    mov dword ptr [rip+pass], 1
    mov dword ptr [rip+fnslots], 0
    mov dword ptr [rip+fnregs], NREGS
    mov dword ptr [rip+fnlocal], 0
    mov dword ptr [rip+nloops], 0
1:  mov dword ptr [rip+loccur], 0
    mov dword ptr [rip+fnres], 0
    mov dword ptr [rip+fntail], 0
    call clrloc
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
    lea rsi, [rip+fnpush]       # save the registers the function uses
    mov ecx, [rip+fnregs]
    lea rax, [rip+pushlen]
    movzx ecx, byte ptr [rax+rcx]
    rep movsb
    pop rsi
    mov al, 0xEC
    call emit_frame
    mov [rip+topvars], ebp
    xor ebp, ebp
    mov eax, [rip+blkbase]      # the blocks open outside are not the function's
    mov [rip+topblk], eax
    mov eax, [rip+nblk]
    mov [rip+blkbase], eax
    mov rax, [rip+asg]          # the top level goes on after the function with
    mov [rip+topasg], rax       # what it had assigned
    mov eax, [rip+dead]
    mov [rip+topasg+8], rax
    mov rax, [rip+jmask]
    mov [rip+topasg+16], rax
    mov qword ptr [rip+asg], 0
    mov dword ptr [rip+dead], 0
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
    bts [rip+asg], rax          # a parameter is assigned
    cmp eax, NREGS
    jae 3f
    lea rdx, [rip+argnum]
    movzx ecx, byte ptr [rdx+rax]
    mov r9d, 0x89
    call emit_varmov            # mov <variable>, <argument reg>
    jmp 1b
3:  push rax                    # from the seventh on the caller pushed them, the
    mov ecx, [rip+fnnpar]       # last one nearest: above the slots, the locals,
    sub ecx, eax                # the saved registers and the return address
    add ecx, [rip+fnslots]
    add ecx, [rip+fnregs]
    shl ecx, 3
    add ecx, [rip+fnlocal]
    mov eax, 11
    mov edx, 2
    mov r9d, 0x8B
    call emit_mem               # mov r11, [rsp + distance]
    pop rax
    mov ecx, 11
    mov r9d, 0x89
    call emit_varmov            # mov <variable>, r11
    jmp 1b
2:  call eol
    mov [rip+fnnpar], ebp
    mov eax, [rip+nfuncs]
    lea rcx, [rip+funargs]
    mov [rcx+rax], bpl
    inc dword ptr [rip+nfuncs]
    jmp next

# "end": return zero, resolve the jumps of the function and drop its labels,
# variables and jumps
fnend:
    mov eax, [rip+nblk]         # with a block open, end closes the block
    cmp eax, [rip+blkbase]
    ja blkend
    cmp dword ptr [rip+infn], 0
    je err
    call eol
    mov eax, [rip+fnres]        # a function without ret has one result, or if
    mov edx, eax                # it has a tail, those of the function it jumps
    test eax, eax               # to: unknown here, so any number may be named
    jnz 1f
    mov eax, 1
    mov edx, 1
    cmp dword ptr [rip+fntail], 0
    je 1f
    mov edx, 6
1:  mov ecx, [rip+nfuncs]
    lea r10, [rip+funres-1]
    mov [r10+rcx], dl
    push rsi                    # reaching end returns zero in every result
    lea rsi, [rip+zeroes]
    lea rcx, [rip+zerolen]
    movzx ecx, byte ptr [rcx+rax-1]
    rep movsb
    pop rsi
    mov al, 0xC4
    call emit_frame
    push rsi
    call popskip                # restore the registers the function saved
    lea rsi, [rip+retcode]
    add rsi, rax
    mov ecx, RETSZ
    sub ecx, eax
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
    mov rax, [rip+topasg]
    mov [rip+asg], rax
    mov rax, [rip+topasg+8]
    mov [rip+dead], eax
    mov rax, [rip+topasg+16]
    mov [rip+jmask], rax
    mov eax, [rip+topblk]
    mov [rip+blkbase], eax
    call clrvk
    mov rcx, [rip+fnskip]       # top-level code continues here
    mov rax, rdi
    sub rax, rcx
    sub rax, 4
    mov [rcx], eax
    cmp dword ptr [rip+pass], 1
    jne 1f
    mov eax, [rip+loccur]
    mov [rip+fnlocal], eax
    call alloc                  # first pass done: place the variables and
    lea rax, [rip+snap]         # compile the function again
    mov rsi, [rax]
    mov rdi, [rax+8]
    mov rcx, [rax+16]
    mov [rip+nbufs], ecx
    mov rcx, [rax+24]
    mov [rip+nvars], ecx
    mov rcx, [rax+32]
    mov [rip+bsssz], rcx
    mov rcx, [rax+40]
    mov [rip+ncalls], ecx
    mov rcx, [rax+48]
    mov [rip+nfuncs], ecx
    mov rcx, [rax+56]
    mov [rip+nrefs], ecx
    mov rcx, [rax+64]
    mov [rip+dataend], rcx
    mov rcx, [rax+72]
    mov [rip+datarel], rcx
    mov rcx, [rax+80]
    mov [rip+nchks], ecx
    mov rcx, [rax+88]
    mov [rip+nruns], ecx
    mov ebp, [rip+topvars]
    mov dword ptr [rip+pass], 2
    jmp fndef
1:  call clrloc                 # not before alloc, which must know the locals
    mov dword ptr [rip+pass], 0
    mov dword ptr [rip+fnslots], 0
    mov dword ptr [rip+fnregs], NREGS
    mov dword ptr [rip+fnlocal], 0
    mov ebp, [rip+topvars]
    jmp next

# no variable is a local: where a function starts and ends
clrloc:
    lea rcx, [rip+vlocal]
    xor eax, eax
1:  mov dword ptr [rcx+rax*4], 0
    inc eax
    cmp eax, NVARS
    jb 1b
    ret

# rcx = the innermost open block, which the statement at hand closes or
# continues; the jump recorded for it lands here
blktop:
    mov eax, [rip+nblk]
    dec eax
    lea rax, [rax+rax*2]
    lea rcx, [rip+blks]
    lea rcx, [rcx+rax*8]
    mov rdx, [rcx]
    mov rax, rdi
    sub rax, rdx
    sub rax, 4
    mov [rdx], eax
    ret

# "end" with a block open. After a plain block the two ways here are its
# last line and the jump past it; after an else part, its last line and the
# last line of the part before. What is assigned is what both have assigned.
blkend:
    call eol
    call blktop
    dec dword ptr [rip+nblk]
    cmp dword ptr [rcx+16], 0
    je 1f
    cmp dword ptr [rcx+20], 0   # the part before else ended in jmp or ret:
    jne 3f                      # only this way arrives
1:  mov rax, [rcx+8]
    cmp dword ptr [rip+dead], 0
    je 2f
    mov [rip+asg], rax          # only the other way arrives
    mov dword ptr [rip+dead], 0
    jmp 3f
2:  and [rip+asg], rax
3:  call clrvk
    mov qword ptr [rip+dataend], 0
    jmp next

# "else": the block so far ends with a jump past the rest, and the jump of
# its "if" lands here
elsedef:
    mov eax, [rip+nblk]
    cmp eax, [rip+blkbase]
    jbe err
    call eol
    mov byte ptr [rdi], 0xE9    # jmp rel32, filled in at end
    inc rdi
    mov r8, rdi
    add rdi, 4
    call blktop
    cmp dword ptr [rcx+16], 0   # one else to a block
    jne err
    mov [rcx], r8
    mov rax, [rcx+8]            # the else part starts with what the if had
    mov rdx, [rip+asg]          # and remembers how the part before ended
    mov [rcx+8], rdx
    mov edx, [rip+dead]
    mov [rcx+20], edx
    mov dword ptr [rcx+16], 1
    mov [rip+asg], rax
    mov dword ptr [rip+dead], 0
    call clrvk                  # (the jmp above already parted any data)
    jmp next

# emit "sub rsp, <frame>" (al = 0xEC) or "add rsp, <frame>" (al = 0xC4) when
# the function has stack slots or locals
emit_frame:
    mov ecx, [rip+fnslots]
    shl ecx, 3
    add ecx, [rip+fnlocal]
    jz 1f
    cmp al, 0xEC
    jne 2f
    cmp ecx, 4096
    jae 3f
2:  mov word ptr [rdi], 0x8148
    mov [rdi+2], al
    mov [rdi+3], ecx
    add rdi, 7
1:  ret
3:  push rsi                    # a page or more: reserve it with a probe
    push rcx
    lea rsi, [rip+probe]
    mov ecx, PROBESZ
    rep movsb
    pop rcx
    pop rsi
    mov [rdi-PROBESZ+2], ecx
    ret

# eax = how many bytes of the six pops to leave out: those of the registers
# that the function does not use and so did not save
popskip:
    mov eax, [rip+fnregs]
    lea rcx, [rip+pushlen]
    movzx ecx, byte ptr [rcx+rax]
    mov eax, FNPUSHSZ
    sub eax, ecx
    ret

# give each of the ebp variables of the function a place. A variable is in
# use from its definition to its last mention; if that range meets a loop,
# to the end of the loop, since the next round may read it again. A place is
# free for a variable defined after the last mention of the one that had it.
alloc:
1:  xor r8d, r8d                # stretch the ranges until nothing changes
    mov ecx, [rip+nloops]
    lea rbx, [rip+loops]
2:  test ecx, ecx
    jz 5f
    mov r10, [rbx]              # the label
    mov r11, [rbx+8]            # the jump back to it
    xor eax, eax
3:  cmp eax, ebp
    jae 4f
    lea rdx, [rip+vfirst]
    cmp [rdx+rax*8], r11
    ja 6f                       # defined after the loop
    lea rdx, [rip+vlast]
    cmp [rdx+rax*8], r10
    jb 6f                       # not mentioned in or after it
    cmp [rdx+rax*8], r11
    jae 6f
    mov [rdx+rax*8], r11
    mov r8d, 1
6:  inc eax
    jmp 3b
4:  add rbx, 16
    dec ecx
    jmp 2b
5:  test r8d, r8d
    jnz 1b
    lea rdx, [rip+locfree]
    xor ecx, ecx
7:  mov qword ptr [rdx+rcx*8], 0
    inc ecx
    cmp ecx, NREGS + NVARS
    jb 7b
    mov dword ptr [rip+fnslots], 0
    mov dword ptr [rip+fnregs], 0
    xor eax, eax
8:  cmp eax, ebp
    jae 9f
    lea rdx, [rip+vlocal]       # a local has its place in the frame
    cmp dword ptr [rdx+rax*4], 0
    jne 60f
    lea rdx, [rip+vfirst]
    mov r10, [rdx+rax*8]
    lea rdx, [rip+vlast]
    mov r11, [rdx+rax*8]
    lea rdx, [rip+locfree]
    xor ecx, ecx
7:  cmp [rdx+rcx*8], r10        # the first place whose variable is done
    jb 6f
    inc ecx
    jmp 7b
6:  mov [rdx+rcx*8], r11
    lea rdx, [rip+fnloc]
    mov [rdx+rax], cl
    cmp ecx, NREGS
    jae 61f
    cmp ecx, [rip+fnregs]       # a register: count how many are in use
    jb 6f
    lea edx, [rcx+1]
    mov [rip+fnregs], edx
    jmp 6f
61: sub ecx, NREGS - 1          # a slot: count it
    jle 6f
    cmp ecx, [rip+fnslots]
    jbe 6f
    mov [rip+fnslots], ecx
6:
60: inc eax
    jmp 8b
9:  ret

# fill in the jumps of the current scope, now that all its labels are known
resolve:
    push rbx
    push rbp
    mov eax, [rip+fixbase]
    mov ebp, [rip+nfix]
    sub ebp, eax
    shl eax, 5
    lea rbx, [rip+fixs]
    add rbx, rax
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
    add rbx, 32
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
    test byte ptr [rdx+2], IS_PTR >> 8
    jz 6f
    test ebx, ebx               # callp too, after the address
    jz err
    jmp 1f
6:  test byte ptr [rdx+1], IS_RET
    jz 6f
    test ebx, ebx               # ret: one to six results, the same number at
    jz err                      # every ret of the function
    cmp ebx, 6
    ja err
    mov eax, [rip+fnres]
    test eax, eax
    jnz 7f
    mov [rip+fnres], ebx
    mov eax, ebx
7:  cmp eax, ebx
    jne err_res
    jmp 1f
6:  cmp bl, [rdx]
    jne err
    test byte ptr [rdx+1], IS_MEM
    jz 1f
    call memchk
1:  test byte ptr [rdx+1], IS_RET
    jz 3f
    test byte ptr [rdx+1], IS_CALL
    jz 4f
    cmp ebx, 6                  # tail: the values must be in registers, since
    ja err                      # the frame that would hold the others is gone
    mov dword ptr [rip+fntail], 1
4:  mov al, 0xC4                # ret: release the stack slots first
    call emit_frame
    call godead                 # and nothing falls through to the next line
    call popskip                # then pop only what the function saved
    mov rdx, [rip+curop]
    movzx ecx, byte ptr [rdx+3]
    sub ecx, eax
    push rsi
    lea rsi, [rdx+rax+4]
    rep movsb
    pop rsi
    jmp 5f
3:  movzx ecx, byte ptr [rdx+3]
    push rsi
    lea rsi, [rdx+4]
    rep movsb
    pop rsi
5:
    test byte ptr [rdx+1], IS_CALL
    jz 8f
    test byte ptr [rdx+2], IS_REF >> 8
    jz 9f
    test ebx, ebx               # ref takes the name alone and gives one value
    jnz err
    cmp dword ptr [rip+ncap], 1
    jne err
    mov ebx, -1                 # recorded as a call with no count: an address
9:  mov eax, [rip+ncalls]
    shl eax, 5
    lea rcx, [rip+calls]
    add rcx, rax
    mov rax, [rip+callname]
    mov [rcx], rax
    mov rax, [rip+callname+8]
    mov [rcx+8], rax
    mov [rcx+16], rdi
    mov [rcx+24], ebx
    mov eax, [rip+ncap]
    mov [rcx+28], eax
    add rdi, 4
    inc dword ptr [rip+ncalls]
8:  mov eax, [rip+pushed]       # drop the values that went on the stack
    test eax, eax
    jz 2f
    mov word ptr [rdi], 0x8148  # add rsp, imm32
    mov byte ptr [rdi+2], 0xC4
    mov [rdi+3], eax
    add rdi, 7
    mov dword ptr [rip+pushed], 0
2:  ret

# ecx = the row of regtab and argnum for the next value of the statement:
# its position, or 7 (r11) for a value of a call after the sixth
argidx:
    mov ecx, ebx
    mov rdx, [rip+curop]
    test byte ptr [rdx+2], IS_PTR >> 8
    jz 3f
    test ebx, ebx               # callp: the address goes to rcx, row 8, and
    jnz 4f                      # the values after it are those of a call
    mov ecx, 8
    ret
4:  dec ecx
    jmp 5f
3:  test byte ptr [rdx+1], IS_CALL
    jz 1f
5:  cmp ecx, 6
    jb 2f
    mov ecx, 7
    ret
1:  cmp ebx, 7
    jae err
2:  ret

# the value is in its register: push it if it goes on the stack, count it
argnext:
    mov rdx, [rip+curop]
    mov eax, ebx
    test byte ptr [rdx+2], IS_PTR >> 8
    jz 2f
    dec eax
    jmp 3f
2:  test byte ptr [rdx+1], IS_CALL
    jz 1f
3:  cmp eax, 6
    jl 1f
    mov word ptr [rdi], 0x5341  # push r11
    add rdi, 2
    add dword ptr [rip+pushed], 8
1:  inc ebx
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

# emit "mov <arg reg ebx>, rax" in its shortest form and advance ebx.
# Keeps r8 and r9.
emit_mov:
    call argidx
    mov rdx, rax
    shr rdx, 32
    jnz 2f
    lea r10, [rip+regtab]       # 32 bits: mov r32, imm32 clears the upper half
    movzx edx, byte ptr [r10+rcx*2]
    test edx, edx
    jz 1f
    mov [rdi], dl
    inc rdi
1:  mov dl, [r10+rcx*2+1]
    mov [rdi], dl
    mov [rdi+1], eax
    lea rdx, [rdi+1]
    mov [rip+immpos], rdx       # for a value that is filled in later
    add rdi, 5
    jmp argnext
2:  lea r10, [rip+argnum]
    movzx ecx, byte ptr [r10+rcx]
    mov edx, ecx
    shr edx, 3                  # REX.B: the register is r8-r15
    or edx, 0x48                # REX.W
    mov [rdi], dl
    and ecx, 7
    movsxd rdx, eax
    cmp rdx, rax
    jne 3f
    mov byte ptr [rdi+1], 0xC7  # mov r64, imm32, sign-extended
    or cl, 0xC0
    mov [rdi+2], cl
    mov [rdi+3], eax
    add rdi, 7
    jmp argnext
3:  or cl, 0xB8                 # mov r64, imm64
    mov [rdi+1], cl
    mov [rdi+2], rax
    add rdi, 10
    jmp argnext

# ---- implicit exit(0), patch jumps, calls and sizes, write ELF to stdout
fin:
    cmp dword ptr [rip+infn], 0 # a function without its end
    jne err
    cmp dword ptr [rip+nblk], 0 # or a block
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
    cmp dword ptr [rbx+24], -1
    je 3f
    lea rcx, [rip+funargs]
    movzx ecx, byte ptr [rcx+rax]
    cmp ecx, [rbx+24]
    jne err_argc
    lea rcx, [rip+funres]       # no more names after "as" than it has results
    movzx ecx, byte ptr [rcx+rax]
    cmp [rbx+28], ecx
    ja err_res
    lea rcx, [rip+funaddr]
    mov rax, [rcx+rax*8]
    mov rcx, [rbx+16]
    sub rax, rcx
    sub rax, 4                  # relative to the end of the rel32
    mov [rcx], eax
    jmp 4f
3:  lea rcx, [rip+funaddr]      # ref: the address the function is loaded at
    mov rax, [rcx+rax*8]
    sub rax, r14
    add rax, BASE
    mov rcx, [rbx+16]
    mov [rcx], eax
4:  add rbx, 32
    dec ebp
    jmp 1b
2:  lea rbx, [rip+refs]         # every global name is known now: fill in the
    mov ebp, [rip+nrefs]        # uses that came before their declaration
1:  test ebp, ebp
    jz 2f
    mov r8, [rbx]
    mov r9, [rbx+8]
    call lookup_buf
    jc err_undef
    lea rcx, [rip+bufkind]      # a var or a const must be declared first
    cmp byte ptr [rcx+rax], G_ADDR
    jne err_undef
    lea rcx, [rip+bufaddr]
    mov ecx, [rcx+rax*4]
    cmp dword ptr [rbx+24], 0
    je 3f
    lea rdx, [rip+bufrun]
    mov edx, [rdx+rax*4]
    cmp dword ptr [rbx+24], 2   # for at, data reaches to the end of its run
    jne 4f
    test edx, edx
    jz 4f
    lea r10, [rip+runend]
    mov edx, [r10+rdx*4-4]
    sub edx, ecx
    mov ecx, edx
    jmp 3f
4:  lea rcx, [rip+bufsize]
    mov ecx, [rcx+rax*8]
3:  mov rax, [rbx+16]
    mov [rax], ecx
    add rbx, 32
    dec ebp
    jmp 1b
2:  lea rbx, [rip+chks]         # every size is known now: check the loads and
    mov ebp, [rip+nchks]        # stores whose address is a name plus a number
1:  test ebp, ebp
    jz 2f
    mov r8, [rbx]
    mov r9, [rbx+8]
    call lookup_buf
    jc 4f
    lea rcx, [rip+bufkind]
    cmp byte ptr [rcx+rax], G_ADDR
    jne 4f
    lea rcx, [rip+bufrun]
    mov ecx, [rcx+rax*4]
    test ecx, ecx
    jz 3f
    test dword ptr [rbx+24], 0x100  # data is read-only
    jnz err_acc
    lea rdx, [rip+runend]       # and reaches to the end of its run
    mov edx, [rdx+rcx*4-4]
    lea rcx, [rip+bufaddr]
    mov ecx, [rcx+rax*4]
    sub rdx, rcx
    jmp 5f
3:  lea rcx, [rip+bufsize]      # a buffer has its declared size
    mov rdx, [rcx+rax*8]
5:  mov rax, [rbx+16]
    movzx ecx, byte ptr [rbx+24]
    cmp rax, rdx                # the offset, then the width, must fit
    jae err_acc
    sub rdx, rax
    cmp rcx, rdx
    ja err_acc
4:  add rbx, 32
    dec ebp
    jmp 1b
2:
    mov r13, rdi
    sub r13, r14                # file size
    mov [r14+64+32], r13
    mov [r14+64+40], r13
    mov eax, [rip+nvars]        # the writable segment starts a whole number of
    shl rax, 3                  # pages below the buffers, to hold the vars
    add rax, 4095
    and rax, -4096
    mov ecx, BSS
    sub rcx, rax
    mov [r14+64+56+16], rcx     # its address
    mov [r14+64+56+24], rcx
    add rax, [rip+bsssz]
    mov [r14+64+56+40], rax     # its memory size
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
err_num:
    lea rsi, [rip+m_num]
    mov edx, M_NUM_SZ
    mov ebx, 1
    jmp die
err_unasg:
    lea rsi, [rip+m_unasg]
    mov edx, M_UNASG_SZ
    mov ebx, 1
    jmp die
err_acc:
    lea rsi, [rip+m_acc]
    mov edx, M_ACC_SZ
    mov ebx, 1
    jmp die
err_use:
    lea rsi, [rip+m_use]
    mov edx, M_USE_SZ
    mov ebx, 1
    jmp die
err_res:
    lea rsi, [rip+m_res]
    mov edx, M_RES_SZ
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

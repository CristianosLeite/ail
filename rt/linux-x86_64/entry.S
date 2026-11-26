/* The image of the runtime: its header, the table of its entries, and an
 * entry for each service, which a program calls with its values in rax,
 * rdi, rsi, rdx and r10 and any stack, and which calls the C function
 * with the state first, by the convention of the platform. The results
 * come back in rax and rdi; rbx, rbp and r12 to r15 are kept.
 *
 * The header: the bytes "AILR", the version, the size of the image, the
 * bytes of state, the number of entries, four bytes of zeros, then eight
 * bytes that the compiler fills in, the distance from the start of the
 * image to the state, and the offsets of the entries, four bytes each. */
#include "rt.h"

	.section .head, "ax"
	.globl rt_image
rt_image:
	.ascii "AILR"
	.long 1
	.long rt_end - rt_image
	.long RT_STATE
	.long (rt_table_end - rt_table) / 4
	.long 0
rt_state:
	.quad 0
rt_table:
	.long e_start - rt_image
	.long e_exit - rt_image
	.long e_args - rt_image
	.long e_alloc - rt_image
	.long e_free - rt_image
	.long e_open - rt_image
	.long e_close - rt_image
	.long e_read - rt_image
	.long e_write - rt_image
	.long e_pipeerr - rt_image
	.long e_mkdir - rt_image
	.long e_unlink - rt_image
	.long e_rmdir - rt_image
	.long e_rename - rt_image
	.long e_names - rt_image
	.long e_clock - rt_image
	.long e_sleep - rt_image
	.long e_wait - rt_image
	.long e_wake - rt_image
	.long e_cpus - rt_image
	.long e_thread - rt_image
rt_table_end:

	.text
.macro entry name
e_\name:
	push %rbp
	mov %rsp, %rbp
	and $-16, %rsp
	mov %r10, %r9
	mov %rdx, %r8
	mov %rsi, %rcx
	mov %rdi, %rdx
	mov %rax, %rsi
	lea rt_image(%rip), %rdi
	add rt_state(%rip), %rdi
	call rt_\name
	mov %rdx, %rdi
	leave
	ret
.endm

/* where the process starts: keep the stack and go on at the first
 * statement of the program, which stands behind the image */
e_start:
	lea rt_image(%rip), %rax
	add rt_state(%rip), %rax
	mov %rsp, (%rax)
	jmp rt_end

	entry exit
	entry args
	entry alloc
	entry free
	entry open
	entry close
	entry read
	entry write
	entry pipeerr
	entry mkdir
	entry unlink
	entry rmdir
	entry rename
	entry names
	entry clock
	entry sleep
	entry wait
	entry wake
	entry cpus

/* thread: start a thread that calls the function in rax with the value
 * in rdi, by the convention of AIL, and ends when it returns. 0, or the
 * error of the kernel for the memory, the closed page or the thread.
 * The stack is 8 MiB of its own whose lowest page is closed before the
 * thread exists, so that a function that needs more faults; the thread
 * gives it back at its end, with no stack under it from there on. The
 * new thread comes out of the system call with the registers of this
 * one, which is where it has the function, the value and its stack. */
e_thread:
	push %rbx
	push %r12
	push %r13
	mov %rax, %rbx
	mov %rdi, %r12
	xor %edi, %edi
	mov $0x800000, %esi
	mov $3, %edx
	mov $0x22, %r10d
	mov $-1, %r8
	xor %r9d, %r9d
	mov $9, %eax
	syscall
	cmp $-4096, %rax
	ja 9f
	mov %rax, %r13
	mov %rax, %rdi
	mov $4096, %esi
	xor %edx, %edx
	mov $10, %eax
	syscall
	test %rax, %rax
	jnz 8f
	mov $0x50f00, %edi
	lea 0x800000(%r13), %rsi
	xor %edx, %edx
	xor %r10d, %r10d
	xor %r8d, %r8d
	mov $56, %eax
	syscall
	test %rax, %rax
	jz 1f
	cmp $-4096, %rax
	ja 8f
	xor %eax, %eax
	jmp 9f
1:	mov %r12, %rax
	call *%rbx
	mov %r13, %rdi
	mov $0x800000, %esi
	mov $11, %eax
	syscall
	xor %edi, %edi
	mov $60, %eax
	syscall
8:	mov %rax, %r12
	mov %r13, %rdi
	mov $0x800000, %esi
	mov $11, %eax
	syscall
	mov %r12, %rax
9:	pop %r13
	pop %r12
	pop %rbx
	ret

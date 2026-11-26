/* The services of the runtime for x86-64 Linux; rt.h says what the file
 * is, entry.S how a program reaches a function of it. */
#include "rt.h"

_Static_assert(sizeof(struct rt) == RT_STATE, "RT_STATE is not the size of the state");

static inline long sys6(long n, long a, long b, long c, long d, long e, long f)
{
	register long r10 __asm__("r10") = d;
	register long r8 __asm__("r8") = e;
	register long r9 __asm__("r9") = f;
	long r;
	__asm__ volatile("syscall" : "=a"(r)
		: "a"(n), "D"(a), "S"(b), "d"(c), "r"(r10), "r"(r8), "r"(r9)
		: "rcx", "r11", "memory");
	return r;
}

#define sys1(n, a) sys6(n, (long)(a), 0, 0, 0, 0, 0)
#define sys2(n, a, b) sys6(n, (long)(a), (long)(b), 0, 0, 0, 0)
#define sys3(n, a, b, c) sys6(n, (long)(a), (long)(b), (long)(c), 0, 0, 0)
#define sys4(n, a, b, c, d) sys6(n, (long)(a), (long)(b), (long)(c), (long)(d), 0, 0)

enum {
	SYS_read = 0, SYS_write = 1, SYS_open = 2, SYS_close = 3, SYS_mmap = 9,
	SYS_munmap = 11, SYS_rt_sigaction = 13, SYS_exit_group = 231
};

/* end the process, every thread of it */
long rt_exit(struct rt *rt, long code)
{
	(void)rt;
	for (;;)
		sys1(SYS_exit_group, code);
}

/* the address of the count of arguments; behind it their addresses, a
 * zero, the addresses of the environment and a zero */
long rt_args(struct rt *rt)
{
	return rt->sp;
}

/* n bytes of zeros at a multiple of 16, or 0: one mapping a call, with
 * its length in the 16 bytes before the address */
long rt_alloc(struct rt *rt, unsigned long n)
{
	unsigned long p;

	(void)rt;
	if (n >= -4096UL)
		return 0;
	p = sys6(SYS_mmap, 0, n + 16, 3, 0x22, -1, 0);
	if (p > -4096UL)
		return 0;
	*(unsigned long *)p = n + 16;
	return p + 16;
}

/* give back what rt_alloc returned; 0 is nothing */
long rt_free(struct rt *rt, unsigned long p)
{
	(void)rt;
	if (p)
		sys2(SYS_munmap, p - 16, *(unsigned long *)(p - 16));
	return 0;
}

/* open the file whose path is the n bytes at path; a descriptor or an
 * error */
long rt_open(struct rt *rt, const char *path, unsigned long n, long flags, long mode)
{
	char z[4096];
	unsigned long i;

	(void)rt;
	if (n >= sizeof z)
		return -RT_ENAMETOOLONG;
	for (i = 0; i < n; i++)
		z[i] = path[i];
	z[n] = 0;
	return sys3(SYS_open, z, flags, mode);
}

long rt_close(struct rt *rt, long fd)
{
	(void)rt;
	return sys1(SYS_close, fd);
}

/* up to n bytes: how many were read, 0 at the end, or an error */
long rt_read(struct rt *rt, long fd, void *p, unsigned long n)
{
	(void)rt;
	return sys3(SYS_read, fd, p, n);
}

/* up to n bytes: how many were written, or an error */
long rt_write(struct rt *rt, long fd, const void *p, unsigned long n)
{
	(void)rt;
	return sys3(SYS_write, fd, p, n);
}

/* from now on a write to a pipe or a socket whose other end is closed
 * is the error -32 and no longer the end of the process: the signal of
 * the kernel for it is ignored, in this process and in those it starts */
long rt_pipeerr(struct rt *rt)
{
	struct {
		long handler;
		unsigned long flags;
		long restorer;
		unsigned long mask;
	} act = { 1, 0, 0, 0 };

	(void)rt;
	return sys4(SYS_rt_sigaction, 13, &act, 0, 8);
}

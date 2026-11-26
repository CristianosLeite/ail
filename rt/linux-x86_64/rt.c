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
	SYS_munmap = 11, SYS_rt_sigaction = 13, SYS_rename = 82, SYS_mkdir = 83,
	SYS_rmdir = 84, SYS_unlink = 87, SYS_getdents64 = 217, SYS_exit_group = 231
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

/* the n bytes of a path with a zero behind them, as the kernel takes
 * one, in the 4096 bytes at z: 0, or the error of a path too long */
static long path0(char *z, const char *path, unsigned long n)
{
	unsigned long i;

	if (n >= 4096)
		return -RT_ENAMETOOLONG;
	for (i = 0; i < n; i++)
		z[i] = path[i];
	z[n] = 0;
	return 0;
}

/* open the file whose path is the n bytes at path; a descriptor or an
 * error */
long rt_open(struct rt *rt, const char *path, unsigned long n, long flags, long mode)
{
	char z[4096];
	long r;

	(void)rt;
	r = path0(z, path, n);
	return r ? r : sys3(SYS_open, z, flags, mode);
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

/* make a directory, remove a file, remove an empty directory */
long rt_mkdir(struct rt *rt, const char *path, unsigned long n, long mode)
{
	char z[4096];
	long r;

	(void)rt;
	r = path0(z, path, n);
	return r ? r : sys2(SYS_mkdir, z, mode);
}

long rt_unlink(struct rt *rt, const char *path, unsigned long n)
{
	char z[4096];
	long r;

	(void)rt;
	r = path0(z, path, n);
	return r ? r : sys1(SYS_unlink, z);
}

long rt_rmdir(struct rt *rt, const char *path, unsigned long n)
{
	char z[4096];
	long r;

	(void)rt;
	r = path0(z, path, n);
	return r ? r : sys1(SYS_rmdir, z);
}

/* give a file another path, in place of a file that has it */
long rt_rename(struct rt *rt, const char *path, unsigned long n, const char *to, unsigned long m)
{
	char z[4096], y[4096];
	long r;

	(void)rt;
	r = path0(z, path, n);
	if (!r)
		r = path0(y, to, m);
	return r ? r : sys2(SYS_rename, z, y);
}

/* the next names of the directory that fd is open on, each with a zero
 * behind it and none of them "." or "..", into the n bytes at p, at
 * least 512: the bytes written, 0 after the last name, or an error.
 * The names of an entry are shorter than the entry, so those of what
 * the kernel puts into n bytes fit n bytes. */
long rt_names(struct rt *rt, long fd, char *p, unsigned long n)
{
	char d[4096];
	unsigned long o = 0;
	long r, i;

	(void)rt;
	if (n < 512)
		return -RT_EINVAL;
	for (;;) {
		r = sys3(SYS_getdents64, fd, d, n < sizeof d ? n : sizeof d);
		if (r <= 0)
			return r;
		for (i = 0; i < r;) {
			const char *s = d + i + 19;

			i += *(unsigned short *)(d + i + 16);
			if (s[0] == '.' && (!s[1] || (s[1] == '.' && !s[2])))
				continue;
			while (*s)
				p[o++] = *s++;
			p[o++] = 0;
		}
		if (o)
			return o;
	}
}

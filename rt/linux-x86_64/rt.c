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
#define sys5(n, a, b, c, d, e) sys6(n, (long)(a), (long)(b), (long)(c), (long)(d), (long)(e), 0)

enum {
	SYS_read = 0, SYS_write = 1, SYS_open = 2, SYS_close = 3, SYS_mmap = 9,
	SYS_poll = 7, SYS_munmap = 11, SYS_rt_sigaction = 13, SYS_rt_sigprocmask = 14, SYS_sched_yield = 24,
	SYS_dup2 = 33, SYS_nanosleep = 35, SYS_getpid = 39, SYS_socket = 41, SYS_connect = 42, SYS_sendto = 44, SYS_bind = 49,
	SYS_listen = 50, SYS_getsockname = 51, SYS_setsockopt = 54, SYS_getsockopt = 55,
	SYS_fork = 57, SYS_execve = 59, SYS_exit = 60, SYS_wait4 = 61, SYS_kill = 62, SYS_fcntl = 72, SYS_rename = 82, SYS_mkdir = 83,
	SYS_rmdir = 84, SYS_unlink = 87, SYS_getppid = 110, SYS_rt_sigtimedwait = 128, SYS_prctl = 157, SYS_futex = 202, SYS_sched_setaffinity = 203, SYS_sched_getaffinity = 204, SYS_getdents64 = 217, SYS_clock_gettime = 228,
	SYS_exit_group = 231, SYS_epoll_wait = 232, SYS_epoll_ctl = 233, SYS_accept4 = 288,
	SYS_eventfd2 = 290, SYS_epoll_create1 = 291, SYS_pidfd_open = 434
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

/* Memory. A block has 16 bytes before the address a program gets, the
 * first 8 of them saying what it is: the number of its class for a
 * small block, the length of its mapping for a large one, which is
 * always more. A small block is one of 39 sizes, from 32 bytes to 32
 * KiB with the 16 in them, four sizes for each doubling above 128, so
 * that at most a fifth of a block is not asked for. Small blocks are
 * cut from chunks of 256 KiB that the kernel maps and that are never
 * given back; a block that is freed is the first of the list of its
 * class and the next to be given out, zeroed then. A large block is a
 * mapping of its own, as every block was before.
 *
 * The lists are shared by the threads, and are only locked once the
 * runtime has started one: a program with one thread pays nothing for
 * the others. */
#define CHUNK 262144UL
#define SMALL 32768UL

/* the class of a block of t bytes in all, 32 to SMALL, and its size */
static unsigned class_of(unsigned long t)
{
	unsigned s;

	if (t <= 128)
		return (t + 15) / 16 - 2;
	s = 63 - __builtin_clzl(t - 1);
	return 7 + (s - 7) * 4 + ((t - 1) >> (s - 2) & 3);
}

static unsigned long class_size(unsigned c)
{
	unsigned s;

	if (c < 7)
		return (c + 2) * 16;
	c -= 7;
	s = 7 + c / 4;
	return (1UL << s) + (c % 4 + 1) * (1UL << (s - 2));
}

static void lock(struct rt *rt)
{
	int i;

	if (!rt->threads)
		return;
	while (__atomic_exchange_n(&rt->lock, 1, __ATOMIC_ACQUIRE))
		for (i = 0; __atomic_load_n(&rt->lock, __ATOMIC_RELAXED); i++) {
			if (i < 200)
				__builtin_ia32_pause();
			else
				sys1(SYS_sched_yield, 0);
		}
}

static void unlock(struct rt *rt)
{
	if (rt->threads)
		__atomic_store_n(&rt->lock, 0, __ATOMIC_RELEASE);
}

/* zeros over n words at p: the string instruction, which is the
 * fastest for the sizes of most blocks; its start costs more than a
 * small block takes in a loop */
static void zero(unsigned long *p, unsigned long n)
{
	if (n > 12) {
		__asm__ volatile("rep stosq" : "+D"(p), "+c"(n) : "a"(0L) : "memory");
		return;
	}
	while (n--)
		*p++ = 0;
}

/* n bytes of zeros at a multiple of 16, or 0 */
long rt_alloc(struct rt *rt, unsigned long n)
{
	unsigned long p, t = n + 16, size;
	unsigned c;

	if (t < 32)
		t = 32;
	if (n >= -4096UL)
		return 0;
	if (t > SMALL) {
		p = sys6(SYS_mmap, 0, t, 3, 0x22, -1, 0);
		if (p > -4096UL)
			return 0;
		*(unsigned long *)p = t;
		return p + 16;
	}
	c = class_of(t);
	size = class_size(c);
	lock(rt);
	p = (unsigned long)rt->freed[c];
	if (p) {
		rt->freed[c] = *(unsigned long **)p;
		unlock(rt);
		zero((unsigned long *)p, size / 8 - 2);
		return p;
	}
	if (rt->end - rt->next < size) {
		p = sys6(SYS_mmap, 0, CHUNK, 3, 0x22, -1, 0);
		if (p > -4096UL) {
			unlock(rt);
			return 0;
		}
		rt->next = p;
		rt->end = p + CHUNK;
	}
	p = rt->next;
	rt->next = p + size;
	unlock(rt);
	*(unsigned long *)p = c;
	return p + 16;
}

/* give back what rt_alloc returned; 0 is nothing */
long rt_free(struct rt *rt, unsigned long p)
{
	unsigned long c;

	if (!p)
		return 0;
	c = *(unsigned long *)(p - 16);
	if (c >= RT_CLASSES) {
		sys2(SYS_munmap, p - 16, c);
		return 0;
	}
	lock(rt);
	*(unsigned long **)p = rt->freed[c];
	rt->freed[c] = (unsigned long *)p;
	unlock(rt);
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

/* The kernel maps a small shared object into every process, whose
 * clock_gettime reads the clock without a system call. Its address is
 * among the pairs behind the environment (the pair 33); the function is
 * found by its name in the table of symbols, which the hash table of
 * either form leads to. 1 if anything is not as expected: the system
 * call is used then. */
struct sym {
	unsigned name;
	unsigned char info, other;
	unsigned short shndx;
	unsigned long value, size;
};

static int same(const char *a, const char *b)
{
	while (*a && *a == *b)
		a++, b++;
	return *a == *b;
}

static long vdso(struct rt *rt)
{
	static const char want[] = "__vdso_clock_gettime";
	unsigned long *p = (unsigned long *)rt->sp, base = 0, bias, *dyn = 0;
	unsigned long i, n = 0;
	const struct sym *tab = 0;
	const char *str = 0;
	const unsigned *hash = 0, *gnu = 0;

	p += 1 + *p + 1;		/* the arguments and their zero */
	while (*p)
		p++;			/* the environment */
	for (p++; *p; p += 2)
		if (*p == 33)
			base = p[1];
	if (!base)
		return 1;
	/* the header: where the program headers are, how large, how many */
	p = (unsigned long *)(base + *(unsigned long *)(base + 32));
	n = *(unsigned short *)(base + 56);
	bias = base;
	for (i = 0; i < n; i++, p = (unsigned long *)((char *)p + *(unsigned short *)(base + 54))) {
		if ((unsigned)*p == 1)		/* loaded: file offset, address */
			bias = base + p[1] - p[2];
		else if ((unsigned)*p == 2)	/* the dynamic table */
			dyn = (unsigned long *)(base + p[1]);
	}
	if (!dyn)
		return 1;
	for (; *dyn; dyn += 2) {
		if (*dyn == 4)
			hash = (const unsigned *)(bias + dyn[1]);
		else if (*dyn == 5)
			str = (const char *)(bias + dyn[1]);
		else if (*dyn == 6)
			tab = (const struct sym *)(bias + dyn[1]);
		else if (*dyn == 0x6ffffef5)
			gnu = (const unsigned *)(bias + dyn[1]);
	}
	if (!str || !tab)
		return 1;
	if (hash) {
		for (i = 0; i < hash[1]; i++)
			if (tab[i].shndx && same(str + tab[i].name, want))
				return bias + tab[i].value;
		return 1;
	}
	if (gnu) {
		/* buckets, first symbol, words of the filter, then the filter,
		 * the buckets and a chain whose last entry of a bucket is odd */
		const unsigned *bucket = gnu + 4 + 2 * gnu[2], *chain = bucket + gnu[0];

		for (n = 0; n < gnu[0]; n++) {
			i = bucket[n];
			if (i < gnu[1])
				continue;
			for (;; i++) {
				if (tab[i].shndx && same(str + tab[i].name, want))
					return bias + tab[i].value;
				if (chain[i - gnu[1]] & 1)
					break;
			}
		}
	}
	return 1;
}

/* the clock that only goes forward, in nanoseconds since a moment that
 * is the same for the whole run */
long rt_clock(struct rt *rt)
{
	long t[2];

	if (!rt->clock)
		rt->clock = vdso(rt);
	if (rt->clock == 1 || ((long (*)(long, long *))rt->clock)(1, t))
		sys2(SYS_clock_gettime, 1, t);
	return t[0] * 1000000000 + t[1];
}

/* wait that many nanoseconds: 0, or the error of a wait that a signal
 * ended early */
long rt_sleep(struct rt *rt, unsigned long ns)
{
	long t[2];

	(void)rt;
	t[0] = ns / 1000000000;
	t[1] = ns % 1000000000;
	return sys2(SYS_nanosleep, t, 0);
}

/* Sleep while the four bytes at p are v, until a wake of p or for ns
 * nanoseconds at most, -1 for no limit: 0 after a wake, -11 if the
 * bytes were another value, -110 after the time, -4 after a signal. A
 * caller looks at the bytes again whatever comes back. */
long rt_wait(struct rt *rt, unsigned *p, unsigned long v, long ns)
{
	long t[2];

	(void)rt;
	if (ns < 0)
		return sys4(SYS_futex, p, 128, v, 0);
	t[0] = ns / 1000000000;
	t[1] = ns % 1000000000;
	return sys4(SYS_futex, p, 128, v, t);
}

/* wake up to n threads that sleep in a wait of p: how many were woken */
long rt_wake(struct rt *rt, unsigned *p, unsigned long n)
{
	(void)rt;
	return sys3(SYS_futex, p, 129, n);
}

/* the processors this process may run on; 1 if the kernel does not say */
long rt_cpus(struct rt *rt)
{
	unsigned char m[128];
	long r, c = 0;

	(void)rt;
	r = sys3(SYS_sched_getaffinity, 0, sizeof m, m);
	if (r <= 0 || r > (long)sizeof m)
		return 1;
	while (r--)
		for (; m[r]; m[r] &= m[r] - 1)
			c++;
	return c ? c : 1;
}

/* A poller tells which of the descriptors it watches may be read or
 * written without waiting; on Linux it is an epoll object, which says
 * so once for each time a descriptor becomes ready. */
struct event {
	unsigned what;
	unsigned long tag;
} __attribute__((packed));

long rt_poller(struct rt *rt)
{
	(void)rt;
	return sys1(SYS_epoll_create1, 0x80000);
}

/* watch fd for reading (what 1), writing (2) or both, and make it a
 * descriptor that does not wait; tag comes back with its events. -1
 * for a descriptor that is always ready, a plain file. */
long rt_watch(struct rt *rt, long ep, long fd, long what, unsigned long tag)
{
	struct event e;
	long f;

	(void)rt;
	f = sys2(SYS_fcntl, fd, 3);
	if (f < 0)
		return f;
	if (!(f & 0x800))
		sys3(SYS_fcntl, fd, 4, f | 0x800);
	e.what = 0x80000000u | (what & 1 ? 0x2001 : 0) | (what & 2 ? 4 : 0);
	e.tag = tag;
	return sys4(SYS_epoll_ctl, ep, 1, fd, &e);
}

long rt_unwatch(struct rt *rt, long ep, long fd)
{
	(void)rt;
	return sys4(SYS_epoll_ctl, ep, 2, fd, 0);
}

/* wait at most ms milliseconds, -1 for no limit, for up to max events,
 * at most 64, and write each as 16 bytes at out: 1 for may be read, 2
 * for may be written or their sum, an error or a closed end counting as
 * both, and the tag. How many there are, or an error. */
long rt_poll(struct rt *rt, long ep, unsigned long *out, unsigned long max, long ms)
{
	struct event e[64];
	long r, i;

	(void)rt;
	r = sys4(SYS_epoll_wait, ep, e, max > 64 ? 64 : max, ms);
	for (i = 0; i < r; i++) {
		out[2 * i] = (e[i].what & 0x2019 ? 1 : 0) | (e[i].what & 28 ? 2 : 0);
		out[2 * i + 1] = e[i].tag;
	}
	return r;
}

/* a descriptor that a poller watches for reading and that wakeup makes
 * ready, from any thread: what ends a poll that waits */
long rt_waker(struct rt *rt)
{
	(void)rt;
	return sys2(SYS_eventfd2, 0, 0x80800);
}

long rt_wakeup(struct rt *rt, long fd)
{
	unsigned long one = 1;

	(void)rt;
	return sys3(SYS_write, fd, &one, 8);
}

/* the address of a socket of the internet, version 4: the family, the
 * port and the address with their high bytes first, zeros */
static void inet(unsigned char *a, unsigned long ip, unsigned long port)
{
	int i;

	for (i = 0; i < 16; i++)
		a[i] = 0;
	a[0] = 2;
	a[2] = port >> 8;
	a[3] = port;
	a[4] = ip >> 24;
	a[5] = ip >> 16;
	a[6] = ip >> 8;
	a[7] = ip;
}

/* a socket that listens on the port of the address, 0 for every address
 * of the machine and port 0 for one the kernel chooses, that does not
 * wait and may take the port of a socket just closed: the descriptor */
long rt_listen(struct rt *rt, unsigned long ip, unsigned long port, long backlog)
{
	unsigned char a[16];
	int one = 1;
	long fd, r;

	(void)rt;
	fd = sys3(SYS_socket, 2, 0x80801, 0);
	if (fd < 0)
		return fd;
	sys5(SYS_setsockopt, fd, 1, 2, &one, 4);
	inet(a, ip, port);
	r = sys3(SYS_bind, fd, a, 16);
	if (!r)
		r = sys2(SYS_listen, fd, backlog);
	if (r) {
		sys1(SYS_close, fd);
		return r;
	}
	return fd;
}

/* the next connection to a socket that listens, as a descriptor that
 * does not wait; -11 if there is none now */
long rt_accept(struct rt *rt, long fd)
{
	(void)rt;
	return sys4(SYS_accept4, fd, 0, 0, 0x80800);
}

/* a socket for a stream, which does not wait */
long rt_socket(struct rt *rt)
{
	(void)rt;
	return sys3(SYS_socket, 2, 0x80801, 0);
}

/* connect it: 0, or -115 if that goes on, after which the socket may be
 * written when it is done and sockerr says how it ended */
long rt_connect(struct rt *rt, long fd, unsigned long ip, unsigned long port)
{
	unsigned char a[16];

	(void)rt;
	inet(a, ip, port);
	return sys3(SYS_connect, fd, a, 16);
}

/* the error that a socket has to report, as a negative number, or 0 */
long rt_sockerr(struct rt *rt, long fd)
{
	int v = 0, n = 4;
	long r;

	(void)rt;
	r = sys5(SYS_getsockopt, fd, 1, 4, &v, &n);
	return r ? r : -(long)v;
}

/* the port of a socket */
long rt_port(struct rt *rt, long fd)
{
	unsigned char a[16];
	int n = 16;
	long r;

	(void)rt;
	r = sys3(SYS_getsockname, fd, a, &n);
	return r ? r : a[2] << 8 | a[3];
}

/* write to a socket; the error -32 if the other end is closed, without
 * the signal, and -88 for a descriptor that is no socket */
long rt_send(struct rt *rt, long fd, const void *p, unsigned long n)
{
	(void)rt;
	return sys6(SYS_sendto, fd, (long)p, n, 0x4000, 0, 0);
}

/* write to a pipe with the error -32 if nobody reads it, without the
 * signal: it is blocked for this thread around the write, and one that
 * the write made is taken back, unless the program had blocked it */
long rt_writeq(struct rt *rt, long fd, const void *p, unsigned long n)
{
	unsigned long set = 4096, old = 0;
	long t[2] = { 0, 0 }, r;

	(void)rt;
	sys4(SYS_rt_sigprocmask, 0, &set, &old, 8);
	r = sys3(SYS_write, fd, p, n);
	if (r == -32 && !(old & 4096))
		sys4(SYS_rt_sigtimedwait, &set, 0, t, 8);
	sys4(SYS_rt_sigprocmask, 2, &old, 0, 8);
	return r;
}

/* in a child: end it, as a program that cannot be started ends */
static void fail(void)
{
	for (;;)
		sys1(SYS_exit, 127);
}

/* in a child: make the three descriptors given its 0, 1 and 2, or end
 * it; -1 is one to leave. One that is 0, 1 or 2 itself must be read
 * before another is put on its number, so each round puts in place
 * those whose number no other still reads. When none is left to do so
 * they read one another in a ring, and only then one of them is copied
 * to a number from 3 up, which is closed when the program starts. */
static void place(long *m)
{
	long i, j, n, d, b;

	for (i = 0; i < 3; i++)
		if (m[i] == i)
			m[i] = -1;
	for (;;) {
		n = d = 0;
		for (i = 0; i < 3; i++) {
			if (m[i] == -1)
				continue;
			n++;
			b = 0;
			for (j = 0; j < 3; j++)
				if (m[j] == i)
					b = 1;
			if (b)
				continue;
			if (sys2(SYS_dup2, m[i], i) < 0)
				fail();
			m[i] = -1;
			d = 1;
		}
		if (!n)
			return;
		if (d)
			continue;
		for (i = 0; m[i] == -1; i++)
			;
		m[i] = sys3(SYS_fcntl, m[i], 1030, 3);
		if (m[i] < 0)
			fail();
	}
}

/* Start a program as a child process: its number, or an error. argv is
 * the address of the addresses of its arguments, strings with a zero at
 * the end, with a 0 after the last; the first is the program, a path if
 * it has a slash and else a name looked for in the directories of PATH.
 * env is its environment in the same form, 0 for that of this process;
 * fds the address of three descriptors that become its 0, 1 and 2, -1
 * for the one of this process. With the flag 1 the child is held: the
 * kernel kills it when the thread that started it ends. A program that
 * cannot be started is a child that ends with status 127. */
long rt_start(struct rt *rt, char **argv, char **env, long *fds, long flags)
{
	char z[4096];
	long m[3], me = 0, pid, i, n, d;
	const char *path = "/usr/bin:/bin", *q;
	char **own = (char **)(rt->sp + 16 + 8 * *(long *)rt->sp), **e;

	if (!env)
		env = own;
	if (flags & 1)
		me = sys1(SYS_getpid, 0);
	pid = sys1(SYS_fork, 0);
	if (pid)
		return pid;
	if (flags & 1) {
		/* a kernel that refuses would leave a child nothing holds; a
		 * parent that ended before that line sends nothing */
		if (sys5(SYS_prctl, 1, 9, 0, 0, 0) || sys1(SYS_getppid, 0) != me)
			fail();
	}
	for (i = 0; i < 3; i++) {
		m[i] = fds[i];
		/* asked of all three before any copy is made, since a copy may
		 * take the number of a descriptor that was not open */
		if (m[i] != -1 && sys2(SYS_fcntl, m[i], 1) < 0)
			fail();
	}
	place(m);
	for (n = 0; argv[0][n]; n++)
		if (argv[0][n] == '/') {
			sys3(SYS_execve, argv[0], argv, env);
			fail();
		}
	for (e = own; *e; e++)
		if ((*e)[0] == 'P' && (*e)[1] == 'A' && (*e)[2] == 'T' && (*e)[3] == 'H' && (*e)[4] == '=')
			path = *e + 5;
	/* each directory of the list, an empty one being this directory */
	for (;;) {
		for (q = path; *q && *q != ':'; q++)
			;
		d = q - path;
		if (d + n < 4094) {
			for (i = 0; i < d; i++)
				z[i] = path[i];
			if (d)
				z[d++] = '/';
			for (i = 0; i <= n; i++)
				z[d + i] = argv[0][i];
			sys3(SYS_execve, z, argv, env);
		}
		if (!*q)
			fail();
		path = q + 1;
	}
}

/* Wait for the child to end and take it from the kernel: its exit
 * status, 0 to 255; or the signal that ended it, negated; or -1000 if
 * it still ran after ms milliseconds, in which case it was killed and
 * taken; or -1001 if there is no such child. ms 0 waits without limit. */
long rt_reap(struct rt *rt, long pid, unsigned long ms)
{
	int st = 0;
	long r, fd, t;
	struct {
		int fd;
		short want, got;
	} pf;

	if (ms) {
		fd = sys2(SYS_pidfd_open, pid, 0);
		if (fd >= 0) {
			pf.fd = fd;
			pf.want = 1;
			pf.got = 0;
			do
				r = sys3(SYS_poll, &pf, 1, ms);
			while (r == -4);
			sys1(SYS_close, fd);
			if (!r)
				goto late;
		} else {
			/* no descriptor to be had for the child: ask every
			 * millisecond whether it has ended */
			t = rt_clock(rt);
			for (;;) {
				st = 0;
				r = sys4(SYS_wait4, pid, &st, 1, 0);
				if (r == -4)
					continue;
				if (r)
					goto took;
				if ((unsigned long)(rt_clock(rt) - t) / 1000000 >= ms)
					goto late;
				rt_sleep(rt, 1000000);
			}
		}
	}
	do {
		st = 0;
		r = sys4(SYS_wait4, pid, &st, 0, 0);
	} while (r == -4);
took:
	if (r < 0)
		return -1001;
	if (st & 127)
		return -(long)(st & 127);
	return st >> 8 & 255;
late:
	sys2(SYS_kill, pid, 9);
	while (sys4(SYS_wait4, pid, 0, 0, 0) == -4)
		;
	return -1000;
}

/* Let this thread, and the children it starts from now on, run only on
 * the processor cpu, or on the lowest one it may run on if that is not
 * among them: the processor it is now bound to, or an error. */
long rt_pin(struct rt *rt, unsigned long cpu)
{
	unsigned char m[128];
	unsigned long i;
	long r;

	(void)rt;
	for (i = 0; i < sizeof m; i++)
		m[i] = 0;
	r = sys3(SYS_sched_getaffinity, 0, sizeof m, m);
	if (r < 0)
		return r;
	if (cpu >= 1024 || !(m[cpu / 8] >> (cpu & 7) & 1)) {
		for (cpu = 0; cpu < 1024 && !(m[cpu / 8] >> (cpu & 7) & 1); cpu++)
			;
		if (cpu == 1024)
			return -RT_EINVAL;
	}
	for (i = 0; i < sizeof m; i++)
		m[i] = 0;
	m[cpu / 8] = 1 << (cpu & 7);
	r = sys3(SYS_sched_setaffinity, 0, sizeof m, m);
	return r < 0 ? r : (long)cpu;
}

/* The runtime of AIL for x86-64 Linux: what docs/runtime.md calls the
 * services, as C functions. Each takes the state of the runtime first
 * and then the values of the statement, and returns one or two results.
 * The file is compiled without a C library into an image that has no
 * writable byte of its own: all that the runtime keeps is in the state. */
#ifndef AIL_RT_H
#define AIL_RT_H

/* the bytes of state, which the header of the image names */
#define RT_STATE 16

#ifndef __ASSEMBLER__

/* the state: bytes the compiler reserves, zero at the start */
struct rt {
	long sp;	/* the stack at the start: argc, the arguments, the environment */
	long clock;	/* clock_gettime of the kernel's page of code, 1 if it has none, 0 before the first use */
};

/* two results: the first in rax, the second in rdx, which the entry
 * moves to the register of the second result of AIL */
struct rt2 {
	long a, b;
};

/* error codes: the numbers of Linux, negative */
#define RT_EINVAL 22
#define RT_ENAMETOOLONG 36

long rt_exit(struct rt *rt, long code);
long rt_args(struct rt *rt);
long rt_alloc(struct rt *rt, unsigned long n);
long rt_free(struct rt *rt, unsigned long p);
long rt_open(struct rt *rt, const char *path, unsigned long n, long flags, long mode);
long rt_close(struct rt *rt, long fd);
long rt_read(struct rt *rt, long fd, void *p, unsigned long n);
long rt_write(struct rt *rt, long fd, const void *p, unsigned long n);
long rt_pipeerr(struct rt *rt);
long rt_mkdir(struct rt *rt, const char *path, unsigned long n, long mode);
long rt_unlink(struct rt *rt, const char *path, unsigned long n);
long rt_rmdir(struct rt *rt, const char *path, unsigned long n);
long rt_rename(struct rt *rt, const char *path, unsigned long n, const char *to, unsigned long m);
long rt_names(struct rt *rt, long fd, char *p, unsigned long n);
long rt_clock(struct rt *rt);
long rt_sleep(struct rt *rt, unsigned long ns);
long rt_wait(struct rt *rt, unsigned *p, unsigned long v, long ns);
long rt_wake(struct rt *rt, unsigned *p, unsigned long n);
long rt_cpus(struct rt *rt);
long rt_poller(struct rt *rt);
long rt_watch(struct rt *rt, long ep, long fd, long what, unsigned long tag);
long rt_unwatch(struct rt *rt, long ep, long fd);
long rt_poll(struct rt *rt, long ep, unsigned long *out, unsigned long max, long ms);
long rt_waker(struct rt *rt);
long rt_wakeup(struct rt *rt, long fd);
long rt_listen(struct rt *rt, unsigned long ip, unsigned long port, long backlog);
long rt_accept(struct rt *rt, long fd);
long rt_socket(struct rt *rt);
long rt_connect(struct rt *rt, long fd, unsigned long ip, unsigned long port);
long rt_sockerr(struct rt *rt, long fd);
long rt_port(struct rt *rt, long fd);
long rt_send(struct rt *rt, long fd, const void *p, unsigned long n);
long rt_writeq(struct rt *rt, long fd, const void *p, unsigned long n);

#endif
#endif

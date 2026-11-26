/* The runtime of AIL for x86-64 Linux: what docs/runtime.md calls the
 * services, as C functions. Each takes the state of the runtime first
 * and then the values of the statement, and returns one or two results.
 * The file is compiled without a C library into an image that has no
 * writable byte of its own: all that the runtime keeps is in the state. */
#ifndef AIL_RT_H
#define AIL_RT_H

/* the bytes of state, which the header of the image names */
#define RT_STATE 8

#ifndef __ASSEMBLER__

/* the state: bytes the compiler reserves, zero at the start */
struct rt {
	long sp;	/* the stack at the start: argc, the arguments, the environment */
};

/* two results: the first in rax, the second in rdx, which the entry
 * moves to the register of the second result of AIL */
struct rt2 {
	long a, b;
};

/* error codes: the numbers of Linux, negative */
#define RT_ENAMETOOLONG 36

long rt_exit(struct rt *rt, long code);
long rt_args(struct rt *rt);
long rt_alloc(struct rt *rt, unsigned long n);
long rt_free(struct rt *rt, unsigned long p);
long rt_open(struct rt *rt, const char *path, unsigned long n, long flags, long mode);
long rt_close(struct rt *rt, long fd);
long rt_read(struct rt *rt, long fd, void *p, unsigned long n);
long rt_write(struct rt *rt, long fd, const void *p, unsigned long n);

#endif
#endif

# The runtime

A program asks its platform for a few things: to start and to end, for
memory, for the bytes of a file, for a thread, a socket, another
program. The runtime is the code that does them, behind names that are
the same on every platform. The compiler compiles it into each
executable and the statement [`rt`](language.md#rt) calls it; `alloc`,
`free`, `args` and the end of a program are calls of it too.
[RUNTIME.md](RUNTIME.md) is the plan this follows. What a program wants
of x86-64 Linux alone it still asks with [`sys`](language.md#sys).

There is one runtime now, for x86-64 Linux, written in AIL:
`rt/linux-x86_64/rt.aiw`. It was written in C first, compiled without a
C library into an image that stood in every executable; the two were
run against the same tests, service by service, before the C one was
removed (2026-11-26).

## Services

A service takes up to five values and gives up to two results. An error
is a negative number larger than -4096, one of those below; any other
result is a value.

| Number | Service | Values | Results |
|---|---|---|---|
| 1 | `exit` | status | none: the process ends, with every thread |
| 2 | `args` | | the address of the number of arguments; behind it the address of each argument, a zero, the address of each string of the environment, a zero. Each ends with a NUL |
| 3 | `alloc` | size | the address of that many bytes of zeros, a multiple of 16, or 0. Threads that `thread` started may call it and `free` at the same time |
| 4 | `free` | address | none. The address is one `alloc` gave, or 0, which does nothing |
| 5 | `open` | address and length of a path, flags, mode | a descriptor, or an error |
| 6 | `close` | descriptor | 0, or an error |
| 7 | `read` | descriptor, address, size | the bytes read, at most the size and 0 at the end, or an error |
| 8 | `write` | descriptor, address, size | the bytes written, at most the size, or an error |
| 9 | `pipeerr` | | 0, or an error. From now on a `write` to a pipe or a socket whose other end is closed gives the error -32; until it is called such a write ends the process on Linux. It holds for the programs the process starts too |
| 10 | `mkdir` | address and length of a path, mode | 0, or an error (-17 if it is there) |
| 11 | `unlink` | address and length of a path | 0, or an error: the file is removed |
| 12 | `rmdir` | address and length of a path | 0, or an error (-39 if it is not empty): the empty directory is removed |
| 13 | `rename` | address and length of a path, and of another | 0, or an error: the file has the second path, in place of a file that had it |
| 14 | `names` | descriptor of a directory, address, size | the bytes written, 0 after the last name, or an error (-22 for a size below 512): the next names of the directory, each with a NUL behind it, none of them `.` or `..` |
| 15 | `clock` |  | nanoseconds of the clock that only goes forward, since a moment that is the same for the whole run |
| 16 | `sleep` | nanoseconds | 0, or the error -4 of a wait that ended early |
| 17 | `wait` | address, value, nanoseconds or -1 | 0 after a `wake` of the address, -11 if the four bytes there were not the value, -110 after the time, -4 after a signal: the thread sleeps while the four bytes at the address are the value, and looks again whatever comes back |
| 18 | `wake` | address, number | how many threads that sleep in a `wait` of the address were woken, at most the number |
| 19 | `cpus` |  | the processors the process may run on, at least 1 |
| 20 | `thread` | address of a function, value | 0, or an error: a thread calls the function with the value and ends when it returns. Its stack is 8 MiB with a closed page under it, so a function that needs more faults |
| 21 | `poller` |  | a poller, which tells which of the descriptors it watches may be read or written without waiting, or an error. It is closed with `close` |
| 22 | `watch` | poller, descriptor, 1 to read, 2 to write or 3, tag | 0, or an error; -1 for a descriptor that is always ready, a plain file. The descriptor no longer waits from then on: a `read` or `write` that cannot go on gives -11, and the poller says once when it can |
| 23 | `unwatch` | poller, descriptor | 0, or an error |
| 24 | `poll` | poller, address, most events (up to 64), milliseconds or -1 | the number of events written at the address, 16 bytes each: 1 for may be read, 2 for may be written or 3, an error or a closed end counting as both, and the tag of the descriptor. 0 after the time, or an error |
| 25 | `waker` |  | a descriptor that a poller watches to read and that `wakeup` makes ready from any thread, or an error |
| 26 | `wakeup` | waker | 8, or an error |
| 27 | `listen` | IPv4 address as a number (0 for every address), port (0 for any), most connections that wait | a socket that listens and does not wait, or an error |
| 28 | `accept` | socket that listens | the next connection, a socket that does not wait; -11 if there is none now |
| 29 | `socket` |  | a socket for a stream that does not wait, or an error |
| 30 | `connect` | socket, IPv4 address, port | 0, or -115 while it goes on: the socket may be written when it is done and `sockerr` says how it ended |
| 31 | `sockerr` | socket | 0, or the error the socket has to report |
| 32 | `port` | socket | its port, or an error |
| 33 | `send` | socket, address, size | the bytes written, or an error: -32 if the other end is closed, -88 for a descriptor that is no socket |
| 34 | `writeq` | descriptor, address, size | the bytes written, or an error: a `write` that gives -32 for a pipe nobody reads without ending the process, whether `pipeerr` was called or not |
| 35 | `start` | address of the arguments, address of an environment or 0 for that of the process, address of three descriptors, flags | the number of a child process, or an error. The arguments and the environment are addresses of strings that end with a NUL, with a 0 after the last; the first argument is the program, a path if it has a slash and else a name looked for in the directories of `PATH`. The three descriptors, 8 bytes each, become its 0, 1 and 2, -1 for the one of the process. With the flag 1 the child is killed when the thread that started it ends. A program that cannot be started is a child that ends with 127 |
| 36 | `reap` | child, milliseconds or 0 for no limit | its exit status, 0 to 255; the signal that ended it, negated; -1000 if it still ran after the time, and was killed; -1001 if there is no such child |
| 37 | `pin` | processor | the processor the thread and the programs it starts are bound to from now on, that one or the lowest it may run on, or an error |

The descriptors 0, 1 and 2 are the input, the output and the error
output the process was started with. A path is its bytes, at most 4095,
with no NUL behind them. The flags of `open` are a sum of 0 to read, 1 to
write or 2 for both, 64 to make the file if it is not there (with the
mode, the bits of its permissions), 512 to cut it to no bytes, 1024 to
write at its end, 0x10000 for a directory, whose names `names` gives,
and 0x80000 to close it in a program the process starts. `read` and `write` may do less than they were asked, and a
caller that wants all asks again.

The errors that a caller may tell apart, with the numbers Linux gives
them; a runtime for another platform gives the same numbers:

| Number | Meaning |
|---|---|
| -2 | no such file |
| -4 | interrupted: ask again |
| -9 | no such descriptor |
| -11 | nothing now, for a descriptor that does not wait |
| -12 | no memory |
| -13 | not allowed |
| -17 | the file is there |
| -28 | no room left |
| -32 | the other end is closed |
| -22 | a value that the service does not take |
| -36 | the path is too long |
| -88 | not a socket |
| -98 | the port is taken |
| -104 | the other end broke the connection |
| -110 | the time is over |
| -111 | nobody listens there |
| -115 | it goes on |
| -39 | the directory is not empty |

## Memory on Linux

A block has 16 bytes before its address, which say what it is. Up to 32
KiB with those 16 it is one of 39 sizes, four for each doubling above 128
bytes, cut from chunks of 256 KiB that are mapped as they are needed and
never given back. `free` puts such a block first in the list of its size,
and `alloc` takes the first of the list, clears it, and only cuts a new
block when the list is empty; what is cut from a chunk is zeros already.
A larger block is a mapping of its own, which `free` gives back to the
kernel. The lists are in the state and are locked, by a few instructions
that spin, only once `thread` has started a thread. On the program
`allocs` of ail-bench, 200000 blocks of 16 to 1039 bytes with 64 alive,
this takes 0.99 of the time of `calloc` and `free` of the C library; a
mapping for every block took 79 times as long.

## How the runtime is part of a program

`rt/linux-x86_64/rt.aiw` is AIL source that the compiler has as data
(`build/rt/linux-x86_64/source.aiw`, written by `rt/source.sh` without its comments)
and compiles in front of every program, as if the program began with
it. A function `rt_<name>` there is the service `name`: it takes the
values of the service and returns its results, and a statement that
calls the service is a call of that function, with all that a call has:
values in `rax`, `rdi`, `rsi`, `rdx` and `r10`, results in `rax` and
`rdi`, the registers of the variables kept. In a function, a short
service is compiled in place of its call, so `rt write` in a function
is the system call and nothing around it.

`state.aiw` is compiled behind the program and declares what the
runtime keeps, the buffer `rt_state`, so that its bytes are behind the
buffers of the program. The table `rtnames` of the compiler says for
each service whether it has anything there; a program that calls no
such service has no bytes of state, and one that keeps nothing in
memory has no writable segment.

The first line of `rt.aiw` is the first that a process runs: `stack
rt_state` keeps the stack the process starts with, which is what
`args` gives. In a program that calls no service that reads it, the
compiler makes the line do nothing. The second line jumps past every
function of the runtime to the program, so a process touches the first
page of that code and the pages of what it calls.

Every name of the two files starts with `rt_`, variables and labels too,
and a program has no name that does: a function of the runtime that is
compiled in place is read where the program's names are known, and `as`
on the name of a `var` of the program would write that `var`.

The statement `stack p` is for that first line: it stores the stack
pointer at the address `p`, and is allowed at top level only.

An executable with the runtime is 11.7 KiB longer than without, all of
its functions being in each. A program starts in the time it took
before there was a runtime, within half a microsecond of 48: started in
turn 3000 times each on one CPU, `hello` took 48.2 and 48.4
microseconds in the median against 47.9 for the one of the revision
before the runtime (the C runtime cost two microseconds). On the
programs of ail-bench that spend their time in the runtime it takes
0.85 (`iocopy`), 0.98 (`iosmall`) and 0.99 (`allocs`) of the time of the
C programs with the C library.

## A new service

A function `rt_<name>` in `rt/linux-x86_64/rt.aiw`, a row in the table
`rtnames` of `compiler/tables.aiw` with a number of its own, its values,
its results and what it needs of the state, a line in the tables here
and in [language.md](language.md#rt), and tests `tests/rt_*`. The
source of the compiler may call it once a seed that has it is pinned.

## Another platform

A directory `rt/<platform>/` with the same two files, written for that
platform, and a compiler that writes code for it; the services, their
values, their results and their errors are those of this page.

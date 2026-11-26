# The runtime

A program asks its platform for a few things: to start and to end, for
memory, for the bytes of a file. The runtime is the code that does them,
behind names that are the same on every platform. The compiler puts it
into each executable and the statement [`rt`](language.md#rt) calls it;
`alloc`, `free`, `args` and the end of a program are calls of it too.
[RUNTIME.md](RUNTIME.md) is the plan this follows. What a program wants
of x86-64 Linux alone it still asks with [`sys`](language.md#sys).

There is one runtime now, for x86-64 Linux, written in C in
`rt/linux-x86_64/`. `make` compiles it with `cc`, without a C library;
`make RT=<file>` takes an image built elsewhere.

## Services

A service takes up to five values and gives up to two results. An error
is a negative number larger than -4096, one of those below; any other
result is a value.

| Entry | Service | Values | Results |
|---|---|---|---|
| 1 | `exit` | status | none: the process ends, with every thread |
| 2 | `args` | | the address of the number of arguments; behind it the address of each argument, a zero, the address of each string of the environment, a zero. Each ends with a NUL |
| 3 | `alloc` | size | the address of that many bytes of zeros, a multiple of 16, or 0 |
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

## How a program calls it

The values are in `rax`, `rdi`, `rsi`, `rdx` and `r10`, as for a call of
a function of the program, and the results come back in `rax` and
`rdi`. `rbx`, `rbp` and `r12` to `r15` are kept; every other register
may change. The stack may stand anywhere: an entry aligns it for the
code it calls.

## The image

The runtime is one run of bytes that may stand at any address and has no
writable byte. The compiler has it as data (`build/rt/image.aiw`,
written by `rt/image.sh`) and copies it behind the header of every
executable; the program follows it.

| Offset | Bytes | |
|---|---|---|
| 0 | 4 | `AILR` |
| 4 | 4 | the version of this form, 1 |
| 8 | 4 | the size of the image, a multiple of 64 |
| 12 | 4 | the bytes of state |
| 16 | 4 | the number of entries |
| 20 | 4 | zeros |
| 24 | 8 | the distance from the start of the image to its state, which the compiler fills in |
| 32 | 4 each | the offset of each entry from the start of the image |

The state is memory of the process that is zero at the start, as many
bytes as the image names, which the compiler reserves behind the buffers
of the program. All that the runtime keeps is there.

The entry 0 is where the process starts: it notes the stack, which on
Linux is what `args` gives, and goes on at the end of the image, the
first statement of the program. Every other entry is a service, with the
number the table above gives it; the compiler knows the services by the
table `rtnames` of `compiler/tables.aiw`, and `tests/tables.sh` holds
the two together.

## A new service

A function in `rt/linux-x86_64/rt.c` with its line in `rt.h`, an entry
at the end of the table and of the entries in `entry.S`, a row in
`rtnames` with the number of that entry, a line in the tables here and
in [language.md](language.md#rt), and tests `tests/rt_*`.

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
| 35 | `start` | address of the arguments, address of an environment or 0 for that of the process, address of three descriptors, flags | the number of a child process, or an error. The arguments and the environment are addresses of strings that end with a NUL, with a 0 after the last; the first argument is the program, a path if it has a slash and else a name looked for in the directories of `PATH`. The three descriptors, 8 bytes each, become its 0, 1 and 2, -1 for the one of the process; one that is given stays open in the child however it was opened. With the flag 1 the child is killed when the thread that started it ends. With the flag 2 it leads a group of processes of its own, which the programs it starts are in unless they leave it: the group is killed when `reap` has taken the child, whatever the child left running, and when the process that started it ends, however that ends. A program that cannot be started is a child that ends with 127 |
| 36 | `reap` | child, milliseconds or 0 for no limit | its exit status, 0 to 255; the signal that ended it, negated; -1000 if it still ran after the time, and was killed; -1001 if there is no such child; the error of the platform if it refuses to end a child whose time is over, which is then left as it is and may be given to `reap` again, unless it has ended meanwhile, which gives what it ended with. Only a child of the process is waited for and killed, never another process that has the number: a number that is not 1 to 2^31-1 is no child, and a child that one thread waits for is no child to another thread meanwhile, so that no `reap` takes it and frees its number during the wait. On Linux that holds against anything that takes children when the wait has a descriptor of the child, as it has on every kernel since 5.4 unless the process is out of descriptors; without one it holds against `reap` alone, so a program that takes children with `sys` must not do so during a `reap` with a time, and where the kernel itself takes the children that end (the process ignores `SIGCHLD`, or set `SA_NOCLDWAIT`), or does not say whether it does (a filter that refuses `rt_sigaction`), a child whose time is over is sent no signal: the error that kept the descriptor away is the result and the child is left. What the process does with `SIGCHLD` is asked once, when the time is over, so a program must not change it during such a `reap` either. The time is all 64 bits |
| 37 | `pin` | processor | the processor the thread and the programs it starts are bound to from now on, that one or the lowest it may run on, or an error |
| 38 | `cwd` | address, size | the length of the path of the directory of the process, which is written there with a NUL behind it that is not counted, or an error: -34 if it does not fit |
| 39 | `chdir` | path | 0, or an error: the directory at the path is the one of the process from now on, for every thread |
| 40 | `real` | path, address, size | the length of the path of the directory as the system names it, from the root and with no link and no `..` in it, written as `cwd` writes one, or an error. On Linux the process goes into the directory and comes back by a descriptor, so a directory that may be entered and not listed has a name too, and a thread that names a file from the directory of the process must not do so meanwhile |
| 41 | `self` | address, size | the length of the path of the executable of the process, which is written there, or an error: -36 if it does not fit |
| 42 | `kind` | path | 1 for a file, 2 for a directory, 3 for a link, which is not followed, 4 for anything else, or an error: -2 if nothing is there |
| 43 | `chmod` | descriptor, mode | 0, or an error: the open file has the mode, whatever the process leaves out of the mode of a file it makes |
| 44 | `pid` |  | a number that no other process has while this one runs |
| 45 | `lock` | path | a descriptor that holds the lock of the directory or file at the path until it is closed or the process ends, or an error. One process at a time has the lock, and the service waits for the one that has it; a program that is started does not get the descriptor, and a process that has the lock must not ask for it again |
| 46 | `become` | address of the arguments, address of an environment or 0 for that of the process | only an error, if the program cannot be started, -2 if it is not there: else the program is there in place of the process, with its descriptors but for those opened to be closed then, and nothing of the process goes on. The arguments and the environment are those of `start`, and the program is found as there |

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

## Windows on x86-64

The second platform, to see whether the services can be had where
nothing is as on Linux: `rt/windows-x86_64/rt.aiw`, and a compiler for
it, `build/ailc-windows-x86_64`, which runs on Linux and writes
executables of Windows (`make build/ailc-windows-x86_64`; `make
build/windows-x86_64/hello.exe` for an example). They are run under
Wine, by `tests/win.sh`.

Windows has no system calls for a program to make. Every service calls
functions of its libraries, whose addresses the loader writes into the
import tables of the executable; `compiler/windows-x86_64/imports.list`
names them, and `imports.sh` makes the tables of that list and tells
the runtime where each address is, as a `const` in front of its source.
A service puts the values of such a function into a `local` and calls
it with [`ccall`](language.md#ccall-and-base), which passes them as
Windows wants them, at the place that [`base`](language.md#ccall-and-base)
and the `const` give.

What differs behind the same services: a descriptor is a number of the
runtime, which keeps the handle of Windows for each of 256 in its
state, 0, 1 and 2 being the input and the outputs it asks Windows for
when they are first used; `args` cuts the one line that Windows has for
the arguments, as its C library does, at its first call; memory comes
from `VirtualAlloc`, in the same blocks; an error of Windows becomes
the number of this page. The statement `sys` is no statement there.

The runtime has every service. The compiler compiled for Windows runs
under Wine and compiles its own source to the file it is. Windows loads
no image above 0x77000000 bytes, the buffers of a program included,
whatever the address it is loaded at, so the compiler for Windows
reports `buffers too big` for a program whose image would be larger.
Wine loads any, so `tests/win.sh` reads the size of the image of the
compiler in its header, and that of a program whose buffers end at
that size. Of the tests
that have no `sys`, 579 give their output and status there, the tasks,
the async library with its sockets and the HTTP client and server among
them; 21 are of Linux alone and say why in `tests/win.skip`.

Microsoft Defender takes a program for malware now and then, by its
model and not by a signature: in November 2026 two of the 628 programs
of the tests, `tests/win/stale.aiw` and `tests/rt_open_threads.aiw`
(`Sabsik`, `Wacatac`). The first of them it did not let start; the
same source compiled after the runtime had got one more import
started, and so did the second. Nothing in the
header decides it: one byte changed there, a time of linking for one,
clears a program or does not, by the value of the byte. That is what
one scan recorded, and no rule of what Defender takes. A file it takes
wrongly is submitted to Microsoft, the very file that was flagged
(https://www.microsoft.com/en-us/wdsi/filesubmission). A signature
does not answer the verdict: it says who published a file and that it
is unchanged, and a signed file is taken too; and a directory left out
of the scan is one Defender no longer looks at.

Where a service cannot be on Windows what it is on Linux:

- A directory is opened for its names only, and is no handle of
  Windows: `names` is a search of its path. Names are in the code page
  of the process, not UTF-8.
- A path is too long, -36, from 260 bytes on, counted with the
  directory the process is in, and not from 4096. Windows says of such
  a path that it is not there, so after that answer the runtime asks
  `GetFullPathNameA`, which says that it is too long.
- `wake` does not say how many threads it woke, and gives 0. `wait`
  returns 0 also when the bytes changed while it slept.
- A thread is one of Windows, with a stack that Windows keeps; a
  function that needs more than its 8 MiB ends the process.
- `start` gives the number 1 for a program that cannot be started, and
  `reap` takes it as a child that ended with 127, since there is no
  child to end so, and so is one given a descriptor that is not an open
  file. The program is found by a path with either slash. The child
  gets copies of the three handles, made for it and closed once it is
  started, and a list that names them: it inherits those and no other
  handle of the process. A child that is held ends when the process
  that started it ends, not the thread: it is in a job of Windows from
  the moment it is made, by the same list (Windows 10), and is not
  started where Windows gives no such job. `reap` gives a fault of the child as the signal Linux has
  for it, negated: -11, -8, -4, or -6 for any other.
  A child is a handle there, which is closed when the child is taken
  and which Windows then gives to a later child, so the program never
  has it: `start` gives a number of the runtime, from 2 on, that no
  other child of the process gets, and the runtime keeps a list of the
  children that are not yet taken, each with its number and its
  handle. One `reap` at a time has a child, as on Linux, and a number
  that is not in the list is no child, -1001: the number of a child
  that was taken stays that whatever is started afterwards.
- `clock` is the counter of Windows; `sleep` waits whole milliseconds.
- A poller watches sockets and nothing else: `watch` gives -1 for any
  other descriptor, as for a plain file, and a read of a pipe waits.
  Windows says of a socket whether it is ready and not when it becomes
  so; a poller keeps for each socket it watches what it has said, asks
  Windows about the others, and forgets what it said when a read, a
  write or an accept finds the socket not ready, which is when a caller
  waits for it. Each poller has its own record of what it watches, with
  the tags, so two pollers take nothing from each other, and a socket
  that is closed is watched by none. The record has a lock, which
  `watch`, `unwatch`, `poll` and the forgetting hold while they read
  and change it, and each watch has a number, so what Windows answered
  of a socket counts only for the watch there was when it was asked. A
  poller has a socket of its own, for single messages and connected to
  itself, that every wait of it asks about too. A waker is such a
  socket, and is not asked about: `wakeup` notes it in every poller
  that watches it and sends a byte to the socket of each, so one
  `wakeup` is one event in each of them, and a poller that waits with
  no limit waits until there is an event. A `watch` that another
  thread makes while a poller waits counts from its next wait on.
- A descriptor is one of 256, a socket too. Its number is taken with
  one atomic step before Windows is asked for the handle, and given
  back only when a close has finished, so threads that open at once get
  different numbers. A write to a socket takes
  all its bytes where Linux takes part of many.
- `cwd`, `real` and `self` write a path as Windows does, with its
  drive and `\`. `real` is the path made whole by `GetFullPathNameA`,
  without `..`; a link in it stays what it is. `kind` is never 4, and
  3 for whatever Windows keeps as a reparse point. `chmod` has nothing
  to do and gives 0 for a descriptor that is open.
- `lock` is a mutex of Windows named by the path made whole, since
  Windows locks no directory: it keeps out the programs that ask the
  runtime for the lock and nothing else. A mutex belongs to a thread,
  so the thread that took the lock closes it, and a second `lock` of
  the same path by that thread is given at once.
- `become` starts the program as a child that is held, with the input
  and the outputs of the process, waits for it and ends the process
  with its status, or with 128 and the number of what ended it:
  Windows puts no program in the place of another.
- The group of a child started with the flag 2 is a job of Windows of
  its own, which a process it starts cannot leave and of which the
  process that started the child has the only handle: `reap` closes
  it, and Windows does when that process ends. On Linux the group is
  one of the kernel, with a watcher in it, a process that waits for
  the end of a pipe from the process that started the child and then
  kills the group; the child runs only once the watcher is there. The
  watcher keeps no other descriptor, and a program that makes a group
  of its own (`setsid`, `setpgid`) is out of it.
- `pipeerr` has nothing to do: there is no signal.

## Another platform
## Another platform

A directory `rt/<platform>/` with the same two files, written for that
platform, and a compiler that writes code for it; the services, their
values, their results and their errors are those of this page.

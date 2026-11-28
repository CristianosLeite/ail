---
title: Five services for a program that stays inside a directory
last-verified: 2026-11-28
sources: [conversation 2026-11-28, REVIEW.md of 2026-11-28 (a review of c5ed7fb, never part of the repository), docs/TODO.md of aildb (step 19), rt/linux-x86_64/rt.aiw, rt/windows-x86_64/rt.aiw, docs/runtime.md, runs of 2026-11-28 on Windows 11 Pro build 26300 with WSL 2 (Ubuntu, kernel 6.18.33.2)]
status: current
---
# Five services for a program that stays inside a directory

**Summary.** aildb is to run on Windows (user, 2026-11-26), and a
source with `sys` is not compiled for it. Step 19 of its
`docs/TODO.md` named what the runtime still lacked: a file with no
name, a child ended, a thing opened below an open directory with no
link followed, the path of an open descriptor, and the lock of an
open descriptor that is not waited for. They are the services 59 to
63, `anon`, `kill`, `openat`, `fdpath` and `lockfd`, written on
2026-11-28 at the user's word to go on with that list. The user named
what was needed; every name, flag, error and trade below is the
agent's, and waits for the user's review.

## Decisions

- **`anon` has a name on Windows while it is open** (agent,
  2026-11-28). Windows has no file without a name. It is a file of
  the directory for temporary files, made only if nothing has its
  name, 64 bits of `random`, and removed by Windows with its last
  handle (`FILE_FLAG_DELETE_ON_CLOSE`). It is shared with every
  access, since `pwrite` opens a second handle of a file
  (`ReOpenFile`) and Windows refuses that for a file opened for one
  handle alone. Who can open it meanwhile is who can read the
  directory for temporary files of the user; on Linux the same user
  reaches the memory by the number of the process. Rejected: a file
  that is not shared, which `pwrite` and `map` could not be given;
  and a pipe, which has no place to set and takes what a child
  writes only while somebody reads.
- **`kill` ends a child and nothing else** (agent, 2026-11-28). It
  takes a number that `start` gave, not the number of a process: on
  Windows the runtime has a handle only for a child, and on Linux a
  number that is no child may be any process of the user by the time
  the signal goes. The child stays to be taken, so that `reap` is
  still the one place where a number is given up. `reap` gives -9
  for it on both platforms: Windows has no signals, so the child is
  ended with a status of the runtime's own, 0xE0000009, that `reap`
  knows. Rejected: a signal as a value of the service, which Windows
  could not give a meaning; and ending the group of a child that
  leads one, which `reap` already does.
- **`openat` takes one name** (agent, 2026-11-28), not a path below
  the directory. A caller that walks part by part, as aildb does,
  loses nothing, and no part between two others is opened with a
  link followed: Linux has no flag before 5.6 (`openat2`) that
  refuses links on the whole way, and `NtCreateFile` follows a
  reparse point that is not the last part.
- **A link is the error -40 on both platforms** (agent, 2026-11-28).
  Linux says -20 of a link where a directory is asked for, and
  Windows -20 or -21 of a link of the other kind, so after those
  errors the name is asked what it is. The answer may be of another
  thing than the one that was refused, if the name changed between
  the two: only the number of the error depends on it, and nothing
  is opened by it.
- **0x200000 opens a thing only to be asked what it is** (agent,
  2026-11-28), the `O_PATH` of Linux by its number. aildb asks every
  entry of a directory what it is before it reads one, and opening a
  named pipe or a device to ask would wait or do what the device
  does. A link is then opened as itself, which is how a caller
  learns that an entry is one, unless a directory was asked for: a
  directory that is to be the place of another `openat` is never a
  link.
- **64 with 0x10000 makes a directory** (agent, 2026-11-28), in place
  of a service `mkdirat`. Linux makes it and then opens it with no
  link followed, so what took the name between the two is opened
  only if it is a directory and no link; Windows does both in one
  call.
- **A directory opened by `openat` keeps its name on Windows**
  (agent, 2026-11-28): it is opened without leave to remove it or to
  rename it. `names` there searches a path, the one Windows has for
  the handle when it is opened, and a directory that could be renamed
  meanwhile and a junction put at its name would have the names of
  another directory read. `open` of a directory still shares it with
  those that remove it, as before. A program must so close such a
  directory before it removes it, which Linux does not ask.
- **`lockfd` is the lock of `lock`** (agent, 2026-11-28), so that a
  program may hold a file by its descriptor against one that asks by
  its path. It is for a plain file alone: Windows locks no directory,
  and the file `.ail-lock` that `lock` makes in one has a path to be
  looked up, which is what the service is there to avoid. It has no
  counterpart that waits and none that lets go: aildb asks again
  while it waits, and closes the descriptor.
- **The source of the runtime may be 112 KiB** (agent, 2026-11-28):
  the services of Windows passed the 48 KiB the compiler kept for
  them with `openat`.

## The review of c5ed7fb

The user gave the agent a review of the pull request at `c5ed7fb`
(2026-11-28, a file `REVIEW.md` of the repository aildb that is no
part of either repository) and had it answered: five findings, one
commit each. How each is answered is the agent's, for the user to
review.

- **`kill` without a descriptor sends a signal only to a number that
  is sure to be the child's** (review, P1; agent). Linux gives no
  descriptor of a child before 5.3 and when the process has every
  descriptor it may have, and the signal then went to the number
  after a question, with a `reap` of another thread or the kernel
  free to take the child between the two. The question and the
  signal are under the lock of the list of `reap`, and nothing is
  sent for a number that a `reap` of another thread waits for or in
  a process that ignores `SIGCHLD` or has `SA_NOCLDWAIT`: the error
  of `pidfd_open` is the result. Rejected: no way without a
  descriptor at all, which would leave an old kernel without the
  service; and waking the thread that waits in `reap`, which the
  runtime has no way to do.
- **A number that is no descriptor is -9** (review, P2; agent), in
  `openat` and in `lockfd` of Linux, where the kernel takes -100 for
  the directory of the process and reads 32 bits. The other services
  of a descriptor are as they were, which the review did not ask.
- **A descriptor opened only to be asked is noted on Windows**
  (review, P2; agent), where the handle is an ordinary one that may
  do little. It is the directory of another `openat` whether 0x10000
  was asked or not, a directory to be made is made, and it has no
  record of names. The review offered this or a narrower contract
  on both platforms; the agent took the first, and made what else
  such a descriptor answers the same as on Linux, -9 for a read, a
  write, a lock and its names, which was -13 for a read before.
- **0x800000 of `openat`: a file that keeps its name while it is
  open** (review, P2, for aildb; agent). A file is shared with those
  that remove or rename it, so the file of a lock taken by `lockfd`
  could be renamed and a second one locked under its name; aildb
  asks that the file of the lock of an index is not removed while
  the lock is held on Windows. The flag is of the open, since that
  is where Windows decides it, and holds from the open on, also
  while a program waits for the lock. On Linux it does nothing, and
  is taken out of what the kernel gets: no file keeps its name
  there, and a program for both platforms does not count on it.
  Rejected: a second handle that `lockfd` takes, which holds the
  name only once the lock is had; a service that opens and locks in
  one, a second way to open below a directory; and no sharing with
  those that remove a file for every `openat`, which would change
  what a program may do with a file it has open.
- **`fdpath` asks the path what is at it** (review, P3; agent). The
  kernel says the name a file was opened by with ` (deleted)` behind
  it once that name is removed, though the file has another, so the
  count of its names did not tell. The path is -2 unless the file of
  the descriptor is at it, by device and number, which also lets a
  file be named `x (deleted)`. Rejected: looking for the mark in the
  string, which such a name would be taken for.

The review also said of `sync` of a directory on Windows that its
success shows a request that Windows took and no more, which is
what this page says below.

## What is not known

- Wine: this machine has none. `openat` asks `ntdll.dll` for
  `NtCreateFile` and `RtlNtStatusToDosError`, and `tests/win/link.aiw`
  has `cmd` make a junction, which the test skips where none is
  made.
- `reap` by the number of a child, the way for a Linux before 5.4,
  was not run: the kernel here is 6.18. `kill` by the number is run
  by `rt_kill_nofd`, which takes the descriptors away; a `kill`
  while another thread waits in `reap` for the same child has no
  test, since nothing holds the two still.
- Whether a relative open from a handle that is on a junction itself
  stays in the junction: `openat` refuses a junction as a directory,
  so nothing depends on it.
- File systems other than NTFS and the share of WSL, and a Windows
  older than build 26300.
- What is on the device after `sync` of a directory on Windows.
  Windows answered the flush with success on NTFS; its documents say
  what the call does for a file and a volume, and no loss of power
  was tried.

## Runs

- 2026-11-28, at `2751fe7`, the five fixes after the review of
  `c5ed7fb` on `main` with the pull request 43 merged into the
  branch, Ubuntu under WSL 2: `make test` status 0, 3164 lines of ok.
- The same day and revision, `tests/win.sh all` with the tree on
  NTFS and the programs started on Windows 11 itself: status 0,
  `win_tests (616 run)` and fifteen named checks, `win_stale_watch`
  among them: `stale.exe` was started and ended as the test asks.
  It is the first run of that test at a head of this branch that
  Microsoft Defender did not stop; the runtime has other bytes than
  at `63bec88` and the header those of the pull request 43, and
  which of the two it comes with is not known.

- 2026-11-28, at `63bec88`, Ubuntu under WSL 2: `make test` status
  0, 3156 lines of ok.
- The same day and revision, `tests/win.sh all` with the tree on
  NTFS and the programs started on Windows 11 itself
  ([page](../testing/windows-itself.md)): `win_tests (614 run)` and
  thirteen named checks passed, `win_openat_link` among them, and
  one failed, `win_stale_watch`: Microsoft Defender took
  `stale.exe` for `Trojan:Win32/Sabsik.EN.D!ml` and Windows did not
  start it (the status 126 of the shell), as `docs/runtime.md` tells
  of November 2026. At `ba98976`, without the change of `sync`, the
  same; between the two, with a runtime that had other bytes, the
  same source started and ended with 3. The test was so not run at
  the head of the branch on this machine.
- The same day, `tests/win/stale.aiw` unchanged and compiled by the
  compiler for Windows of each commit from `c286a5b` to the head, the
  program started on Windows 11 in a directory of NTFS (the user's
  way to find what an alert comes with, 2026-11-28: the test stays
  as it is and the builds of a branch are compared by commit): it
  ended with 3 for every commit up to `1333ad1`, `fdpath`, a file of
  61440 bytes, and was not started, 126, from `ba98976` on, `lockfd`,
  the first with a file of 65536 bytes. That commit adds one
  function to the runtime of Windows, 38 lines that call
  `GetFileType` and `LockFileEx`, both imported before, and no
  import. Nothing was changed for it. The user compiled the same
  source with the compiler at hand that day and had it accepted and
  ended with 3; which revision that compiler was is not noted here.

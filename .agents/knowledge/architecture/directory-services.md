---
title: Five services for a program that stays inside a directory
last-verified: 2026-11-28
sources: [conversation 2026-11-28, docs/TODO.md of aildb (step 19), rt/linux-x86_64/rt.aiw, rt/windows-x86_64/rt.aiw, docs/runtime.md, runs of 2026-11-28 on Windows 11 Pro build 26300 with WSL 2 (Ubuntu, kernel 6.18.33.2)]
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

## What is not known

- Wine: this machine has none. `openat` asks `ntdll.dll` for
  `NtCreateFile` and `RtlNtStatusToDosError`, and `tests/win/link.aiw`
  has `cmd` make a junction, which the test skips where none is
  made.
- `kill` and `reap` by the number of a child, the way for a Linux
  before 5.4, were not run: the kernel here is 6.18.
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

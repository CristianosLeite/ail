---
title: The tests of Windows run on Windows itself
last-verified: 2026-11-28
sources: [conversation 2026-11-27, tests/win.sh, runs of 2026-11-27 on Windows 11 Pro build 26300 with WSL 2 (Ubuntu, kernel 6.18.33.2), an Intel Core i7-12700H]
status: current
---
# The tests of Windows run on Windows itself

**Summary.** `tests/win.sh` runs what the compiler for Windows writes
under Wine. On a machine with Windows and WSL 2 the same script runs
the programs on Windows itself, with a script named `wine` that
starts its first argument. On 2026-11-27 it passed so, every check
and 607 tests, with the tree on NTFS.

## How it is run
- WSL starts a file of Windows that a shell of Linux names, if the
  file may be executed. So `wine` is two lines in a directory that is
  first in `PATH`: `chmod +x "$1"` and `exec "$@"`. Nothing of
  `tests/win.sh` changes, and the compilers run on Linux as ever.
- **The tree is on NTFS** (a directory under `/mnt/c`), copied there
  with its `build/`. With the tree in the file system of Linux a
  program of Windows sees it as a share (`\\wsl.localhost\...`), and
  four tests failed there that pass on NTFS: `rt_fstat_dir`,
  `rt_lock`, `rt_pwrite_threads`, and a rename onto a file that is
  mapped (`rt_map_replace`). The directory of the process is then a
  path of a share too, with no letter of a drive.
- WSL gives a program the bare name of its file as its first
  argument, not the path it was started by. A test that opens its own
  file asks `rt self` (`rt_open_threads` did not, and was the one
  test that failed on NTFS until it did).

## What was run
- `tests/win.sh all` at `1a6f5f4`, the tree on NTFS: status 0, the
  twelve named checks and `win_tests (607 run)`. The compiler for
  Windows compiled its own source there to the file it is.
- The same at `v0.2.2` with the tree on the share: 601 run, four
  failed, three of those named above and `rt_open_threads`.

- `tests/win.sh all` at `63bec88` on 2026-11-28, the tree on NTFS:
  `win_tests (614 run)` and thirteen named checks passed, and
  `win_stale_watch` failed, its program not started: Microsoft
  Defender took it (`Trojan:Win32/Sabsik.EN.D!ml`). The status of the
  script was 1 for that.
- **Microsoft Defender takes some of the programs that are compiled**
  (2026-11-28, Windows 11 Pro build 26300). Its list of that day has
  `Trojan:Win32/Sabsik.EN.D!ml` for three test programs between 08:36
  and 08:59 and `Trojan:Win32/Wacatac.C!ml` at 17:34 for `rt_access.exe`
  in the directory of a review's own run; the file was removed each
  time. Both names end in `!ml`, a verdict of a model and not a
  signature. The bytes of those programs were not looked at. The
  agent only read the list: an exclusion, a file restored or a sample
  sent to Microsoft is the user's to decide, and no program is
  changed to pass. Not known: whether `ail.exe`, `ailc.exe` and
  `indent.exe` of the archive for Windows of a release are taken.

## What is not known from it
- Wine: this machine has none, so the services added on 2026-11-27
  (`time`, `random`, `platform`, `trylock`, `map`, `unmap`) were not
  run under it. `random` imports `bcryptprimitives.dll`, which an old
  Wine may not have.
- An older Windows. Build 26300 lets a mapped file be removed and
  replaced by a rename; `docs/runtime.md` says so with that build.
- The tests of faults (`tests/win.skip`) are left out as before.

---
title: Async runtime
last-verified: 2026-11-20
sources: [PR #4, PR #5, conversation 2026-11-20, lib/async/, docs/language.md, docs/performance.md, docs/tokens.md]
status: current
---
# Async runtime

**Summary.** `async fn` and `await` compile to tasks that one thread polls; the runtime is the
library `lib/async/` (task, time, io, pool, chan), written in AIL with no support in the compiler
beyond the two statements. Futures are eager, cancellation is cooperative, and there is no
scheduler on several threads.

## Facts
- A task is a heap record: 64 bytes of the library, then the variables and locals of the
  function, addressed through `rbx`. No task has a stack; a task leaves and enters only at an
  `await`, a statement boundary.
- `await` has two forms, told apart by its first word: a variable or global name (or a number
  or expression) is a handle; any other name is a function, called and awaited in one statement
  (`await asyncread c b 512 as n`).
- The compiler calls the program's functions `async` and `await` by name, as `spawn` and `join`
  are called (`IS_LIB`), so a program must `use "lib/async/task.ai"`. A program without it
  contains nothing of the runtime.
- The files are used in the order task, time, io, pool, chan; pool also needs `lib/task.ai`.
  Syscall numbers the compiler has no name for are `const`s of `lib/async/io.ai`, so the async
  work needed no seed release.
- Cancellation (`asynccancel`, result -125): an event ends at once unless its hook refuses
  (work a pool thread has begun, a limit that must wait for its target). A cancelled task gets
  the real result of what is already done; at an await that would wait it cancels the target,
  waits for it to end, and is then told -125 once, or ended if it was told before.
- A limit (`asynctimeout`) ends with -62; `asynctimeout` of handle 0 is 0.
- Every async write goes through `asyncput`: `sendto` with `MSG_NOSIGNAL` for a socket, the
  signal blocked around `write` and taken back for a pipe. The disposition of `SIGPIPE` of the
  process is never changed.
- `asyncclose` takes the descriptor out of `epoll` (`EPOLL_CTL_DEL`) before closing it: the
  kernel keeps a registration as long as the open file lives, so a `dup` would keep it.
- `asyncsleep` saturates its deadline at 0x7fffffffffffffff ns; such a timer is never due.
- The locals of one function may take 0x7ffff000 bytes at most, a page under 2 GiB, so that
  the 32-bit distance of a local stays positive behind the record header or the stack slots.
- Measured (i7-12700H, medians): a wait is 22 ns, a sleeping task 272 bytes, work handed to
  the pool 1.1 to 3.5 us; the echo server carries what the `epoll` server in C carries (about
  297600 against 295200 round trips a second at 100 connections) in 259 tokens against 503 (245 before the sources were indented).
- The examples are in `bench/async/`, not `examples/`: `tools/bench.sh` expects a C and a Rust
  mirror of every file in `examples/`.

## Why
- **`async fn` is a word, not inferred from `await`:** inference saves one token a function,
  but the first line would no longer say what a call returns, and a plain function could not
  drive tasks with `await` as the top level does.
- **Call and await in one statement:** counted in `docs/tokens.md`, it is the cheapest form
  (124 tokens for the echo program against 144 with a separate `call`).
- **Eager futures:** `async` queues the task at once, so two calls followed by two awaits run
  both meanwhile, with no `join` combinator to learn.
- **All variables of an async function in memory:** a task may move between polls only if
  nothing of it is in a register; keeping in registers the variables that cross no `await` is a
  later optimisation that the measurements did not ask for.
- **A cancelled task waits for what it awaits:** memory it gave to pool work or to another
  task must outlive that work; ending it at once freed records still in use.
- **One thread:** nine tenths of the server's time are the kernel's, and the queue, free
  lists, timer heap and descriptor lists are written without locks. If more processors are
  needed, a thread per core each with its own runtime; `docs/performance.md` has the evaluation.

## How to apply
- New waiting primitive: an event (a task without a poll function) armed with `asyncarm`, a
  hook at 56 that takes it out of its list, ended with `asyncfinish`.
- After touching variable placement in async functions run
  `build/tools/randvars build/ailc 2000 3 async`.
- An operation asks the kernel first and waits only after `EAGAIN`; keep that order, it is why
  a busy server hardly ever sleeps.
- Library names all start with `async`; a library returns an error and never ends the program.

## Related
- [Tools in AIL](tools-in-ail.md)
- [Review fixes of 2026-11-20](review-fixes-2026-11.md)
- [Language extensions](language-extensions.md)
- [Open items](../status/open-items.md)

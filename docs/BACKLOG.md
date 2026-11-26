# Backlog

> Since 2026-11-21 the benchmarks are in the repository ail-bench
> (https://github.com/CristianosLeite/ail-bench). Paths on this page that name `bench/`, `tools/perf.aiw`,
> `tools/par.aiw`, `tools/tokens.aiw`, `tools/tokens.sh`, `tools/bench.sh`, `tools/claudetokens.sh`,
> `tools/pin.sh`, `tools/lib/o200k.aiw`, `tools/lib/fmt.aiw`, `tests/algo.sh`, `tests/par.sh`,
> `tests/async.sh`, `tests/tokens.sh`, `docs/performance.md` or `docs/tokens.md` are paths there. The
> algorithm, array and collection programs are `bench/<name>.aiw` there, no longer in `examples/`, and
> `tests/nd/bench.py` is the tool `tools/nptime.aiw` there.

The work that is done: every item that was in [TODO.md](TODO.md) and has been
completed, with what was asked for and, where it was measured, what came of
it. The items were moved here on 2026-11-21, when all 105 were ticked; an
item that is completed in TODO.md is moved here with its section. See the
[roadmap](roadmap.md) for project history.

## Compiler self-hosting and language limits

- [x] Add named read-only data and make string addresses and byte lengths usable
  outside `sys`. Today a string is inlined behind a jump and expands to two
  syscall arguments. Stage1 builds its constant tables at startup from decimal
  words. Preserve automatic byte lengths and support arbitrary byte data.
- [x] Lift the 16-buffer limit and add a compact way to declare shared scalars
  and constants. Stage1 uses all 16 slots and packs additional state into one
  buffer behind offset-based accessors.
- [x] Support forward references to buffers and data. A `buf` must precede every
  use today, including uses inside functions. Give the new global names clear
  collision and shadowing rules for function locals and top-level variables.
- [x] Support full-width 64-bit immediates, negative literals and compact hex
  notation for hardware values. Ordinary literals are unsigned decimal and
  silently wrap at 32 bits. Diagnose out-of-range literals and keep wrapping
  arithmetic available.
- [x] Add 16-bit and 32-bit loads and stores. The current operations cover 8 and
  64 bits, and stage1 needs helpers to append or patch 32-bit words.
- [x] Lift the six-variable limit at top level and in functions, including
  parameters. Registers are assigned for the entire scope. Reuse registers
  across disjoint lifetimes and spill to the stack when necessary.
- [x] Lift the six-parameter limit on AIL calls with stack arguments or another
  extension to the internal calling convention. The raw Linux syscall ABI has
  its own six-argument limit.

## Correctness and memory

- [x] Detect variable reads on paths that skipped their assignment. The compiler
  checks textual definition order, so a jump over an `as` can leave a variable
  with an unspecified value. Account for branches, joins and loop back edges.
- [x] Diagnose invalid accesses proven at compile time. Track known buffer
  addresses and constant offsets, and account for access width and write
  permissions. Raw `load` and `store` currently have no bounds checks, so an
  access can reach a neighboring buffer or fault.
- [x] Add allocation, release and local storage facilities. `buf` accepts a
  positive decimal size, rounds it up to 8 bytes and reserves global zero-filled
  storage for the process lifetime. Runtime-sized storage currently uses raw
  syscalls. Consider configurable alignment and explicit zero-length objects.
- [x] Evaluate checked memory operations for dynamic bounds and lifetime or
  alias tracking for managed allocations. Define how pointers cross function and
  syscall boundaries before deciding whether borrow checking fits AIL.
- [x] Add signed division, remainder, ordering and arithmetic right shift.
  Existing operations use unsigned semantics. Consider checked arithmetic for
  overflow and invalid shifts, and a way to handle division by zero, which
  currently raises `SIGFPE`.
- [x] Improve recursion limits. Each call consumes 56 bytes before any future
  spills, and stack exhaustion is unchecked. Evaluate tail calls and a defined
  stack exhaustion failure mode.

## Program composition and hardware access

- [x] Support multiple source units with a compact mechanism for sharing code and
  data. The compiler consumes one source stream with no imports or linking.
- [x] Extend function composition where it saves tokens. Functions are flat,
  `call` requires a static name, and `ret` carries one value. Evaluate local
  helper definitions, indirect calls and multiple results independently.
- [x] Measure the cost of explicit labels, jumps and comparison temporaries in
  real programs. Evaluate direct conditional branches and compact structured
  control flow while retaining explicit jumps.
- [x] Make system interfaces cheaper to use. `sys` requires numeric syscall
  IDs, returns raw error values and leaves omitted argument registers untouched.
  Evaluate named ABI constants and reusable helpers for process arguments,
  environment and common I/O.
- [x] Evaluate additional machine operations using representative programs.
  Floating-point, vector and atomic operations currently have no language forms.

## Compiler scale, output and tooling

- [x] Split the compiler using the existing [`use`](language.md#use) statement,
  which the pinned seed already supports for `compiler/tables.aiw`.
  - Keep `compiler/ailc.aiw` as the entry point with the shared declarations and
    parser state machine. Its states share top-level variables and labels.
    Extract whole functions along the existing section boundaries. Suggested
    files under `compiler/` are `diag.aiw`, `lex.aiw`, `names.aiw`, `expr.aiw` and
    `emit.aiw` for diagnostics, token reading, name lookup, expressions and code
    emission.
  - Put each `use` where the extracted code stood. A used file shares the
    top-level scope and is compiled at that point, so preserve the order of
    `var` and `const` declarations and keep each function in one file. Build
    from the repository root and use the same spelling for each path everywhere,
    since `use` resolves paths from the working directory and deduplicates by
    exact spelling.
  - List every compiler source in the Makefile dependencies and include it in
    the scratch copy in `tests/make.sh`. Run `make test` to check the bootstrap
    fixed point and compare `build/ailc` byte for byte with a build from before
    the split to verify that moving the source preserved the generated binary.
  - Revisit a separate `import` if a concrete use case calls for file-local
    names or explicit exports.
- [x] Lift the 65,536-byte source cap. Both compilers read all input before
  parsing, allocate a fixed 1 MiB emission buffer and size the jump, label, call
  and function tables from the source cap. Grow storage as needed and check
  capacity where bytes and entries are appended.
- [x] Improve symbol lookup at scale. Linear scans for duplicate definitions and
  fixups can make symbol-heavy programs take quadratic time to compile.
- [x] Remove fixed layout constraints. The ELF code and writable segments start
  at `0x400000` and `0x10000000`, and buffer addresses are encoded as 32-bit
  immediates. That caps the total rounded buffer size at 3,840 MiB. Evaluate
  relocatable addressing and position-independent executables, and handle
  branches or calls that exceed signed 32-bit displacement range as output grows.
- [x] Evaluate additional targets and interoperability. The compiler and its
  output are x86-64 Linux only. Generated programs are standalone ELF64 files
  without ELF sections, symbols or dynamic linking, and AIL calls use an
  internal calling convention. Consider linkable objects and a platform ABI.
- [x] Report source locations and specific causes for compile errors, including
  the original use site of unresolved names. Today diagnostics are one line
  without a location. Evaluate source maps or debug metadata for runtime faults.
- [x] Generate common compiler tables from a single definition. Stage0 declares
  the ELF template, opcode rows and register data in assembly. Stage1 recreates
  them with decimal words and manually maintained offsets.
- [x] Add differential fuzzing and independent checks of emitted bytes, including
  every displacement at fixup-table capacity. The existing parity suite checks
  both compilers against one another and checks the bootstrap fixed point.
- [x] Automate the check that a failed example build leaves no up-to-date target.
- [x] Measure token cost with a real tokenizer on equivalent AIL, C, Rust and
  assembly programs. Use the results to guide syntax choices.

## Port the Python tools to AIL

Give each tool an entry point at `tools/<name>.aiw` and an executable at
`build/tools/<name>`. Build the tools with `build/ailc` after the bootstrap.
Add a `make tools` target and declare each tool's source dependencies so edits
to a shared file rebuild its callers. Have `make test` build the tools it runs.

Use the existing [`use`](language.md#use) and keep dependencies one way.
Tool entry points handle arguments, diagnostics and exit status. Put shared
token and line scanning in `tools/lib/scan.aiw` and shared control-flow
analysis in `tools/lib/flow.aiw`. Keep each tool's rewrite rules, generator or
reporting code with that tool. Add `lib/std/bytes.aiw`, `lib/std/file.aiw` and
`lib/std/proc.aiw` for byte buffers, file I/O and child processes as callers need
them. Reuse `lib/std/io.aiw` for arguments and output. Keep Linux syscall details
in the file and process helpers and the compiler bootstrap independent of
the tools.

Pass text as an address and byte length, and refer to positions in a growable
buffer by offset so they survive reallocation. Keep mutable state in buffers
owned by the caller. Document who frees allocations and closes descriptors,
which calls may grow a buffer, and how errors are returned. Prefix new shared
symbols by file purpose because `use` brings names into one program-wide scope.

1. [x] Port `hashcol.py`. Use existing arithmetic and byte operations to
   enumerate names and compute the 32-bit hash. Check the reported pair against
   the current script and the `hash_collision_prefix` fixture.
2. [x] Port `fuse.py`, then `infix.py`. Add shared file and buffer helpers and a
   byte-oriented source scanner that preserves strings, comments and line
   endings. Share label lookup and control-flow traversal where the passes
   need the same semantics. Keep expression trees and their printer in
   `infix` until another tool uses them. Compare the ports against the Python
   tools on representative sources. Retain the byte-for-byte, idempotence
   and compiled-behavior checks in `tests/infix.sh` and switch it to the AIL
   executable after it passes them.
3. [x] Port `randvars.py`. Use a documented deterministic PRNG and keep the
   evaluator independent of the compiler and source emitters. Retain the
   three source forms, the byte comparison of the first two, expected exit
   statuses, and saved failure sources. Replay selected Python-generated
   cases as fixtures if the new PRNG changes the corpus for existing seeds.
   Add the process helpers used here and by `perf` for environment and argument
   passing, descriptor redirection, output capture, exit status and cleanup.
   Drain redirected output while the child runs, or use temporary files.
   Enforce the existing run timeout, kill timed-out children and reap them.
   Switch `make test` to the AIL runner for both function and top-level modes.
4. [x] Port `perf.py`. Reuse the process and file helpers. Keep benchmark inputs
   and expected results in tool-local data, and keep validation, timing and
   reporting in separate functions. Preserve CPU affinity, monotonic timing,
   warmups, shuffled run order, summary statistics and output checks. Keep
   `gcc`, `rustc`, `as` and `ld` as external commands. Document the launch
   method and compare it against the current `posix_spawn` path before mixing
   new startup measurements with historical results.
5. [x] Port `tokens.py`. Keep corpus selection, comment stripping and table
   output in the tool. Put `o200k_base` segmentation and byte-pair encoding
   in a dedicated AIL source file. Load the official merge ranks as a data
   file pinned by checksum. Compare the full table with `tiktoken` on the
   benchmark corpus and exercise Unicode and whitespace cases separately.
   A compatible external tokenizer can serve during the transition. Switch
   `tools/tokens.sh` to the AIL executable and remove its Python environment
   setup once the AIL tokenizer matches the reference.

6. [x] Port `par.py`, which the list above left out: the check of
   `tests/par.sh` and the three tables, with the process helpers and the
   token counts of `build/tools/tokens`. With it `make test` needs no
   Python.

Use the Python scripts as references during each port. Preserve the current
command arguments, exit statuses and output formats where callers rely on
them. Update the documented commands and retire each Python entry point after
its AIL replacement passes the corresponding checks.

- [x] `procheld` of `lib/std/proc.aiw` (2026-11-24, for aildb, whose
  command is killed by `procwait` of the program that started it and
  left the embedding provider it had started running): a child started
  as `procstart` starts one and killed by the kernel when the thread
  that started it ends (`PR_SET_PDEATHSIG`). `procstart` and `procheld`
  share what the child does, `procchild`. Test `lib_proc_held`: a
  process in the middle is killed, the child of `procheld` is gone and
  the child of `procstart` goes on. After a review of it the same day,
  a child whose `prctl` the kernel refuses ends with status 127 and
  starts no program; the test denies the request with a filter of
  system calls.

## Source style and editor tooling

- [x] Document the indentation convention. Use one tab per syntactic block
  level and display tabs at a width of two columns in VS Code. Keep top-level
  statements at column one. Indent the bodies of `fn`, `if` (including its
  comparison forms), `else` and `while`. Align `else` and `end` with the
  matching opener. A `label` stays at its current block depth. Keep expressions
  and assignments compact, as in `n-=1`. Indentation is a style convention
  and has no effect on how the compiler parses blocks.
- [x] Write an AIL formatter that changes only leading spaces and tabs. Add
  `--check` to report indentation violations without rewriting files, as the
  first lint rule. Verify that formatting is idempotent and that formatted
  examples compile to the same bytes.
- [x] Add a VS Code extension for `.aiw` files with syntax highlighting, block
  folding and formatting through the same AIL formatter.
- [x] Apply the convention to the examples first. Reindent the compiler in a
  separate formatting commit and verify the bootstrap fixed point.

On the ten examples, the `o200k_base` tokenizer counted 970 tokens without
indentation, 990 with one tab per level (+2.1%), and 1,024 with either two or
four spaces per level (+5.6%), excluding comments. All variants compiled to
byte-identical executables. See [token cost](https://github.com/CristianosLeite/ail-bench/blob/main/docs/tokens.md) for the corpus.

## Parallel execution

- [x] Define compact `spawn` and `join` forms for independent tasks. Have
  `spawn` submit a function and return a task handle, and have `join` wait
  for its result. Define handle lifetime, error handling and the visibility of
  writes after `join`. Specify how long memory passed to a task must stay valid.
- [x] Implement a small runtime in AIL that starts a bounded, configurable pool
  of Linux threads on demand. Reuse workers across tasks and skip runtime
  initialization in programs that never spawn a task.
- [x] Test result delivery, shared-memory synchronization and worker limits.
  Measure elapsed time and source tokens on the same divisible workloads at 1,
  2, 4, 8, 14 and 20 workers on the benchmark machine. Vary task size to find
  where scheduling and synchronization overhead outweigh the speedup.

## Native asynchronous execution

Port Tokio's runtime model to AIL on Linux and integrate suspension into the
language. Use Tokio's scheduler, I/O driver and timer service as the reference
architecture. Keep the runtime in AIL and expose its polling contract through
a small internal interface for compiler-generated code.
[Tokio runtime architecture](https://docs.rs/tokio/latest/tokio/runtime/index.html)

1. [x] Prototype the runtime in AIL with hand-written resumable tasks. Define
   the task frame, poll and wake contract, result storage and task lifetime.
   Start with one executor thread, a ready queue and cooperative scheduling.
   Coalesce repeated wakeups and preserve wakeups that arrive during a poll.
   Keep runtime initialization on demand for programs that execute async code.
   [Tokio's poll and wake model](https://tokio.rs/tokio/tutorial/async)
2. [x] Add the Linux I/O driver and timers. Keep the executor, `epoll` driver,
   and monotonic deadline queue in separate AIL files under `lib/async/`.
   Start with sleep, timeouts and nonblocking TCP accept, connect, read and
   write. Define how operations retry after `EAGAIN`, handle partial reads
   and writes, and remove registrations when cancelled. Test descriptor
   reuse and races between I/O readiness, deadline expiry and cancellation.
3. [x] Integrate native async syntax. Prototype `async fn name ...` and
   `await h as result`, and measure their token cost on timers and network
   programs before settling the syntax. Define how a call creates a future,
   which operation schedules it as a concurrent task, and how synchronous
   code starts and drives the executor. Compile each async function into a
   resumable state machine with a frame for values that must survive `await`.
   Define how results and errors are delivered, how that frame is freed,
   and when a `local` address remains valid across suspension. Keep the
   compiler sources within the syntax supported by the pinned seed until
   a seed that supports async is released and pinned.
4. [x] Integrate with the existing `spawn` and `join` worker pool. Keep their
   documented behavior and use the pool for blocking calls and CPU-bound
   work. Deliver worker completion to the executor as a wakeup that an async
   task can await. Define cancellation and shutdown for queued work, running
   work, and tasks suspended on timers or I/O. Add bounded channels and
   waiting on the first of several operations after those rules are tested.
   Evaluate a multithreaded async scheduler after measuring the single-thread
   executor and defining which task state can move across threads.
5. [x] Test suspension and resumption across branches and loops, propagation
   of results and errors, cancellation before and after readiness, shutdown
   with live tasks, and progress under load. Check that synchronous programs
   start no async runtime. Add a timer example and a concurrent TCP echo
   server. Measure source tokens, throughput, latency and memory per task
   on representative workloads before broadening the API.

## Native numerical arrays

Port NumPy's core array model to AIL on x86-64 Linux. Use `ndarray` views,
broadcasting and elementwise operations as the reference for a compact
library under `lib/nd/`. Programs bring it in with `use` and call prefixed
functions. The implementation uses AIL's existing memory operations and
scalar floating-point statements and runs without Python or BLAS.
[NumPy copies and views](https://numpy.org/doc/stable/user/basics.copies.html)
and [ufuncs](https://numpy.org/doc/stable/reference/ufuncs.html).

1. [x] **Establish the array descriptor and memory contract.** Follow the
   collection libraries with caller-owned, zero-initialized descriptors and
   no top-level initialization. Record dtype, rank, shape, signed byte
   strides, the data origin and the backing storage bounds. Start with
   row-major contiguous `f64` arrays and rank-1 and rank-2 workloads. Check
   shape products, allocation sizes and offsets before accessing storage.
   Define owned arrays and borrowed views, with the backing storage kept
   alive by the caller until all views are finished. Free owned storage
   and reset its descriptor. Return errors explicitly and preserve the
   descriptor on failure.
2. [x] **Add views and elementwise kernels.** Support basic slicing,
   transpose and reshape of contiguous arrays as metadata operations, and
   provide an explicit copy for materializing a view. Use one strided
   traversal for same-shape and broadcast operations, with a flat loop for
   contiguous inputs. Match dimensions from the right and use zero input
   strides for expanded axes, including scalar operands. Start with add,
   subtract, multiply and divide. Write to caller-provided outputs so
   buffers can be reused across operations. Allow exact in-place matches
   for elementwise kernels, reject other output overlap with inputs, and
   reject output views that map multiple elements to one address.
3. [x] **Add reductions and matrix products.** Implement sum and mean over
   the whole array and along one axis, and add vector dot products and 2-D
   matrix multiplication. Specify empty axes, NaNs, infinities and the
   accumulation order. Evaluate pairwise summation against the scalar
   baseline. Add `i64` with explicit conversions once the `f64` kernels
   and fixtures are in place. Define integer overflow before extending
   the reductions to integers.
4. [x] **Verify the semantics and measure the kernels.** Check shapes,
   negative strides, empty and singleton axes, incompatible broadcasting,
   aliasing, overflow and allocation failure in `tests/lib_nd_*`. Generate
   reference fixtures with a pinned NumPy version and commit the expected
   results so `make test` runs offline without Python. Use tolerances for
   floating-point results and check special values separately. Extend the
   `perf` method to measure elementwise operations, reductions and matrix
   products on identical inputs against C (`-O3`) and, in an optional run,
   NumPy. Check results before timing, report kernel and end-to-end time
   separately, and count caller tokens for equivalent workloads. Document
   the API and results in [language.md](language.md) and
   [performance.md](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md).
   Done on 2026-11-21: the tests `lib_nd_ref_*` compare the library with
   NumPy 2.3.5 through `tests/lib/ndfix.aiw`, which `tests/nd/gen.py`
   wrote and, since 2026-11-22, `tools/ndgen.aiw` writes, the same bytes
   without NumPy; `ndelem`, `ndreduce` and `ndmatmul` are timed by `perf`. The
   kernels take 3.65 times as long as the loops of C in the geometric
   mean of 14 times, 1.24 times where memory is the limit and up to 10
   times at a thousand numbers; a caller is 608 tokens against 636 in C
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#numerical-arrays-2026-11-21)).
5. [x] **Optimize based on measurements.** Compare cache blocking for matrix
   multiplication and coarse tasks with disjoint outputs using `spawn` and
   `join`. Use the scalar baseline to evaluate selective SIMD support and
   keep a scalar fallback if new instructions are added. Check numerical
   behavior and the compiler fixed point for any code generation changes.
   Use concrete workloads to decide when to add more dtypes, advanced
   indexing, `.npy` I/O, linear algebra or FFTs, and use caller token counts
   to decide whether array syntax is worth adding.
   Done on 2026-11-21: a number as an operand has a loop over words; the
   statements `padd`, `psub`, `pmul`, `pdiv` and `pmadd` compute two
   doubles at once from memory to memory with the bits of one at a time,
   and the kernels use them, which brings the geometric mean of AIL/C
   over the 14 kernels from 3.650 to 2.175; `ndmatmulp` multiplies in
   tasks, 5.5 times faster at a side of 1000 on 20 processors. Blocks in
   the product gained 4% and were left out, and `sum` and `dot` stay at
   3.5 times C, since their order of adding is kept. No further dtypes,
   indexing, file formats or array syntax until a program needs them
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#after-the-measurements)).
6. [x] **Keep ordered floating-point accumulators in XMM registers.** Prototype
   compiler support for keeping the running value of `ndsum` and `nddot` in
   XMM across iterations. The current `fadd` moves its operands from general
   registers and moves the result back on every addition. Preserve index
   order and round the multiply and add separately in `nddot`. The current
   kernels take 3.35–3.53 times as long as the C loops. Measure the prototype
   against both baselines and check the compiler fixed point.
   Done on 2026-11-21: `fsum` and `fdot` are the loop as one statement, with
   the sum in `xmm0` for the whole run and the bits of the loop of `fadd`;
   `sum` and `dot` take 1.00 to 1.03 times the time of C
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#array-kernels-after-the-first-round-2026-11-21)).
7. [x] **Use packed operations on reversed contiguous views.** In `ndrun`,
   start at the lowest address when the result and vector operands all have
   a stride of −8 bytes and any scalar operands have stride zero. Reuse the
   existing forward packed loops and keep the general strided path. A
   prototype gave a 3.8x speedup at 1,000 elements and 2.1–2.4x at a million.
   Compare bits for odd lengths, scalar broadcasts and exact in-place views.
   Done on 2026-11-21: `ndrun` turns such a run round; 3.7 to 4.0 times
   less time at 1,000 elements and 2.0 to 2.3 at a million, the time of the
   arrays forwards, with the bits of a loop over the indices
   (`tests/lib_nd_reversed`;
   [results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#array-kernels-after-the-first-round-2026-11-21)).
8. [x] **Reduce setup cost for small contiguous vectors.** Add a direct path
   for nonempty contiguous rank-one doubles when the output is disjoint
   from both inputs, including scalar operands. Share the arithmetic loops
   and preserve shape, broadcasting and alias checks in the general path.
   Reusing descriptors saved 5–9% at 1,000 elements. With descriptors already
   reused, the direct path saved another 11–13% at 1,000 elements and 26–28%
   at 16. Report timings with descriptor setup inside and outside the clock.
   Done on 2026-11-21: `ndelem` calls `ndrun` at once for such arrays. With
   the clock of the harness taken off, a call with its descriptors ready
   takes 19 ns instead of 64 at 16 elements and 15% less at 1,000; setup
   inside the clock adds 25 ns, 8% at 1,000
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#array-kernels-after-the-first-round-2026-11-21)).
9. [x] **Unroll the packed loop in matrix multiplication.** In `ndaxpy`, try
   four `pmadd` operations per iteration, followed by packed and scalar
   tails. A prototype cut single-core kernel time by 19% at side 100 and 7%
   at side 1,000. Preserve the order of `k` and compare bits for odd widths,
   views and the parallel path.
   Done on 2026-11-21: four `pmadd` a round, then pairs, then one. The
   kernel takes 19% less time at side 100, 22% at 300 and 12% at 1,000, and
   the same at 30; `tests/lib_nd_matmul_wide` compares the bits
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#array-kernels-after-the-first-round-2026-11-21)).
10. [x] **Measure task granularity for matrix multiplication.** Compare
    `ndmatmul` and `ndmatmulp` over worker and task counts. On the
    i7-12700H, side 1,000 took 252 ms serially and 39 ms with 20 tasks,
    while four tasks beat 20 at side 30. Measure with a cold and a reused
    pool, include rectangular shapes, and document when parallel calls
    pay off.
    Done on 2026-11-21: `bench/nd/mmtasks.sh` times seven shapes at nine
    pairs of threads and tasks. With the pool started tasks pay from 13
    microseconds of work, with few tasks; the first call starts the
    threads and pays from a side of about 100; side 1,000 takes 222 ms on
    one thread and 39 ms in 20 tasks
    ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#array-kernels-after-the-first-round-2026-11-21)).
11. [x] **Report requested and actual matrix task counts.** With 16 result
    rows and 14 requested tasks, `ndmatmulp` uses blocks of two rows and
    creates eight tasks. Show both counts in `bench/nd/mmtasks.sh` and the
    performance table. Measure the current split before changing it. A
    prototype that distributed the extra rows across blocks reduced the
    warm-pool median from 74.7 to 58.4 microseconds in this case and
    increased it for some other shapes.
    Done on 2026-11-21: `ndruns` gives the rows of a run and the tasks
    made, `ndmatmulp` uses it and `bench/nd/mmtasks.sh` prints both
    counts. A balanced split was 5% to 19% faster where a task is ten
    microseconds or more, up to 58% slower at a side of 30, and 1.00 on
    the geometric mean of the eleven cells that differ, so the split
    stays
    ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#array-kernels-after-the-first-round-2026-11-21)).
12. [x] **Validate the first parallel matrix result before reusing its
    buffer.** `bench/nd/mmtasks.aiw` checks the first call's status but
    compares the output only after later calls have overwritten it.
    Compare the first result against the serial result before running
    the warm-pool calls. Keep both result checks outside the timed
    regions and verify that corrupting either result fails the benchmark.
    Done on 2026-11-21: the first result is compared before the later
    calls and the last one after them, both outside the clocks; a wrong
    double stored after either makes the benchmark print 1 and
    `mmtasks.sh` end with `differ` and the status 1.
13. [x] **Validate the call that sets the warm minimum.** The last call
    can overwrite an incorrect earlier result whose time is still the
    minimum. In `bench/nd/mmtasks.aiw`, capture the status of each timed
    call and check it after stopping the clock. When a call would lower
    the minimum, compare its output bit for bit with the serial result
    before accepting its time and before reusing the output buffer.
    Keep the first- and last-call checks. Verify that an incorrect
    intermediate call that would set the minimum makes the script fail
    even when the last call gives the correct result.
    Done on 2026-11-21: every timed call's status is counted, and a call
    faster than all before it is compared with the serial result before
    its time is taken. A wrong element stored after the first later
    call, with its time made 0, prints 1 and the time of a right call,
    and `mmtasks.sh` ends with `differ`; before, it printed a time of 0
    and no error.
14. [x] **Label the reported count as planned row blocks.** Rename
    `tasks made` to `row blocks` in `bench/nd/mmtasks.sh` and use the
    same term in `bench/nd/mmtasks.aiw` and `performance.md`. Keep the
    requested task count beside it and show the count returned by
    `ndruns`. Explain that the serial path runs one block on the
    caller and a failed `spawn` also leaves its block to the caller.
    Check that the report shows one row block for a serial call and
    eight for 16 rows with 14 tasks requested.
    Done on 2026-11-21: the column and the texts say row blocks, the
    count `ndruns` plans, with the note on the caller's block; the
    report shows 1 for a call with one task and 8 for 16 rows with 14
    tasks asked for.

Rerun the array benchmarks and `tests/lib_nd_*` for these changes. Include
integers, transposes and mixed strides when checking for regressions beyond
the contiguous and reversed double workloads measured so far.

## Harness clock and an algorithm library

The AIL harness reads the clock with `sys clock_gettime`, a system call,
while the C and Rust harnesses read it through the vDSO. On the i7-12700H a
kernel that does nothing takes 91 ns per run in AIL and 12 ns in C. Kernel
times summed over many short runs therefore overstate AIL/C: each `ndelem`
kernel at 1,000 elements and 20,000 runs carries 1.8 ms of clock in AIL
against 0.24 ms in C. See
[the call cost measurements](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#array-kernels-after-the-first-round-2026-11-21).
The fix touches every algorithm program, so move their kernels into a
library in the same pass and leave the examples as callers.

1. [x] **Make the clock cost the same in the three harnesses.** Compare
   three ways: time a run around nothing in each harness and write the
   total as an extra word that `perf` subtracts and reports; call
   `__vdso_clock_gettime` from AIL, found through `AT_SYSINFO_EHDR` in the
   auxiliary vector behind `args` and called with `callp`; or read the
   clock with the raw system call in C and Rust as well. For the vDSO call,
   check the argument registers, the stack alignment and which registers
   survive. Keep `harness.aiw`, `harness.h` and `harness.rs` the same in
   what they time, and update `tests/algo.sh` and `perf` if the output
   gains a word. Accept the change when an empty kernel costs the same
   within a few nanoseconds in the three languages.
   Done on 2026-11-21: the harness in AIL finds `__vdso_clock_gettime`
   through `/proc/self/auxv` and calls it with `callp`. An empty kernel
   costs 13 ns a run in AIL, 12 in C and 12 in Rust, where it was 91, 12
   and 12; the system call in all three gave 91, 91 and 89, and the
   subtraction would have left the system call in every run
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#the-clock-of-the-harness-2026-11-21)).
2. [x] **Rerun the kernel tables the clock skewed.** The bias of a row is
   its runs times the difference per run, so it matters for the rows with
   thousands of short runs in the algorithm and array tables and not for
   those at a million elements. Rerun `build/tools/perf` with the corrected
   harness, report the old and new ratios side by side, and note in the
   earlier sections of [performance.md](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md) which figures
   included the clock. Leave the historical tables as measured.
   Done on 2026-11-21: over the 62 kernel times AIL / C is 1.201 where
   the system call gave 1.266, and over the 30 rows of a thousand runs
   or more 1.286 against 1.425; the rows of fewer runs did not move.
   The three earlier sections carry a note
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#the-clock-of-the-harness-2026-11-21)).
3. [x] **Move the algorithm kernels into a library.** Put the sorts
   (`quicksort`, `mergesort`, `heapsort` and `isort`), the lower-bound
   search, the open-addressing table of `hashtab` and the two traversals
   of `graph` under `lib/algo/`. Follow the library rules: a prefix on
   every function, parameter and variable, no top-level code, no `var`,
   caller-provided scratch storage and explicit results. Reduce each
   program in `examples/` to its `use` lines, the adapter the harness
   calls and the `call algo...` line, as the array programs already are.
   Keep each algorithm, its memory layout and its output: `tests/algo.sh`
   must pass unchanged and the results must stay byte-identical to the C
   and Rust programs. Decide how the fixed table of `hashtab` and the
   in-place heap of `heapsort` relate to `lib/std/map.aiw` and `lib/std/heap.aiw`,
   and keep them separate where the benchmark layout differs. Add the new
   files to the Makefile prerequisites and to `tests/indent.sh`, test the
   functions on their own in `tests/lib_algo_*` (empty, single, duplicate
   and already sorted input), and document them in
   [language.md](language.md).
   Done on 2026-11-21: `lib/algo/sort.aiw`, `search.aiw`, `hash.aiw` and
   `graph.aiw`, a prefix a file since the harness owns `algo`. The six
   harness programs compile to the same bytes as before; the heap and
   the table stay apart from `lib/std/heap.aiw` and `lib/std/map.aiw`, whose
   layouts are others ([reference](language.md#the-algo-library)).
4. [x] **Measure what the move changes.** Check that `place` and `lower`
   are still compiled in place at their calls, which needs the callee
   before the caller and no global name in its body. Compare kernel times
   before and after over several placements of the code, since a kernel
   moved by a few bytes varied by a fifth at 1,000 elements. Report the
   token counts of a caller and of the library separately against the C
   and Rust programs, which keep their kernels inline, and update
   [tokens.md](https://github.com/CristianosLeite/ail-bench/blob/main/docs/tokens.md).
   Done on 2026-11-21: the six harness programs are byte for byte the
   files they were, so the calls in place and the times are the same;
   `isort` takes 54.3 ms against 54.6 and from 54.1 to 65.1 over four
   placements. The six callers are 260 tokens against 1613 in C and
   1783 in Rust, and their library functions 1793
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#the-algorithm-kernels-in-a-library-2026-11-21)).

## Algorithm benchmarks and collection APIs

Use [`isort`](../examples/isort.aiw) and its [C counterpart](../bench/isort.c)
as the starting point. Pass contiguous arrays as an address and an element
count, use `load` and `store` for 64-bit values, and size runtime buffers with
`alloc`. The algorithms can use the current language and calling convention.

- [x] Add quicksort in `examples/quicksort.aiw` and `bench/quicksort.c`.
  Sort unsigned 64-bit values in place with the same pivot rule and three-way
  partition in both implementations. Use half-open ranges and recurse on the
  smaller partition while iterating over the larger one to bound stack depth.
- [x] Add bottom-up mergesort with one caller-provided scratch array, heapsort
  with an in-place binary heap, and binary search over sorted arrays. Make
  binary search return the first index whose value is at least the key, or the
  element count if there is none. Keep the algorithm and memory layout matched
  in each AIL and C pair.
- [x] Add hash lookup and graph traversal benchmarks. Measure inserts and
  successful and unsuccessful lookups on the same key sequence and table load.
  Store graphs as a vertex-offset array and a contiguous neighbor array. Use
  a queue for BFS and an explicit stack for DFS, with the same neighbor order
  and visited representation in both implementations.
- [x] Extend [`perf`](../tools/perf.aiw) for algorithm workloads. Run equivalent
  C kernels at `-O3` on identical input generated from fixed seeds. Include
  small and large arrays and random, sorted, reversed and duplicate-heavy
  inputs. Check full sorted output against an independent reference on test
  fixtures, including empty and singleton arrays. Validate results before
  reporting timings. Prepare and reset input outside the timed region. Time
  the kernel inside each executable with a monotonic clock and report it
  separately from the existing end-to-end measurement. Preserve CPU
  affinity, warmups, shuffled runs, and median and quartile reporting. Record
  source tokens for the kernels and the code needed to call them. Include C
  `qsort` as an optional baseline for callers of the generic library interface.

Implement the collections as ordinary library functions under `lib/`. Use
file-prefixed names, caller-owned zero-initialized descriptors and no top-level
initialization. Start with unsigned 64-bit elements or keys and values. The
operation names below are proposed. Keep allocation size calculations checked,
preserve the contents on allocation failure, document the lifetime of any
exposed storage, and have `free` operations reset the descriptor. Return a
separate success or found result wherever zero is a valid value.

- [x] **Growable vector**, `lib/std/vec.aiw`. Provide `vecreserve v n`,
  `vecpush v x`, `vecpop v`, `vecget v i` and `vecfree v`. Keep a data
  address, length and capacity in a 24-byte descriptor, with length and
  capacity in elements. Grow geometrically and reuse `bycopy` for relocation
  if useful. Define `vecreserve` in terms of total capacity and document when
  growth invalidates addresses into the vector.
- [x] **Bounded queue**, `lib/std/queue.aiw`. Provide `queueinit q n`,
  `queuepush q x`, `queuepop q` and `queuefree q`. Allocate a ring of `n`
  values with a head and count. Return failure on full and empty operations.
  Use [`lib/async/chan.aiw`](../lib/async/chan.aiw) as a layout reference and keep
  the queue usable in synchronous programs through its own functions.
- [x] **Min-heap**, `lib/std/heap.aiw`. Provide `heappush h x`, `heappeek h`,
  `heappop h` and `heapfree h`. Store values in a growable array, using the
  vector storage if it fits the callers. Sift up on insertion and down on
  removal. Use the [timer heap](../lib/async/time.aiw) as a reference. Keep
  the in-place max-heap operations of heapsort in its benchmark.
- [x] **Hash map**, `lib/std/map.aiw`. Provide `mapput m k v`, `mapget m k`,
  `mapdel m k` and `mapfree m`. Use open addressing with linear probing,
  power-of-two capacity, and explicit slot states for empty, occupied and
  deleted entries so all 64-bit keys are usable. Update existing keys in place,
  reuse deleted slots, and rebuild when occupied and deleted slots reach the
  chosen load threshold. Publish resized storage after rehashing succeeds.
- [x] Cover each collection in `tests/lib_*`. Check empty operations and zero
  values, vector growth and bounds, queue wraparound and full behavior, heap
  ordering with duplicates, and hash collisions, deletion and resizing. Check
  capacity overflow and reuse after `free`. Document the APIs and storage
  contracts in [`language.md`](language.md) and record benchmark results in
  [`performance.md`](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md).

## Performance follow-up

On the Core i7-12700H, rerunning `build/tools/perf --qsort` after the first
four items brought the geometric mean of AIL/C time ratios from 1.760 to
1.256 across 48 algorithm kernel timings and from 1.037 to 1.032 across five
CPU-bound programs. AIL kernel times fell 28.8%, with `mergesort` gaining
most (51.4% less time) and `hashtab` still furthest from C (1.620x). The
compiler's elapsed time, including process startup, varied from -0.3% to
+2.6% across three sources. The loopback echo servers remained within about
2% at 1, 100 and 1,000 connections. `make test` passed, including the
bootstrap fixed point, as did three extended `randvars` runs that generated
6,000 programs and executed 5,699.

Repeat comparisons with the same inputs and affinity, checking output before
timing and reporting kernel and elapsed times separately. The prototypes
below were checked byte for byte and timed over 15 rounds with shuffled run
order. See [benchmark method](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md#method).

1. [x] **Emit scaled indexes in loads and stores.** In
   [`xaddr` and the memory operand encoder](../compiler/expr.aiw), fold a
   register index scaled by 2, 4 or 8 into the x86-64 memory operand when it
   fits. With both operands in registers, `load p+i*8` went from `imul`,
   `add` and `mov` to a single indexed `mov`, reducing the sequence from
   10 to 4 bytes. The scaled-index change alone brought the mean AIL/C kernel
   ratio from 1.753 to 1.639. See the
   [scaled index measurements](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#scaled-indexes-2026-11-20).
2. [x] **Reduce stack accesses in hot loops and evaluate selective inlining.**
   Inspect [`alloc`](../compiler/emit.aiw) and the generated code for
   [`hashtab`](../examples/hashtab.aiw) before expanding inlining. At 1,000
   keys, manually inlining `place` lowered insertion and successful lookup
   times by 12–20%, while unsuccessful lookups on random keys took 30% longer
   and the loop gained stack accesses. Measure all three operations at 1,000
   and 1,000,000 keys with random and duplicate-heavy inputs. Compare the
   generated stack accesses and code size as well as elapsed time.
   Done on 2026-11-20: registers go to the variables that the loops mention
   most, and inlining `place` by hand is then faster in 11 of the 12 kernel
   times ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#registers-by-weight-2026-11-20)).
3. [x] **Find a profitable lowering for compound loop conditions.** Use
   [`mergesort`](../examples/mergesort.aiw) as a test case. A prototype split
   its two bounds comparisons into separate branches, cutting kernel time
   by up to 7% on sorted and reversed inputs while increasing it by up to
   18% on small random or duplicate-heavy inputs. Preserve AIL's eager
   evaluation semantics, including possible traps, and compare alternative
   branch layouts across all four input shapes and both input sizes.
   Done on 2026-11-20: a jump for each comparison before the loop and at its
   end, which was faster in all eight inputs once the registers went by
   weight ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#two-comparisons-in-a-while-2026-11-20)).
4. [x] **Tune task granularity before changing the pool.** Using medians from
   three runs per configuration (`build/tools/par --runs 3`), 160 tasks at
   20 threads gave a 10.21x speedup for `collatz`, 10.86x for `primes` and
   3.35x for `memsum`.
   At 20 threads, `memsum` took 62.5 ms with 200 tasks per pass and 374 ms
   with 20,000. All three workloads lost to their sequential versions at a
   million tasks. Sweep batch sizes across worker counts and use the results
   to document useful starting sizes for CPU-bound and memory-bound work.
   [Task benchmark method](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#tasks-2026-11-20)
   Done on 2026-11-20: `build/tools/par --grid` times every pair; the sizes
   to start from are in
   [the table and its reading](https://github.com/CristianosLeite/ail-bench/blob/main/docs/performance.md#the-size-of-a-task-at-each-number-of-threads)
   and in the pool section of the language reference. The rerun with
   `--grid --runs 3` gave 10.18x and 11.22x for `collatz` and `primes` at
   2,000 tasks on 20 threads, falling to 2.44x and 3.48x at 200,000 tasks.
   `memsum` peaked at 2.95x with 200 tasks per pass.

5. [x] **Inline small functions at their calls.** With the current compiler,
   writing `place` into the two `hashtab` loops by hand reduced kernel time
   by 6% to 31% across all 12 cases, with 123 more bytes in the executable.
   This includes the random misses at 1,000 keys that regressed before the
   register allocation change. Decide which functions qualify (no `local`,
   no `ret` inside a loop, a size limit), how the variables of the callee are
   named in the caller's 64, and how the two passes see the body.
   Measure `hashtab`, `heapsort` (`sift`) and `bsearch` (`lower`).
   Done on 2026-11-20: a call in a function, of a function before it whose
   code is at most 160 bytes and whose body has no call and no global name,
   is its body, read again from the source; a parameter that is only read
   is the caller's variable. Over eight places of the code `hashtab` takes
   5 to 36% less time, `bsearch` the same, and `heapsort` with `sift` in
   place 7% more at a million elements, so `sift` stays a call
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#calls-compiled-in-place-2026-11-20)). The
   same kernel moved by a few bytes varies by a fifth at a thousand
   elements, which the results take into account.
6. [x] **Probe `hashtab` with indexes in 64-bit words.** Each slot occupies
   two words. Keep the probe index even, advance it by two and use twice the
   slot mask to wrap. This lets `load t+h*8` use the x86-64 scaled operand in
   the probe loop, whose current address is `t+h*16`. Keep the hash, probe
   sequence, table size and duplicate-key behavior. In a prototype on the
   current compiler, all three kernels took 2.6% to 4.9% less time on one
   million random keys, while misses at 1,000 keys and hits at one million
   duplicate-heavy keys took up to 2.5% longer. Retest the full matrix with
   and without inlining, and include a collision that wraps past the last
   slot in the output checks. A separate prototype that returned the key
   already read by `place` saved 12.4% on small random misses but cost
   6.6% to 7.8% on duplicate-heavy hits. Measure that change separately
   before combining it with the new probe index.
   Done on 2026-11-20: the probe counts words. Over eight places of the
   code it takes 5 to 12% less time on a million random keys and is within
   5% elsewhere, but for the random misses at 1,000 keys, 21% slower, as
   they also are with the old probe merely respelled. The key as a second
   result gains at most 5% with the body in place and is left out
   ([results](https://github.com/CristianosLeite/ail-bench/blob/cb14f3bb8c607af5b59b45877c5e2633d986400c/docs/performance.md#the-probe-of-hashtab-in-words-2026-11-20)).

## Redesign

From `REDESIGN.md`; one commit per item.

- [x] Keep the arithmetic benchmark and its timing script in the repository.
- [x] Add CPU-bound workloads to the corpus: `sieve`, `collatz`, `fnv`, `isort`.
- [x] Record the first seed of the compiler in a manifest and release it.
- [x] Build the compiler from the pinned seed, in three generations.
- [x] Make `compiler/tables.aiw` its own source, checked by form and by bytes.
- [x] Check the one compiler without comparing it to stage0.
- [x] Remove stage0.
- [x] Fix the expression syntax from token counts on the corpus.
- [x] Parse infix expressions as arguments.
- [x] Compile compound expressions and `name = expression`.
- [x] Accept an expression as the condition of `if`.
- [x] Add the `while` block.
- [x] Check expressions against computed results in random programs.
- [x] Use immediate forms of instructions, and shifts and masks for division
  and remainder by a power of two.
- [x] Use variables in place as operands.
- [x] Compute an assignment in the register of its target.
- [x] Lower the arithmetic statements like expressions, so both spellings
  give the same bytes.
- [x] Test the condition of `while` at the end of the loop.
- [x] Branch on the flags of the previous instruction.
- [x] Compile loads and stores with the address as base, index and number
  (added when the measurements showed where `isort` and `sieve` lost).
- [x] Record the measurements after instruction selection.
- [x] Write the examples and the library with expressions.
- [x] Add a tool that rewrites statements as expressions.
- [x] Release and pin the second seed.
- [x] Write the compiler with expressions.
- [x] Report the redesign against its acceptance criteria.

Keep the hardware-oriented syntax and use measured token cost to decide where
to relax grammar rules. One statement per line, ASCII identifiers and the lack of classes and objects
are current design choices; explicit `as` captures were one until the
redesign, which adds expressions beside them.

## Single-precision data

aildb (a vector search engine written in AIL) keeps its vectors as IEEE 754
binary32 and scores them in binary64. The language had no statement that
reads, converts or computes a binary32; `load4` gives the 32 bits as an
integer. Its feasibility study of 2026-11-21 measured a conversion written
with integer statements at 3.4 times the time of one instruction, and
asked for statements in the compiler.

- [x] Convert between binary32 and binary64: `f4to8 a as x` and
  `f8to4 a as x`, rows of `optab` around `cvtss2sd` and `cvtsd2ss`.
- [x] Score binary32 where it lies: `fdot4 a p q n as x`, the loop of `fdot`
  with a `movss` and a `cvtss2sd` between registers for each element of the
  first run; the bits of `f4to8`, `fmul` and `fadd` in order.

## Packages and the `ail` command

A program could not read the files of another project: every path of a
`use` starts from the directory the compiler runs in, so the `use` lines
inside a library such as aildb name nothing when it is compiled from the
directory of a program that imports it. The user asked on 2026-11-22 for
one mechanism of versions and dependencies for AIL and what is built on
it; `TODO.md` has what is decided and what is left.

- [x] Packages in `use`: the compiler takes arguments `name=directory`;
  `use "name:path"` reads a file of that package, a path without a name
  starts from the package of the file that has it, and `lib/` is the
  library of AIL in every package. Without arguments nothing changes.
  `compiler/pkg.aiw`, `tests/pkg.sh`.
- [x] The manifest `Ailfile` (`name`, `version`, `ail`, `bin`, `testbin`,
  `dep`) and the lock `Ailfile.lock`, in `docs/packages.md`; `cli/manifest.aiw`
  reads and checks both, orders versions and takes the lines of a
  dependency out of a text. AIL has its manifest and its first version,
  0.1.0.
- [x] The command `ail`, `cli/ail.aiw` with `cli/tool.aiw`, built as
  `build/ail`: `new`, `init`, `build`, `run`, `clean`, `version`, `help`;
  it finds AIL from `AIL_HOME` or from the place of its executable.
  `docs/cli.md`, `tests/cli.sh`.
- [x] `ail test`: the executables built, then each `tests/<name>.aiw`
  compiled and run against its `.out`, `.code` or `.err`, in a directory
  of its own named in `AIL_TMP`, for 10 seconds at most. `ail fmt` and
  `ail fmt --check`: the formatter of AIL over the sources of a package.
- [x] Dependencies: `cli/deps.aiw` finds the packages of a build, those
  of the manifest and those they name, fetches the ones from a
  repository into `deps/` at the revision of the lock and writes the
  lock; `ail add`, `ail remove` and `ail update` change the manifest and
  put it back if the packages cannot be found.
- [x] `make install` (with `PREFIX` and `DESTDIR`) and `make dist`, through
  `tools/install.sh`: `bin/ail`, and in `lib/ail/` the compiler, the
  formatter, the manifest, the licence and the library.
  `tests/install.sh` works on a package with nothing but what was
  installed.
- [x] A test finds the directory of AIL in `AIL_HOME`, which `ail test`
  sets beside `AIL_TMP`: aildb has a test that reads the licence of the
  AIL it is built with.
- [x] The 30 findings of the review of the pull requests 17 to 24, each
  fixed in its commit on the branch `packages-review`: what is not there
  against what cannot be read, files made anew and written whole, the
  manifest and the lock put back on any failure, names that are no
  paths, links not followed by `ail fmt`, one run of `ail test` at a
  time, one directory under two paths, a package called `ail`, and the
  tests that lost the status of what they ran.

## Text formats and the network

What a program needs to talk to another one: numbers and JSON read from
text, and HTTP over the sockets of `lib/async/io.aiw` (user, 2026-11-22,
for the MCP server of aildb: these are libraries of AIL, not of the
program that first needs them).

- [x] `lib/std/num.aiw`: `numint`, and `numdouble`, a decimal text as the
  nearest binary64, a tie to even, for any number of digits. Compared
  with `float` of Python on 303,627 texts made for it (doubles printed
  with their shortest digits and with 17 and 25, the exact middles of
  neighbours with a digit more and less, long runs of digits, every
  exponent up to the edges): no difference. `tests/lib_num_*`.
- [x] `lib/std/json.aiw`: JSON read in the bytes it is written in, a
  value an address, a length and a kind, with no tree and no allocation
  (`jsonvalue`, `jsonelem`, `jsonmember`, `jsonget`, `jsoneq`,
  `jsonstr`), and written (`jsonadds`, `jsonaddi`). RFC 8259 with the
  UTF-8 and the surrogate pairs of I-JSON, 128 deep. Compared with the
  `json` module of Python on 80,066 texts, values it wrote and those with
  a byte removed, changed or added, and on 30,005 values walked and
  written again: no difference. `tests/lib_json_*`.
- [x] `lib/net/http.aiw`: an HTTP/1.1 client on the sockets of
  `lib/async/io.aiw`. `httpcall` sends a request of 128 bytes that the
  caller owns and reads the response, a body by its length, in chunks or
  up to the end of the connection, with a limit of time for each step
  and of bytes; `httpfield`, `httphead`, `httpstatus`, `httpip` and
  `httpurl` take a message and an address apart. One connection a
  request, no TLS, no names. `tests/lib_http_*`.
- [x] `lib/net/httpd.aiw`: an HTTP/1.1 server. `httpdserve` accepts the
  connections of a listening socket, a task for each, reads one request
  and calls the handler of the program, an async function, with a
  request of 136 bytes to which it adds the body of the response;
  400, 431 and 413 are the server's own. `tests/lib_httpd_*`.
- [x] The version 0.1.1 of AIL (user, 2026-11-22), the first with the
  four libraries: `Ailfile` says it and the tag `v0.1.1` names the merge
  of it, so that a package asks for them with `ail 0.1.1`.

## Runtime

From [RUNTIME.md](RUNTIME.md); what was decided with it is in
[TODO.md](TODO.md).

- [x] The runtime in C for x86-64 Linux and the statement `rt`
  (2026-11-26). `rt/linux-x86_64/` is compiled by `cc` without a C
  library into one image that may stand anywhere and has no writable
  byte: a header, a table of entries, and an entry for each service
  that takes the values of AIL to the convention of C. The compiler has
  it as data and copies it behind the header of every executable, 960
  bytes; the process starts at its first entry, and the program ends
  with a jump to the service `exit`. `rt name` calls a service, with
  its counts checked: `exit`, `args`, `alloc`, `free`, `open`, `close`,
  `read`, `write`; the statements `alloc`, `free` and `args` are calls
  of theirs, and `args` may stand in a function. The code of a program
  stands where it did in a line of the cache, and no table of fixups
  has a new kind: the place of an entry is known when it is called.
  [runtime.md](runtime.md) has the services and the form of the image.
  `tests/rt_*`; `tests/bytes.sh` computes the files with the image as
  `cc` built it, and `tests/insn.cases` has a call of an entry and a
  distance to the writable segment in a form that does not depend on
  the size of the image. Two tests of `lib/nd` read behind their last
  buffer, where the state of the runtime now is, and have a buffer of
  zeros for it.
- [x] The examples and `lib/std/io.aiw` through the runtime
  (2026-11-26): `rt read`, `rt write` and `rt exit` where `sys` stood,
  with names or numbers. The library no longer has a `var` or a line
  that runs where its `use` stands: `argc`, `argv` and `procenv` of
  `lib/std/proc.aiw` ask `args` when they are called. `build/hello` is
  1197 bytes, 243 before, of which 960 are the image; started 1000
  times in a row, seven times over, a run takes 121 microseconds in the
  median against 114 before and 389 for C with its library (a rough
  figure, with the time of the starting process in it; the benchmarks
  are to measure it properly). The executable now has a writable
  segment in any case, for the state.
- [x] Seed 7 and the compiler through the runtime (2026-11-26). The
  service `pipeerr` makes a write to a closed pipe an error, which the
  compiler asked of Linux at its start. Seed 7 is the compiler with the
  runtime and `rt`; its release is to keep the image it was built with
  beside it. The source of the compiler has no `sys` left: it reads its
  input and the files of `use`, writes the executable and its messages
  and ends through `rt`. `tests/io.sh` and every expected message are as
  they were, the compiler built by the seed and by itself behave alike
  on every test, example and fuzzed source, and `build/ailc` and
  `build/ailc2` are the same file.
- [x] Services for files and directories (2026-11-26): `mkdir`,
  `unlink`, `rmdir`, `rename` and `names`, which gives the names of a
  directory as bytes with a NUL behind each, so that no caller knows the
  form the kernel has for them. `lib/std/file.aiw` has no `sys` left
  and makes no copy of a path. `tests/rt_dirs`, and the `lib_file_*`
  tests as they were.
- [x] Services for time (2026-11-26): `clock`, nanoseconds of the clock
  that only goes forward, and `sleep`. On Linux the clock is read in
  the page of code the kernel maps into every process, without a
  system call, as C reads it: the runtime finds `clock_gettime` there
  at the first call, through the hash table of either form, and keeps
  it in its state. `procnow` and `lib/async/time.aiw` call them.
  `tests/rt_clock`.
- [x] Services for threads (2026-11-26): `thread`, which runs a function
  of the program with a value on a stack of its own and gives the stack
  back when the function returns, `wait` and `wake` on the four bytes
  at an address, and `cpus`. `lib/std/task.aiw` has no `sys` left: its
  lock, its idle workers and its joins sleep in `wait`, and a worker is
  a `thread`. `tests/rt_thread`, and the `spawn_*`, `join_*` and
  `task_*` tests as they were, the stack overflow that must fault among
  them.
- [x] Services for readiness and sockets (2026-11-26): a poller with
  `watch`, `unwatch` and `poll`, whose events are 16 bytes of the
  runtime's own, what may be done and a tag; a `waker` that ends a poll
  from another thread; `listen`, `accept`, `socket`, `connect`,
  `sockerr`, `port`; `send` and `writeq`, the writes without the signal
  of a closed end. `lib/async/io.aiw` and `lib/async/pool.aiw` have no
  `sys` and no number of a system call left, and no address of a socket
  in the form of the kernel. `tests/rt_sockets`, `tests/rt_waker`; the
  `async_*`, `lib_http_*` and `lib_httpd_*` tests as they were, but for
  `async_write_closed`, which has the two numbers it took from the
  library as constants of its own.
- [x] Services for processes, and a library without `sys` (2026-11-26):
  `start`, a program with its arguments, an environment and its three
  descriptors, held to the process that started it or not; `reap`, its
  end with a limit of time; `pin`. `lib/std/proc.aiw` calls them, so no
  file of `lib/` has a `sys` left, which `tests/rt.sh` holds together
  with the form of the image and its place in an executable. The two
  functions that put the descriptors of a child in place are in
  `cli/tool.aiw` now, for the children it forks itself.
  `tests/rt_start`; the `lib_proc_*` tests as they were.
- [x] `alloc` and `free` at the cost of C (2026-11-26). Measured first:
  the program `allocs` of ail-bench took 79 times as long as its C twin,
  each block being a mapping. The runtime now cuts blocks of 39 sizes
  from chunks of 256 KiB and gives a freed block out again, cleared
  with the string instruction (a loop of 16-byte stores was measured
  and was slower); a block of 32 KiB or more is a mapping as before.
  The lists are locked only once the runtime has started a thread.
  1.03 times C. A block that is freed no longer faults when it is used,
  unless it is a large one: `tests/free_then_use_faults` is a large
  block now, `tests/alloc_reuses_freed` and `tests/alloc_in_threads`
  are new. The two other programs of the runtime measured there,
  `iocopy` and `iosmall`, take 0.89 and 0.99 of the time of C, and a
  program starts 2 microseconds later than without the runtime, 50
  against 48.
- [x] A runtime written in AIL as source the compiler compiles with
  every program (2026-11-26), in place of the image as a second form of
  output that the plan had: a service is then a function of the program,
  with no table between, and a short one is compiled in place of its
  call, which an image could not be. `rt/linux-x86_64/rt.aiw` is
  compiled in front of the program and `state.aiw` behind it; the
  compiler has both as data. A service with a function `rt_<name>`
  there is a call of it, and any other an entry of the C image, so the
  two parts run side by side while services move. `exit`, `args`,
  `close`, `read` and `write` are in AIL: `rt write` in a function is
  the system call alone. The statement `stack` is for the first line of
  the runtime. `make test` passes with the AIL part and, but for the
  one case that expects a service in place, with
  `make RTAIL=/dev/null`.

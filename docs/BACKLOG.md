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
- [x] `lib/std/sha.aiw`: SHA-256 (user, 2026-11-24: it was written in
  aildb, for the identity of an embedding provider and the keys of the
  vectors an index keeps, and belongs here). `sha256` of bytes given at
  once, `shainit`, `shaadd` and `shaend` for bytes given in pieces, and
  `shahex`. Compared with `hashlib.sha256` of Python 3 for known texts,
  a million bytes, every length from 0 to 130 and 1000 bytes cut into
  pieces of every length from 1 to 130: no difference.
  `tests/lib_sha_sums`.
- [x] The version 0.1.2 of AIL (user, 2026-11-24), the first with
  `lib/std/sha.aiw`, `procheld` of `lib/std/proc.aiw` and float
  literals, the pull requests 32, 33 and 34: `Ailfile` says it and the
  tag `v0.1.2` names the merge of it, so that a package asks for them
  with `ail 0.1.2`.

## Float literals

- [x] Float literals (user's proposal, from aildb, 2026-11-21; asked for
  on 2026-11-24): `1.5`, `-0.25`, `2.5e-3`, digits on both sides of a
  dot and an exponent or none, are the 64 bits of the nearest double
  wherever a number is read, a `const` too. `rdflt` of
  `compiler/lex.aiw` finds one and `numdouble` of `lib/std/num.aiw`,
  which the compiler now uses, rounds it; one beyond every double is
  `number too big`. No new seed. `tests/float_literal*`, the bits
  against `float` of Python.

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
- [x] Paths, memory and threads in AIL (2026-11-26): `open`, `mkdir`,
  `unlink`, `rmdir`, `rename`, `names`, `pipeerr`; `alloc` and `free`,
  the same blocks and lists as in C, with the class of a block from a
  table of 64 bytes; `wait`, `wake`, `cpus` and `thread`, whose new
  thread comes out of the system call in the middle of an AIL function
  and has all it needs in registers. The statement `zero`, the string
  instruction that clears bytes, is new for it. On the programs of
  ail-bench the AIL services take 0.87 (`iocopy`), 0.98 (`iosmall`) and
  0.99 (`allocs`) of the time of C; the C services took 0.88, 0.99 and
  1.03.
- [x] The runtime in AIL alone (2026-11-26). Time, the poller, the
  sockets and the processes were written in AIL, and the whole suite
  passed with the AIL services and with the C ones. Then the C runtime
  was removed: no image, no `cc` in `make`. An executable is the header,
  the code of `rt.aiw` and the program. The first line of the runtime
  does nothing in a program that never asks for the stack of its start,
  the second jumps over its functions, and the state is no memory of a
  program that calls no service that keeps something there: `hello`
  starts in 48.2 to 48.4 microseconds against 47.9 before there was a
  runtime, where the C runtime cost two. `iocopy`, `iosmall` and
  `allocs` of ail-bench take 0.85, 0.98 and 0.99 of the time of C.
- [x] Seed 8 (2026-11-26): the compiler with the runtime in AIL. It is
  built from its revision alone, with no C compiler, and the build from
  it gives the same file. The releases `seed-7` (with its image
  `rt-7`) and `seed-8` are to be published before the branch can be
  built elsewhere; until then the build needs the local file
  `seed/ailc-8`.
- [x] Workloads of the runtime in ail-bench (2026-11-26, its branch
  `runtime`): `iocopy`, `iosmall` and `allocs` beside C programs at
  `-O3`, a table "Runtime" of `tools/perf`, and the start of `hello`
  against the revision before the runtime. Measured with no runtime,
  with the C one and with the AIL one; `docs/performance.md` there has
  the figures.
- [x] The tests on the runtime (2026-11-26): 571 tests that end with a
  status, write or read by `sys` do so by `rt exit`, `rt write`,
  `rt read` and `rt close`, with their expected outputs as they were,
  so that they can run where the system calls of x86-64 Linux are not.
  The tests named `sys_*`, those that must fail to compile, the
  generated ones and four that depend on what a raw system call leaves
  in a register keep `sys`; 150 test sources still have one, for what
  only Linux has.
- [x] The target of the compiler as a package, and the statements
  `ccall` and `base` (2026-11-26), for a second platform. What the
  compiler knows of x86-64 Linux beyond the instructions is in
  `compiler/linux-x86_64/target.aiw`, named by the source as a package
  that the build chooses; the compiler writes the same bytes as before.
  `ccall` calls a function by the C convention of the platform with
  its values at an address and the stack at a multiple of 16, which is
  how the clock of the kernel's page is called now, and `base` is the
  address an executable is loaded at.
- [x] Windows on x86-64, the second platform, as far as the compiler
  itself (2026-11-26). `build/ailc-windows-x86_64` runs on Linux and
  writes executables of Windows: a header and import tables in two
  pages, the code behind them, the memory of the program a section
  without bytes, every byte of the file at the same place in memory.
  `rt/windows-x86_64/rt.aiw` has `exit`, `args`, `alloc`, `free`,
  `open`, `close`, `read`, `write` and `pipeerr`, each by functions of
  Windows called with `ccall`. Under Wine `hello.exe` writes its line,
  and the compiler compiled for Windows compiles its own source to the
  file it is. 522 tests of the suite give their output and status
  there. `tests/win.sh` is in `make test` and is skipped without wine.
  The interface held: no service changed its values, its results or
  its errors for Windows.
- [x] Directories, time, threads and processes on Windows (2026-11-26):
  `mkdir`, `unlink`, `rmdir`, `rename`, `names` as a search of the
  path of a directory; `clock` and `sleep`; `cpus`, `wait` and `wake`
  on `WaitOnAddress`, `thread` on a thread of Windows that enters AIL
  through fifteen bytes of code, since Windows calls with another
  convention; `start`, which writes the arguments as one line, quoted
  so that `args` reads them as they were, with the three handles and
  an environment, and holds a child in a job; `reap`; `pin`. 567 tests
  of the suite pass under Wine, and `tests/win/start.aiw` starts
  programs of Windows. [runtime.md](runtime.md) lists where a service
  cannot be on Windows what it is on Linux.
- [x] Sockets and a poller on Windows (2026-11-26), the last of its
  services: sockets of Winsock as descriptors of the runtime, a poller
  made of `WSAPoll` that says once when a socket becomes ready, by a
  note of what it has said that a read, a write or an accept takes away
  when it finds the socket not ready, and a waker that is a socket
  connected to itself. The tasks, `lib/async` and the HTTP client and
  server pass their tests under Wine: 579 tests in all, tried twice
  before one has failed, since a start under Wine fails now and then.
  The services held as they were written for Linux; what is not the
  same behind them is listed in [runtime.md](runtime.md).
- [x] `reap` on Linux takes only a child (2026-11-26): with a limit of
  time it asked for a descriptor of the process, which the kernel gives
  for any process, and killed the number when the time was over, so a
  number that was no child was killed. It now asks the kernel first
  whether the number is a child that runs, kills through the
  descriptor, which is that child whatever got its number since, and
  takes no number below 1. `tests/rt_reap_not_child`.
- [x] `start` on Linux keeps a descriptor given as its own number
  (2026-11-26): one opened to be closed at the start of a program was
  closed in the child when it already had the number it was given as,
  since nothing was copied. The mark is taken away there.
  `tests/rt_start_cloexec`.
- [x] Descriptors and pollers on Windows that threads share
  (2026-11-26): two threads that opened at once could get one number,
  since it was taken only when Windows had given the handle; it is now
  taken with `cas` first and given back last by `close`. What a poller
  watched was kept with the socket, so a second poller changed the tag,
  ended the watch or took the event of the first; each poller now has a
  record of its own. `tests/rt_open_threads`, `tests/rt_poll_two`,
  which `tests/win.sh` always runs.
- [x] `start` on Windows gives a child its three handles alone
  (2026-11-26): it made the handles of this process inheritable and
  left them so, so a later child got them too; and it put a held child
  in its job after it ran, without looking whether that worked. The
  child now gets copies made for it and a list that names them, and is
  in the job by the same list from the moment it is made; a job that
  cannot be made or a descriptor that is not open is a child that ends
  with 127. `tests/win/inherit.aiw`, `tests/win/holder.aiw`.
- [x] `reap` on Linux asks one process for everything (2026-11-26):
  the kernel reads 32 bits of the number of a child and 31 of a time,
  so a number above that was any child or another one, and a long time
  was none; and the question whether a number is a child and the
  descriptor for it were two calls, between which another thread could
  take the child and the number go to another process. A number above
  2^31-1 is now no child, a long time is waited for in pieces counted
  from the start, and the descriptor is had first and asked whether it
  is a child, whether it has ended and to take it (`waitid`). Where the
  kernel gives no descriptor the signal goes to the number under the
  lock that every taking of a child holds, which is done after the
  waiting. `tests/rt_reap_wide`.
- [x] Pollers on Windows that share a waker, and threads at one poller
  (2026-11-26): the poller that reported a waker emptied its socket,
  so a second poller that watched it was not told; and what a poller
  notes of a socket was read and written back with nothing between, so
  a watch that had just ended could come back, and an answer of
  Windows could get the tag of a later watch. The record of a poller
  has a lock and a number for each watch, a poller a socket of its own
  that ends its wait, and `wakeup` notes the waker in every poller
  that watches it. `tests/rt_poll_shared`, which `tests/win.sh` always
  runs.
- [x] `reap` on Linux keeps a child for the thread that waits for it
  (2026-11-26): where the wait was by the number, another thread could
  take the child between two questions and the number go to a new
  child, which was then taken or killed; and a signal the kernel
  refused was not noticed, so the child was waited for without limit
  and said to have been killed whatever it ended with. Each `reap`
  now puts its number in a list of the runtime for as long as it
  lasts, and a number in the list is no child to another thread, so
  what has the number is one child from the first question to the
  signal; nothing is taken under a lock any more. A refused signal is
  the result, with the child left, and a child that ended by itself
  before the signal gives what it ended with. `tests/rt_reap_two`,
  `tests/rt_reap_denied`.
- [x] A watch on Windows that outlived its socket, and the time of
  `reap` there (2026-11-26): `watch` asked what the descriptor was
  before it had the record of the poller, so a close between the two
  left a watch on a number that the next descriptor got; and `reap`
  gave its time to Windows, which reads 32 bits of it. `watch` now
  asks under the lock of the record, where a close always takes its
  descriptor out before the number is free, and `reap` waits in pieces
  counted from the start, says so if Windows refuses to end the child,
  and takes one that has ended with what it ended with.
  `tests/win/stale.aiw`, `tests/rt_watch_close`, `tests/rt_reap_long`.
- [x] `reap` on Windows gives a child to one thread (2026-11-26): two
  threads that reaped one child both waited for its handle, and the
  first to finish closed it under the other, which then read a status
  of 0 from a call that had failed, or asked about whatever the handle
  had become. `start` now puts each child in a list of the runtime,
  `reap` takes one that is there and that no other `reap` has, -1001
  otherwise, and takes it out of the list before the handle is closed;
  a status that Windows does not give is its error. The source of the
  services may be 48 KiB, since that of Windows passed 32.
  `tests/rt_reap_many`, which `tests/win.sh` always runs: eight
  threads, of which five or four got 0 before.
- [x] `reap` on Linux sends no signal to a number the kernel may have
  given away (2026-11-26): without a descriptor of the child the wait
  asks by the number, which stays the child's only while nothing but
  `reap` takes children; a process that ignores `SIGCHLD` has the
  kernel take them, so the number could be another process when the
  time was over. There `reap` now returns the error that kept the
  descriptor away and leaves the child; `docs/runtime.md` says what
  the promise needs. `tests/rt_reap_auto`.
- [x] `reap` on Linux sends no signal by a number when the kernel does
  not say who takes children (2026-11-26): the check before the signal
  read what the process does with `SIGCHLD` and not whether the kernel
  had answered, so under a filter that refuses `rt_sigaction` the
  zeros it had put there read as a process that takes its children
  itself, and the child was killed by its number. A question that
  fails is now the case in which no signal is sent, and
  `docs/runtime.md` says that the answer is taken once, so a program
  must not change it during such a `reap`. `tests/rt_reap_blind`.
- [x] A child on Windows is a number of the runtime, not its handle
  (2026-11-26): `start` returned the handle, which `reap` closes and
  Windows gives to the next child, so the number of a child that was
  taken named a later one, and a `reap` with it took that. `start` now
  gives a number counted from 2 that no other child gets, kept with
  the handle in the list of the children, which is all that knows the
  handle. `tests/rt_reap_again`, which `tests/win.sh` always runs: the
  second child was taken by the number of the first before.
- [x] `tests/win.sh` fails when a test it always runs does not compile
  (2026-11-26): the runner left out every test the compiler for
  Windows refused, without a word, and only asked that one program
  had run, so a change that broke the compiling of `rt_reap_again`
  left the suite green. A test of that list which does not compile is
  now a failure, with what the compiler said; the other tests are
  still left out, since the suite is those the compiler compiles.
  Checked with a compiler that refuses that one source.
- [x] `tests/win.sh` fails when a test it always runs is not there to
  run (2026-11-26): the list of those tests was only looked at for a
  test the loop over `tests/*.out` had found and no filter had left
  out, so without `tests/rt_reap_again.out` the test was not run and
  the suite stayed green. Before the loop every name of the list must
  now have its `.out` and its source, no `sys` and no line in
  `tests/win.skip`, or the suite fails and says which. Checked in a
  copy with each of the four made untrue.
- [x] The compiler for Windows refuses a program whose image Windows
  does not load (2026-11-26): the last check of the size of an image
  was 2 GiB on both targets, so a program with buffers up to that
  compiled for Windows, which loads no image above 0x77000000 bytes.
  The limit is now `tmax` of the target file, 2 GiB less one byte on
  Linux as before and 0x77000000 for Windows, and `buffers too big`
  above it. `tests/win.sh` compiles a program whose image is that size
  and reads it in the header, and requires one a page above to be
  refused.
- [x] `docs/runtime.md` says what to do with a program Microsoft
  Defender takes wrongly (2026-11-26): it named a signature and an
  excluded directory beside a report to Microsoft, as if either
  answered the verdict. A signature says who published a file and that
  it is unchanged, and signed files are taken too; an excluded
  directory is scanned no more. The two detections stay as what one
  scan recorded, and the guide points to the submission of the file
  that was flagged.
- [x] A path too long for Windows is the error -36 there
  (2026-11-26): `tests/lib_file_errors` passed under Wine and printed
  2, no such file, for its path of 4095 bytes on Windows, which
  answers a path of 260 bytes or more, with the directory of the
  process, as one that is not there. After that answer `open`,
  `mkdir`, `unlink`, `rmdir` and `rename` now ask `GetFullPathNameA`
  (`rt_long`), which fails for such a path with the error that is -36.
  Checked on Windows 11, where the test now gives its output.
- [x] `tests/rt_pipe_signal` passes where the signal is ignored
  (2026-11-26): it expected a write to a pipe that nobody reads to end
  the process, which is what the signal does by default. The runner of
  GitHub starts `make test` with the signal ignored, a child keeps
  that, and the write gave the error, so the test failed there alone.
  It now sets the default with `rt_sigaction` before the write.
- [x] Six tests of the separators end their lines with CRLF again
  (2026-11-26): the conversion of the tests from `sys` to `rt` wrote
  `data_tabs_crlf`, `fn_separators`, `gvar_tabs_comment`,
  `if_with_comment_tabs`, `separators_tab_crlf` and `use_tab_crlf`
  with LF alone, so they still passed and no longer tested a CR
  before the LF. Every line of them has its CR back, the lines with
  `rt` included.
- [x] The version 0.2.0 of AIL (user, 2026-11-26), the first with the
  runtime, the pull request 36: the statement `rt` and its services,
  `alloc`, `free` and `args` as services, the libraries without `sys`,
  and the compiler for Windows on x86-64. `Ailfile` says it and the
  tag `v0.2.0` names the merge of it, so that a package asks for them
  with `ail 0.2.0`. A second number, which the user set with the plan
  of the runtime: every executable is another file than 0.1.2 wrote.
  The items of the runtime that are open stay in `docs/TODO.md`.
- [x] The command `ail` and the tools without `sys` (2026-11-26):
  `cli/` had 91 such statements and `tools/` 12, half of them `close`
  and `exit`, the rest things the runtime had no service for. Nine
  services and a flag say what was meant, each in the runtime of Linux
  and of Windows: `start` with the flag 2, a child that leads a group
  which ends when `reap` has taken it and when its starter ends (on
  Linux the pipes, the gate and the watcher that `tlrunenv` made,
  moved into `rt_group`, with a watcher that keeps no other descriptor;
  on Windows a job of its own); `lock`, the lock of a directory (the
  kernel's on Linux, the lock of a file on Windows); `cwd`, `chdir` and
  `real`, the directory of the process and a directory as the system
  names it; `self`, the path of the executable; `become`, a program in
  place of the process; `kind`, whether a path is a file, a directory
  or a link; `pid`; and `chmod` of an open file. The function that
  guards the memory of the runtime is `rt_mlock` since, `lock` being a
  service. `tests/rt.sh` holds `cli/` and `tools/` free of `sys` as it
  held `lib/`; the tests `rt_cwd`, `rt_self`, `rt_kind`, `rt_chmod`,
  `rt_pid`, `rt_lock`, `rt_become` and `rt_group` pass on Linux and
  under Wine, where `tests/win.sh` always runs them, and
  `tests/cli.sh` passes unchanged. The compiler for Windows compiles
  the command and every tool; running the command there is in
  `docs/TODO.md`.
- [x] The version 0.2.1 of AIL (user, 2026-11-26), the first with
  those nine services and the flag 2 of `start`, the pull request 38:
  `Ailfile` says it and the tag `v0.2.1` names the merge of it, so
  that a package asks for them with `ail 0.2.1`. A third number, since
  what was written before it compiles and runs as it did.
- [x] Six services for a file, which a program had to ask of Linux
  with `sys` and so could not ask on Windows (2026-11-26, for aildb,
  whose user wants it there): `seek`, the place of a file; `pwrite`, a
  write at a place; `truncate`, a file cut or made longer; `sync`, a
  file or a directory flushed; `stat` and `fstat`, the kind, the size
  and the two times of what is at a path, a link not followed, or
  behind a descriptor. On Windows they call `SetFilePointerEx`,
  `WriteFile` with a place, `SetFileInformationByHandle`,
  `FlushFileBuffers`, `GetFileInformationByHandleEx` and
  `GetFileSizeEx`; `docs/runtime.md` says where they differ there. The
  tests `rt_seek` and `rt_stat` pass on Linux and under Wine, where
  `tests/win.sh` always runs them. `win_stale_watch` failed once in
  the first run of `make test`: of 40 runs under Wine it ended with
  another status 2 times with these services and 5 times without
  them, so it is a test that depends on its sleeps, as it was. A
  review of the pull request 40 at `0fd8e8e` (2026-11-27) had six
  findings, each fixed in its commit on the same branch. A place
  below zero given to `pwrite` was the end of the file to Windows,
  which wrote there: it is the error -22 as on Linux (test
  `rt_pwrite`). `fstat` of a directory asked Windows by the path the
  directory was opened with, which is another thing once the process
  is in another directory or the directory has another name: a
  descriptor of a directory has a handle there now, from `open` to
  `close`, and `fstat` asks it (test `rt_fstat_dir`). `pwrite` of
  Windows asked for the place of the file, wrote and set the place
  again, so a read of another thread between them was lost or began
  at the wrong place: it writes with a second handle of the file
  (`ReOpenFile`) and leaves the place alone, and answers -9 for a
  descriptor that may not write, which it asks of
  `NtQueryInformationFile` (test `rt_pwrite_threads`). A `pwrite`
  to a descriptor opened to write at the end wrote at the end on
  both platforms and said it had written at the place: it is the
  error -9, which Linux learns of the flags of the descriptor
  (`fcntl`) before it writes (test `rt_pwrite`). `seek` of a pipe
  was -5 on Windows, what `SetFilePointerEx` said of it: `seek` and
  `pwrite` ask the kind of the handle (`GetFileType`) and answer -29
  for what is no file on a disk (`win_pipe` of `tests/win.sh`, and
  the test `rt_seek_pipe` for Linux). And the test `rt_stat` gave
  `fstat` an address 8 bytes into its 32, so the last number was
  written behind them: every call has 32 bytes now.
  A second review, at `ab402b5` (2026-11-27), had one finding, fixed
  in a commit on the same branch. `fstat` of a pipe was 1, a plain
  file, on Windows, which says of a pipe what it says of a file when
  it is asked for the attributes: `stat` and `fstat` ask the kind of
  the handle first, as `seek` does, and give the kind 4 with no size
  and no times for a pipe, a socket and a console, the kind Linux
  gives a pipe (`win_pipe` of `tests/win.sh`, which asks `fstat` of
  its input and of its output, and the test `rt_seek_pipe` for
  Linux). On Windows 11 itself, the program of `win_pipe` run with a
  pipe at each end, it ended with 31 before the change and with 127
  after it.
- [x] The version 0.2.2 of AIL (user, 2026-11-27), the first with
  those six services, the pull request 40: `Ailfile` says it and the
  tag `v0.2.2` names the merge of it, so that a package asks for them
  with `ail 0.2.2`. A third number, since what was written before it
  compiles and runs as it did.
- [x] The service `time`, the time of day (2026-11-27): nanoseconds
  since 1970 by the clock of the system. A program had to ask Linux
  for it, with `sys clock_gettime`, and so could not ask on Windows;
  aildb notes with it when a run of its index starts. It is
  `clock_gettime` of the clock 0 on Linux and
  `GetSystemTimePreciseAsFileTime` on Windows, which counts in steps
  of 100 nanoseconds. The test `rt_time`, which is also run by
  `tests/win.sh` whatever its count.
- [x] The service `random`, bytes that nobody can guess (2026-11-27),
  which a program had to ask of Linux with `sys getrandom`: aildb
  names with them the file a snapshot is written to before it has its
  name. `getrandom` on Linux, asked again while it gives fewer bytes
  than were wanted, and `ProcessPrng` of `bcryptprimitives.dll` on
  Windows, a fifth library in the import tables, which has no error.
  The test `rt_random`, which is also run by `tests/win.sh` whatever
  its count.
- [x] The service `platform` (2026-11-27): 1 for x86-64 Linux and 2
  for x86-64 Windows, the platform the program was compiled for.
  Nothing told a program where it runs, and what differs there and is
  no service, the separator of a path, the directory of a user's
  configuration, the ending of a program's name, had to be found by
  looking at a path. The test `rt_platform`, which compares it with
  the form of the directory of the process and is also run by
  `tests/win.sh` whatever its count.
- [x] The service `trylock`, the lock that is not waited for
  (2026-11-27): the lock of `lock`, with the error -11 in place of
  the wait when a process has it. aildb ends a build with a status of
  its own when another build of the same destination runs, and asked
  Linux for that with `sys flock`. On Linux it is `flock` told not to
  wait, on Windows `LockFileEx` told to fail at once, whose error 33
  is the -11; the two services share their function in each runtime
  (`rt_locking`). A process that has the lock and asks for it again
  without waiting is refused too, on both platforms. The test
  `rt_trylock`, which is also run by `tests/win.sh` whatever its
  count.
- [x] The services `map` and `unmap`, a file as memory (2026-11-27):
  the first bytes of an open file at an address, to be read, which a
  program had to ask of Linux with `sys mmap`. aildb reads a snapshot
  so, without a copy of it. `mmap` on Linux, shared, so that what is
  written to the file afterwards is in the memory on both platforms,
  and on Windows a view of a mapping of the file
  (`CreateFileMappingA`, `MapViewOfFile`, `UnmapViewOfFile`, three
  imports). Both runtimes ask the size of the file first and refuse
  more bytes than it has, -22, which Linux would map and fault at.
  The tests `rt_map` and `rt_map_replace`: the second maps a file and
  has another process give a new file its name, and the memory is
  still the old file, on Linux and on Windows 11 itself (build 26300,
  NTFS), where the cut of a mapped file is refused, -5. Both are also
  run by `tests/win.sh` whatever its count.
- [x] A run on Windows itself (2026-11-27): `tests/win.sh all` on
  Windows 11 Pro, build 26300, started from WSL 2 with a script named
  `wine` that starts its first argument, the tree copied to NTFS. At
  `1a6f5f4` it ended with 0: the twelve named checks, the fixed point
  of the compiler among them, and 607 tests. Before that one test
  failed there, `rt_open_threads`, which opened its program by the
  name it was started by, the bare name of the file where WSL starts
  it; it asks `rt self` now. With the tree in the file system of
  Linux, a share to a program of Windows, the tests of a lock, of
  `fstat` of a directory, of `pwrite` by threads and of a rename onto
  a mapped file fail, and pass on NTFS.
  `.agents/knowledge/testing/windows-itself.md` has how it is run.
- [x] No lock of a named pipe (2026-11-27, the review of `0723385`,
  P2): `rt_locking` of Linux opened the path to read it before it
  asked for the lock, and the open of a named pipe waits for a
  writer, so `trylock` waited there, the one thing it is not to do.
  The open does not wait now (`O_NONBLOCK`), for `lock` too, and what
  it gives is asked its kind before the lock: -22 for anything but a
  directory and a plain file, a named pipe and a device among them.
  The test `rt_lock_fifo`, which makes the pipe with `sys mknod` and
  so is of Linux alone; before the change it did not end.
- [x] `time` says when the kernel does not answer (2026-11-27, the
  review of `0723385`, P3): `rt_time` of Linux read the two numbers
  whatever `clock_gettime` had returned, so a kernel that refused the
  call gave the program 0, the start of 1970, as a time. It returns
  the error now. Windows has none to give. The test
  `rt_time_refused`, of Linux alone, refuses the call with a filter
  of the process: the status was 3 before, a time of 0, and is 7.
- [x] `map` promises a later write of Linux alone (2026-11-27, the
  review of `0723385`, P2): the table said that what is written to a
  file after it was mapped is read in the memory, on every platform.
  On Windows the memory is a view (`MapViewOfFile`) and a write is
  `WriteFile`, and the documents of Windows leave open that the two
  agree. The table and the part about Windows say so, and the check
  moved from `rt_map`, which every platform runs, to
  `rt_map_written`, which `tests/win.skip` names. On Windows 11
  (build 26300, NTFS) the write was in the view when `rt_map` still
  asked, the same day.
- [x] No lock of a device on Windows (2026-11-28, the review of
  `9400a97`, P2): the table gives -22 for what is neither a directory
  nor a plain file since the item about a named pipe, and the runtime
  of Windows opened the path and asked `LockFileEx` whatever it had
  opened, so `lock` and `trylock` of `NUL` gave a descriptor, a lock
  that keeps no process out. What is opened is asked its kind
  (`GetFileType`) before the lock, and anything but a file on a disk
  is -22, the handle closed and the descriptor free again. The test
  `rt_lock_device` asks `platform` which device to name, so both
  platforms run it; on Windows 11 (build 26300, NTFS) it ended with
  24 before the change, both locks given, and with 31 after.
- [x] The version 0.2.3 of AIL (user, 2026-11-28), the first with
  those six services, the pull request 41: `Ailfile` says it and the
  tag `v0.2.3` names the merge of it, so that a package asks for them
  with `ail 0.2.3`. A third number: what was written before it
  compiles and runs as it did, but for a `lock` of a named pipe or of
  a device, which 0.2.2 took and which is the error -22 now; the
  notes of the release say so.
- [x] A file with no name, the service `anon` (2026-11-28, for step
  19 of aildb, which gives a child its input and takes its outputs in
  such files and asked Linux for them with `sys`): a descriptor to
  read and to write, empty, which a program gets only from `start`.
  On Linux it is memory (`memfd_create`); on Windows a file of the
  directory for temporary files, with a name that nobody can guess,
  which Windows removes with its last handle. The test `rt_anon`
  gives one to a child as its input and one as its output, and
  writes a place of one with `pwrite`.

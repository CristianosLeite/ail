# TODO

This backlog records current limits and the work needed to lift them. Favor
changes that reduce the token cost of real AIL programs. Keep the compiler's
fixed point and use in its source only what the pinned seed understands.
See the [roadmap](roadmap.md) for project history.

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
  which the pinned seed already supports for `compiler/tables.aw`.
  - Keep `compiler/ailc.aw` as the entry point with the shared declarations and
    parser state machine. Its states share top-level variables and labels.
    Extract whole functions along the existing section boundaries. Suggested
    files under `compiler/` are `diag.aw`, `lex.aw`, `names.aw`, `expr.aw` and
    `emit.aw` for diagnostics, token reading, name lookup, expressions and code
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

Give each tool an entry point at `tools/<name>.aw` and an executable at
`build/tools/<name>`. Build the tools with `build/ailc` after the bootstrap.
Add a `make tools` target and declare each tool's source dependencies so edits
to a shared file rebuild its callers. Have `make test` build the tools it runs.

Use the existing [`use`](language.md#use) and keep dependencies one way.
Tool entry points handle arguments, diagnostics and exit status. Put shared
token and line scanning in `tools/lib/scan.aw` and shared control-flow
analysis in `tools/lib/flow.aw`. Keep each tool's rewrite rules, generator or
reporting code with that tool. Add `lib/bytes.aw`, `lib/file.aw` and
`lib/proc.aw` for byte buffers, file I/O and child processes as callers need
them. Reuse `lib/io.aw` for arguments and output. Keep Linux syscall details
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
- [x] Add a VS Code extension for `.aw` files with syntax highlighting, block
  folding and formatting through the same AIL formatter.
- [x] Apply the convention to the examples first. Reindent the compiler in a
  separate formatting commit and verify the bootstrap fixed point.

On the ten examples, the `o200k_base` tokenizer counted 970 tokens without
indentation, 990 with one tab per level (+2.1%), and 1,024 with either two or
four spaces per level (+5.6%), excluding comments. All variants compiled to
byte-identical executables. See [token cost](tokens.md) for the corpus.

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
   [performance.md](performance.md).
   Done on 2026-11-21: the tests `lib_nd_ref_*` compare the library with
   NumPy 2.3.5 through `tests/lib/ndfix.aw`, which `tests/nd/gen.py`
   writes; `ndelem`, `ndreduce` and `ndmatmul` are timed by `perf`. The
   kernels take 3.65 times as long as the loops of C in the geometric
   mean of 14 times, 1.24 times where memory is the limit and up to 10
   times at a thousand numbers; a caller is 608 tokens against 636 in C
   ([results](performance.md#numerical-arrays-2026-11-21)).
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
   ([results](performance.md#after-the-measurements)).
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
   ([results](performance.md#array-kernels-after-the-first-round-2026-11-21)).
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
   [results](performance.md#array-kernels-after-the-first-round-2026-11-21)).
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
   ([results](performance.md#array-kernels-after-the-first-round-2026-11-21)).
9. [x] **Unroll the packed loop in matrix multiplication.** In `ndaxpy`, try
   four `pmadd` operations per iteration, followed by packed and scalar
   tails. A prototype cut single-core kernel time by 19% at side 100 and 7%
   at side 1,000. Preserve the order of `k` and compare bits for odd widths,
   views and the parallel path.
   Done on 2026-11-21: four `pmadd` a round, then pairs, then one. The
   kernel takes 19% less time at side 100, 22% at 300 and 12% at 1,000, and
   the same at 30; `tests/lib_nd_matmul_wide` compares the bits
   ([results](performance.md#array-kernels-after-the-first-round-2026-11-21)).
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
    ([results](performance.md#array-kernels-after-the-first-round-2026-11-21)).
11. [ ] **Report requested and actual matrix task counts.** With 16 result
    rows and 14 requested tasks, `ndmatmulp` uses blocks of two rows and
    creates eight tasks. Show both counts in `bench/nd/mmtasks.sh` and the
    performance table. Measure the current split before changing it. A
    prototype that distributed the extra rows across blocks reduced the
    warm-pool median from 74.7 to 58.4 microseconds in this case and
    increased it for some other shapes.
12. [x] **Validate the first parallel matrix result before reusing its
    buffer.** `bench/nd/mmtasks.aw` checks the first call's status but
    compares the output only after later calls have overwritten it.
    Compare the first result against the serial result before running
    the warm-pool calls. Keep both result checks outside the timed
    regions and verify that corrupting either result fails the benchmark.
    Done on 2026-11-21: the first result is compared before the later
    calls and the last one after them, both outside the clocks; a wrong
    double stored after either makes the benchmark print 1 and
    `mmtasks.sh` end with `differ` and the status 1.

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
[the call cost measurements](performance.md#array-kernels-after-the-first-round-2026-11-21).
The fix touches every algorithm program, so move their kernels into a
library in the same pass and leave the examples as callers.

1. [ ] **Make the clock cost the same in the three harnesses.** Compare
   three ways: time a run around nothing in each harness and write the
   total as an extra word that `perf` subtracts and reports; call
   `__vdso_clock_gettime` from AIL, found through `AT_SYSINFO_EHDR` in the
   auxiliary vector behind `args` and called with `callp`; or read the
   clock with the raw system call in C and Rust as well. For the vDSO call,
   check the argument registers, the stack alignment and which registers
   survive. Keep `harness.aw`, `harness.h` and `harness.rs` the same in
   what they time, and update `tests/algo.sh` and `perf` if the output
   gains a word. Accept the change when an empty kernel costs the same
   within a few nanoseconds in the three languages.
2. [ ] **Rerun the kernel tables the clock skewed.** The bias of a row is
   its runs times the difference per run, so it matters for the rows with
   thousands of short runs in the algorithm and array tables and not for
   those at a million elements. Rerun `build/tools/perf` with the corrected
   harness, report the old and new ratios side by side, and note in the
   earlier sections of [performance.md](performance.md) which figures
   included the clock. Leave the historical tables as measured.
3. [ ] **Move the algorithm kernels into a library.** Put the sorts
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
   in-place heap of `heapsort` relate to `lib/map.aw` and `lib/heap.aw`,
   and keep them separate where the benchmark layout differs. Add the new
   files to the Makefile prerequisites and to `tests/indent.sh`, test the
   functions on their own in `tests/lib_algo_*` (empty, single, duplicate
   and already sorted input), and document them in
   [language.md](language.md).
4. [ ] **Measure what the move changes.** Check that `place` and `lower`
   are still compiled in place at their calls, which needs the callee
   before the caller and no global name in its body. Compare kernel times
   before and after over several placements of the code, since a kernel
   moved by a few bytes varied by a fifth at 1,000 elements. Report the
   token counts of a caller and of the library separately against the C
   and Rust programs, which keep their kernels inline, and update
   [tokens.md](tokens.md).

## Algorithm benchmarks and collection APIs

Use [`isort`](../examples/isort.aw) and its [C counterpart](../bench/isort.c)
as the starting point. Pass contiguous arrays as an address and an element
count, use `load` and `store` for 64-bit values, and size runtime buffers with
`alloc`. The algorithms can use the current language and calling convention.

- [x] Add quicksort in `examples/quicksort.aw` and `bench/quicksort.c`.
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
- [x] Extend [`perf`](../tools/perf.aw) for algorithm workloads. Run equivalent
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

- [x] **Growable vector**, `lib/vec.aw`. Provide `vecreserve v n`,
  `vecpush v x`, `vecpop v`, `vecget v i` and `vecfree v`. Keep a data
  address, length and capacity in a 24-byte descriptor, with length and
  capacity in elements. Grow geometrically and reuse `bycopy` for relocation
  if useful. Define `vecreserve` in terms of total capacity and document when
  growth invalidates addresses into the vector.
- [x] **Bounded queue**, `lib/queue.aw`. Provide `queueinit q n`,
  `queuepush q x`, `queuepop q` and `queuefree q`. Allocate a ring of `n`
  values with a head and count. Return failure on full and empty operations.
  Use [`lib/async/chan.aw`](../lib/async/chan.aw) as a layout reference and keep
  the queue usable in synchronous programs through its own functions.
- [x] **Min-heap**, `lib/heap.aw`. Provide `heappush h x`, `heappeek h`,
  `heappop h` and `heapfree h`. Store values in a growable array, using the
  vector storage if it fits the callers. Sift up on insertion and down on
  removal. Use the [timer heap](../lib/async/time.aw) as a reference. Keep
  the in-place max-heap operations of heapsort in its benchmark.
- [x] **Hash map**, `lib/map.aw`. Provide `mapput m k v`, `mapget m k`,
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
  [`performance.md`](performance.md).

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
order. See [benchmark method](performance.md#method).

1. [x] **Emit scaled indexes in loads and stores.** In
   [`xaddr` and the memory operand encoder](../compiler/expr.aw), fold a
   register index scaled by 2, 4 or 8 into the x86-64 memory operand when it
   fits. With both operands in registers, `load p+i*8` went from `imul`,
   `add` and `mov` to a single indexed `mov`, reducing the sequence from
   10 to 4 bytes. The scaled-index change alone brought the mean AIL/C kernel
   ratio from 1.753 to 1.639. See the
   [scaled index measurements](performance.md#scaled-indexes-2026-11-20).
2. [x] **Reduce stack accesses in hot loops and evaluate selective inlining.**
   Inspect [`alloc`](../compiler/emit.aw) and the generated code for
   [`hashtab`](../examples/hashtab.aw) before expanding inlining. At 1,000
   keys, manually inlining `place` lowered insertion and successful lookup
   times by 12–20%, while unsuccessful lookups on random keys took 30% longer
   and the loop gained stack accesses. Measure all three operations at 1,000
   and 1,000,000 keys with random and duplicate-heavy inputs. Compare the
   generated stack accesses and code size as well as elapsed time.
   Done on 2026-11-20: registers go to the variables that the loops mention
   most, and inlining `place` by hand is then faster in 11 of the 12 kernel
   times ([results](performance.md#registers-by-weight-2026-11-20)).
3. [x] **Find a profitable lowering for compound loop conditions.** Use
   [`mergesort`](../examples/mergesort.aw) as a test case. A prototype split
   its two bounds comparisons into separate branches, cutting kernel time
   by up to 7% on sorted and reversed inputs while increasing it by up to
   18% on small random or duplicate-heavy inputs. Preserve AIL's eager
   evaluation semantics, including possible traps, and compare alternative
   branch layouts across all four input shapes and both input sizes.
   Done on 2026-11-20: a jump for each comparison before the loop and at its
   end, which was faster in all eight inputs once the registers went by
   weight ([results](performance.md#two-comparisons-in-a-while-2026-11-20)).
4. [x] **Tune task granularity before changing the pool.** Using medians from
   three runs per configuration (`build/tools/par --runs 3`), 160 tasks at
   20 threads gave a 10.21x speedup for `collatz`, 10.86x for `primes` and
   3.35x for `memsum`.
   At 20 threads, `memsum` took 62.5 ms with 200 tasks per pass and 374 ms
   with 20,000. All three workloads lost to their sequential versions at a
   million tasks. Sweep batch sizes across worker counts and use the results
   to document useful starting sizes for CPU-bound and memory-bound work.
   [Task benchmark method](performance.md#tasks-2026-11-20)
   Done on 2026-11-20: `build/tools/par --grid` times every pair; the sizes
   to start from are in
   [the table and its reading](performance.md#the-size-of-a-task-at-each-number-of-threads)
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
   ([results](performance.md#calls-compiled-in-place-2026-11-20)). The
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
   ([results](performance.md#the-probe-of-hashtab-in-words-2026-11-20)).

## Redesign

From `REDESIGN.md`; one commit per item.

- [x] Keep the arithmetic benchmark and its timing script in the repository.
- [x] Add CPU-bound workloads to the corpus: `sieve`, `collatz`, `fnv`, `isort`.
- [x] Record the first seed of the compiler in a manifest and release it.
- [x] Build the compiler from the pinned seed, in three generations.
- [x] Make `compiler/tables.aw` its own source, checked by form and by bytes.
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

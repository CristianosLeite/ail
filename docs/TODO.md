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
  which the pinned seed already supports for `compiler/tables.ai`.
  - Keep `compiler/ailc.ai` as the entry point with the shared declarations and
    parser state machine. Its states share top-level variables and labels.
    Extract whole functions along the existing section boundaries. Suggested
    files under `compiler/` are `diag.ai`, `lex.ai`, `names.ai`, `expr.ai` and
    `emit.ai` for diagnostics, token reading, name lookup, expressions and code
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

Give each tool an entry point at `tools/<name>.ai` and an executable at
`build/tools/<name>`. Build the tools with `build/ailc` after the bootstrap.
Add a `make tools` target and declare each tool's source dependencies so edits
to a shared file rebuild its callers. Have `make test` build the tools it runs.

Use the existing [`use`](language.md#use) and keep dependencies one way.
Tool entry points handle arguments, diagnostics and exit status. Put shared
token and line scanning in `tools/lib/scan.ai` and shared control-flow
analysis in `tools/lib/flow.ai`. Keep each tool's rewrite rules, generator or
reporting code with that tool. Add `lib/bytes.ai`, `lib/file.ai` and
`lib/proc.ai` for byte buffers, file I/O and child processes as callers need
them. Reuse `lib/io.ai` for arguments and output. Keep Linux syscall details
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
- [ ] Write an AIL formatter that changes only leading spaces and tabs. Add
  `--check` to report indentation violations without rewriting files, as the
  first lint rule. Verify that formatting is idempotent and that formatted
  examples compile to the same bytes.
- [ ] Add a VS Code extension for `.ai` files with syntax highlighting, block
  folding and formatting through the same AIL formatter.
- [ ] Apply the convention to the examples first. Reindent the compiler in a
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

## Redesign

From `REDESIGN.md`; one commit per item.

- [x] Keep the arithmetic benchmark and its timing script in the repository.
- [x] Add CPU-bound workloads to the corpus: `sieve`, `collatz`, `fnv`, `isort`.
- [x] Record the first seed of the compiler in a manifest and release it.
- [x] Build the compiler from the pinned seed, in three generations.
- [x] Make `compiler/tables.ai` its own source, checked by form and by bytes.
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

# TODO

This backlog records current limits and the work needed to lift them. Favor
changes that reduce the token cost of real AIL programs. Implement compiler
behavior changes in both stages and keep byte-for-byte parity and the stage1
bootstrap fixed point. See the [roadmap](docs/roadmap.md) for project history.

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
- [ ] Evaluate additional targets and interoperability. The compiler and its
  output are x86-64 Linux only. Generated programs are standalone ELF64 files
  without ELF sections, symbols or dynamic linking, and AIL calls use an
  internal calling convention. Consider linkable objects and a platform ABI.
- [ ] Report source locations and specific causes for compile errors, including
  the original use site of unresolved names. Today diagnostics are one line
  without a location. Evaluate source maps or debug metadata for runtime faults.
- [ ] Generate common compiler tables from a single definition. Stage0 declares
  the ELF template, opcode rows and register data in assembly. Stage1 recreates
  them with decimal words and manually maintained offsets.
- [ ] Add differential fuzzing and independent checks of emitted bytes, including
  every displacement at fixup-table capacity. The existing parity suite checks
  both compilers against one another and checks the bootstrap fixed point.
- [ ] Automate the check that a failed example build leaves no up-to-date target.
- [x] Measure token cost with a real tokenizer on equivalent AIL, C, Rust and
  assembly programs. Use the results to guide syntax choices.

Keep the hardware-oriented syntax and use measured token cost to decide where
to relax grammar rules. One statement per line, ASCII identifiers, explicit
`as` captures and the lack of classes and objects are current design choices.

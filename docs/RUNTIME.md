# AIL's second redesign: a portable runtime

The [first redesign](REDESIGN.md) introduced expressions and structured control
flow and established the seed-based build. The second moves platform services
behind a runtime so AIL can run on more systems. The performance goal is for AIL
programs to match or beat equivalent optimized C programs, including the cost
of any runtime calls they make.

## 1. Build the Linux runtime in C

Start on Linux x86-64, the platform the compiler already targets. Define how
generated programs start and call the runtime, including argument and result
passing and how errors are reported. Begin with process startup, arguments,
exit, allocation, and basic file and stream I/O. Compile and run an example
that writes through the runtime, then run the compiler itself through the same
interface. Check its diagnostics and I/O behavior and verify that it still
reaches a byte-identical self-compilation with the pinned seed.

Add platform operations as their callers need them. Keep portable algorithms,
collections, and scheduling logic in AIL. The runtime supplies the primitives
they need, including clocks, threads, waiting and waking, and socket I/O.
Linux-specific operations such as `clone`, `futex`, and `epoll` belong behind
that interface. Keep `sys` available for programs that deliberately depend on
the target's syscall ABI.

## 2. Migrate the runtime to AIL

Use the C implementation as a reference while replacing its services with AIL
one at a time. Run the same tests against both implementations and compare their
observable behavior and costs. Add compiler or language support where the AIL
implementation needs it. Keep the compiler sources buildable by the pinned seed
throughout the migration.

Use a second platform to check that the interface holds up. The runtime provides
that platform's services, and the compiler must also produce code for its
instruction set, executable format, and calling conventions. Bring up a small
program there first, then use the compiler's own build and test suite to check
the port.

## 3. Optimize the runtime, compiler, and language together

Measure from the first C runtime onward. Use `ail-bench` to compare equivalent
AIL and C programs compiled at `-O3` on the same hardware, with the same inputs
and validated results. Report each workload's timings and run-to-run variation.
Measure startup and I/O separately from sustained computation so changes in
runtime overhead and generated code are visible. Keep tracking source token
counts when changing the language.

When AIL falls behind, profile the workload and disassemble the hot paths in
both executables. Compare instruction selection, register spills, memory access,
and call overhead. Reconstruct promising sequences in small AIL or assembly
experiments and measure them before changing the runtime, compiler, or language.
Verify those changes with semantic tests and, where instruction encodings change,
independent byte checks. Rerun the benchmarks and the compiler's bootstrap check
after each change that affects generated code.

# AIL redesign

AIL should take fewer source tokens than Rust for equivalent programs, let authors express arithmetic and control flow directly, and approach optimized C on CPU-bound workloads. The compiler written in AIL, currently `stage1/ailc.aw`, will become the sole maintained compiler. A released copy of that compiler will bootstrap a clean checkout.

## Baseline

| Benchmark | AIL | C | Rust | Assembly |
| --- | ---: | ---: | ---: | ---: |
| Source tokens in the five repository examples | 382 | 342 | 344 | 696 |
| Source tokens in the arithmetic benchmark | 114 | 106 | 120 | 229 |
| Total source tokens | 496 | 448 | 464 | 925 |
| Arithmetic benchmark, median elapsed time | 134.16 ms | 131.85 ms | 132.55 ms | 131.90 ms |

The token counts use `o200k_base`, with comments and blank lines removed. The arithmetic benchmark performs 100 million dependent iterations of a 64-bit recurrence using shift, XOR, multiplication and addition, with input read at runtime and the final value written out. These timings are from one Linux x86-64 machine. The five short programs also showed a startup advantage for the direct-syscall AIL and assembly executables. Track startup separately from sustained computation.

## Source language

- Add infix expressions in assignments, conditions and arguments. Use conventional precedence with parentheses for grouping. Use short assignment syntax and infer a local variable on its first assignment under the existing definite-assignment rules.
- Reuse `if`, `else` and `end` with expression conditions. Add a `while` block so a loop can express its termination condition directly. Keep labels and jumps available for code that needs them.
- Keep explicit memory widths, 64-bit wrapping arithmetic, signed and unsigned operations, and direct Linux syscalls. Evaluate expression operands and arguments from left to right. Preserve the existing address-and-length expansion for string arguments where supported.
- Keep existing statement forms during the migration. Convert the examples, library and compiler in stages. Use equivalent source and observable behavior when comparing the old and new forms.

For example, the decimal digit extraction in `count` could become:

```text
storeb out + 1, 48 + n / 100 % 10
```

The arithmetic benchmark could use:

```text
while i
    x = (x ^ (x >> 13)) * 1664525 + 1013904223
    i = i - 1
end
```

These sketches use a comma to separate expression arguments and preserve spaces for binary operators. Finalize argument boundaries and precedence after parsing and counting several equivalent examples.

## Code generation

Parse expressions into a compact intermediate representation and lower them together. Start within each statement and condition, reusing the existing variable allocator, x86-64 encoders, fixups and ELF writer. Extend analysis across statements where measurements show that expression lowering leaves avoidable work in a hot loop.

1. Fold constant expressions according to AIL's wrapping and signedness rules. Preserve observable traps and the order of memory operations, calls and syscalls.
2. Select x86-64 immediate forms where they fit. The measured loop loaded `13` into a register on every iteration. It can use the immediate form of `shr`. Apply the same principle to multiplication, addition and comparisons.
3. Keep intermediate values in registers until their last use. Coalesce redundant moves and use comparison or arithmetic flags directly for branches when the flags express the required condition.
4. Inspect hot-loop disassembly alongside timings. Add independent expected-byte checks for instruction forms and semantic tests for precedence, evaluation order, overflow, traps and definite assignment.

## Bootstrap with the AIL compiler

1. Build the current stage1 with stage0 one last time to establish the first seed. Rebuild stage1 with that seed and check byte-for-byte equality before publishing the seed as a Linux x86-64 release artifact. Record its source revision and SHA-256 in a versioned manifest.
2. Make the normal build use the pinned seed or a local copy with the manifest's checksum. Build the current sources into `build/ailc`, then use that compiler to rebuild the same sources and check that the two outputs match. Verify this flow in a fresh checkout with an empty build directory. Keep writing compiler outputs via temporary files so a failed build leaves the previous executable intact.
3. Make `stage1/tables.aw` the source of truth for stage1's tables. Move validation to tests of the table contents and emitted instructions. Remove `tools/tables.sh` and the assembly-dependent generation once the new checks cover their role.
4. Run the language, I/O and build tests with the current compiler. Retain the independent byte tests and the self-compilation check. Replace stage0 differential fuzzing with comparisons that have a valid shared language or an independent expected result. For instance, compare old and new syntax on generated programs with known results. Update the Makefile, documentation and agent instructions before removing `stage0/ailc.s` from the active tree.
5. Introduce new syntax in compiler sources only after a released seed can parse it. First add the compiler support using syntax the current seed understands, release and pin that compiler, then migrate the compiler source. Keep earlier seed artifacts linked to their source revisions so historical releases can still be rebuilt.

## Acceptance criteria

- **Source cost.** Total AIL tokens fall below Rust on an expanded, fixed corpus with comparable functionality. Keep the existing six programs, add workloads that exercise arithmetic, control flow and memory access, and report every program so that large regressions remain visible.
- **CPU performance.** Aim for parity with C built at `-O3`. As an initial threshold, require AIL's geometric mean elapsed time across the CPU-bound workloads to be within 5% of C and report any workload more than 10% slower. Use runtime inputs and check every result before timing. Record compiler flags, hardware and run-to-run variation. Report startup and E/S timings separately.
- **Authoring effort.** Use the new syntax in `count` and the arithmetic benchmark to check that expressions remove source-level temporaries and that loops can be written without manual jumps. Migrate representative stage1 routines to test the syntax on compiler code.
- **Bootstrap.** A clean checkout builds, runs the tests and reaches a byte-identical self-compilation using the pinned stage1 seed after stage0 is removed.

Establish the seed-based build first, then add the expression frontend and instruction selection. Port the benchmarks and measure them before rewriting the compiler source in the new syntax.

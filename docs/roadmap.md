# Roadmap

The goal of the proof of concept is a language that is cheap in tokens for an AI to write, compiled by a compiler written in that same language.

## Done

- Stage0 compiler in assembly that emits ELF64 directly.
- `sys`, a raw syscall with integer and string arguments.
- Register-backed variables: `as name` keeps a statement's result, and a variable can be passed as an argument.
- Assignment and arithmetic: `set`, `add`, `sub`, `mul`, `div`, `mod`, `and`, `or`, `xor`, `shl`, `shr`.
- Comparisons: `eq`, `ne`, `lt`, `le`, `gt`, `ge` keep `1` or `0` in a variable, unsigned.
- Memory access: `buf` reserves writable memory in a second ELF segment; `load`, `loadb`, `store` and `storeb` read and write 64-bit values and bytes.
- Control flow: `label`, `jmp`, `jz` and `jnz`, with forward jumps patched from a fixup list at the end of the single pass.
- Functions: `fn` ... `end`, `call` and `ret`, with up to 64 parameters, variables and labels local to each function, recursion and forward calls.
- Stage1: the compiler written in AIL (`stage1/ailc.ai`) with the same behaviour as stage0. Stage0 built it, it builds itself, and the two outputs are byte-identical.
- One compiler (2026-11-20): the build starts from a released copy of stage1, a seed pinned by checksum in `seed/MANIFEST`, the tables of stage1 are their own source, the tests stand without a second compiler, and stage0 is removed.
- Hello world, and a test runner whose tests can expect output, an exit status or a compile error.

## Next: develop the language in AIL

The language is developed in the compiler written in AIL, the only one since 2026-11-20. A new feature that the compiler itself is to use is implemented first in the language the pinned seed understands; then a seed is released, and the source may use the feature ([details](compiler.md#building-it)). Writing the compiler in AIL needed no change to the language, and showed where it costs most. In rough order of value:

1. **Constant data** (done): `data` names read-only bytes, a string is a value in every statement and `len` gives a length. Stage1 keeps its tables that way.
2. **More global names** (done): any number of buffers, `var` for global scalars and `const` for named numbers.
3. **Wider integers** (done): 64-bit, negative and hexadecimal literals, and 16- and 32-bit memory accesses.
4. **More than six variables per function** (done): 64 per scope; a function reuses registers whose variable is done and spills to the stack.

## Next: expressions and generated code

`REDESIGN.md` sets the goals: fewer tokens than Rust on the ten programs of the corpus, arithmetic and control flow written directly, and elapsed time on CPU-bound programs within 5% of C at `-O3`. In order:

1. **Infix expressions** as arguments and in `name = expression`, `if` with an expression, and a `while` block, with the syntax fixed by counting tokens on the corpus.
2. **Instruction selection**: immediate operands, variables used where they are, an assignment computed in the register of its target, the test of a loop at its end. The measurements in [performance.md](performance.md) say where the time goes today.
3. **The corpus, the library and the compiler rewritten** in the new forms, the compiler after a second seed that understands them.

## Supporting work

- Token cost is measured with a real tokenizer against equivalent C, Rust and assembly ([results](tokens.md)): AIL costs 46% fewer tokens than assembly, 17% more than C and 10% more than Rust on ten programs. Use `tools/tokens.sh` to choose between syntax alternatives.
- Elapsed time is measured against the same programs built with `gcc -O3` and `rustc -O` ([results](performance.md)): an AIL program starts in a third of the time of the C one; of five CPU-bound programs two run as fast as C and two take three and four times as long, a geometric mean of 1.74.
- Compile errors name the line, the file, the name at fault and a specific cause, since the error message is what an AI uses to repair its program.

## Not planned

- A second target architecture, linkable object files, a platform calling convention and dynamic linking were evaluated on 2026-11-20 and left out. Each would add a second code generator or a file format to both compilers, for no program that needs it. A second target, if ever wanted, would start as a cross-compiling backend in stage1.

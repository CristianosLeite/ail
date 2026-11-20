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
- Functions: `fn` ... `end`, `call` and `ret`, with up to six parameters, variables and labels local to each function, recursion and forward calls.
- Hello world, and a test runner whose tests can expect output, an exit status or a compile error.

## Next: make the language able to express a compiler

Stage0 has to grow until a compiler can be written in AIL. In rough order of dependency:

1. **Wider integers**: 64-bit and negative immediates, and 16- and 32-bit memory accesses if writing the compiler shows a need.
2. **More than six variables per function**, if writing the compiler shows a need.

## Then: self-hosting

1. Write the compiler in AIL (stage1), with the same behaviour as stage0.
2. Build stage1 with stage0, then build stage1 with itself, and check that the two outputs are byte-identical.
3. From then on, develop the language in AIL. Stage0 stays in the repository only as the bootstrap seed.

## Supporting work

- Measure token cost with a real tokenizer against equivalent C, Rust and assembly, and use the numbers to choose between syntax alternatives. So far the syntax follows a rule of thumb only.
- Report a line number on compile errors, since the error message is what an AI uses to repair its program.

# Roadmap

The goal of the proof of concept is a language that is cheap in tokens for an AI to write, compiled by a compiler written in that same language.

## Done

- Stage0 compiler in assembly that emits ELF64 directly.
- One statement, `sys`, with integer and string arguments.
- Hello world, and a test runner with one test.

## Next: make the language able to express a compiler

Stage0 has to grow until a compiler can be written in AIL. In rough order of dependency:

1. **Values that persist**: named registers or variables, and a way to use a syscall's return value.
2. **Arithmetic and comparison.**
3. **Memory access**: load and store bytes and words, plus a writable region for buffers. This needs a writable segment in the ELF output.
4. **Control flow**: labels, conditional and unconditional jumps, loops. This is the first feature that needs forward references, so the compiler needs fixups or a second pass.
5. **Functions**: call and return with a simple calling convention.
6. **Wider integers**: 64-bit and negative immediates.

## Then: self-hosting

1. Write the compiler in AIL (stage1), with the same behaviour as stage0.
2. Build stage1 with stage0, then build stage1 with itself, and check that the two outputs are byte-identical.
3. From then on, develop the language in AIL. Stage0 stays in the repository only as the bootstrap seed.

## Supporting work

- Measure token cost with a real tokenizer against equivalent C, Rust and assembly, and use the numbers to choose between syntax alternatives. So far the syntax follows a rule of thumb only.
- Report a line number on compile errors, since the error message is what an AI uses to repair its program.
- Let tests express an expected exit status and an expected compile failure, then cover the behaviours currently checked by hand.
- Require a delimiter after the `sys` keyword.

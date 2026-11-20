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
- Stage1: the compiler written in AIL (`stage1/ailc.ai`) with the same behaviour as stage0. Stage0 builds it, it builds itself, and the two outputs are byte-identical; `make test` checks that and that both compilers agree on every test.
- Hello world, and a test runner whose tests can expect output, an exit status or a compile error.

## Next: develop the language in AIL

The language is now developed in stage1; stage0 stays in the repository as the bootstrap seed. A new feature that stage1 itself is to use has to go into both, since stage0 must still build stage1. Writing stage1 needed no change to the language, and showed where it costs most ([details](stage1.md#friction-found)). In rough order of value:

1. **Constant data** (done): `data` names read-only bytes, a string is a value in every statement and `len` gives a length. Stage1 keeps its tables that way.
2. **More global names** (done): any number of buffers, `var` for global scalars and `const` for named numbers.
3. **Wider integers** (done): 64-bit, negative and hexadecimal literals, and 16- and 32-bit memory accesses.
4. **More than six variables per function** (done): 64 per scope; a function reuses registers whose variable is done and spills to the stack.

## Supporting work

- Token cost is measured with a real tokenizer against equivalent C, Rust and assembly ([results](tokens.md)): AIL costs 41% fewer tokens than assembly and about 20% more than C or Rust. Use `tools/tokens.sh` to choose between syntax alternatives.
- Report a line number on compile errors, since the error message is what an AI uses to repair its program.

# TODO

- [ ] Add register-backed variables to stage0. Let source code name values and let the compiler assign each name to a register from a small reserved pool. Report a clear compile error when the pool is exhausted. This lets the future AIL compiler keep cursors, counters, and syscall results live across statements.
  - Start by capturing syscall return values. One possible syntax is `sys 1 1 "hello\n" as n`, where `n` holds the number of bytes written or the raw syscall error code.
  - Keep buffers, addresses, loads, and stores explicit in the language.

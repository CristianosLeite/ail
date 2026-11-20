# Token cost

AIL exists to be cheap in tokens, so syntax choices are decided by measurement. `tools/tokens.sh` counts the tokens of each example in `examples/` and of the equivalent C, Rust and assembly programs in `bench/`, with comments and blank lines removed. It uses `tiktoken` with the `o200k_base` encoding, installed into `.venv` on first use (that step needs network access). The counts are those of one tokenizer; another model's tokenizer gives other numbers, but the comparison between languages is what matters here.

```
tools/tokens.sh             # the table below
tools/tokens.sh hello fact  # some programs only
tools/bench.sh              # check that bench/ behaves like examples/ (needs gcc and rustc)
```

## Result

| program | AIL | C | Rust | asm |
|---|---:|---:|---:|---:|
| count | 189 | 141 | 102 | 232 |
| echo | 56 | 58 | 86 | 150 |
| fact | 52 | 44 | 55 | 101 |
| hello | 23 | 29 | 45 | 78 |
| loop | 62 | 70 | 56 | 135 |
| total | 382 | 342 | 344 | 696 |
| relative to AIL | 1.00 | 0.90 | 0.90 | 1.82 |

AIL costs 45% fewer tokens than assembly that does the same, and about 10% more than C or Rust. It wins where the program is mostly system calls and tests of their results (`hello`, `echo`) and loses where it computes (`count`, where C writes one expression per digit and Rust one `format!`).

The first measurement, on 2026-11-19 before any of the backlog, gave 411 for AIL (C 0.83, Rust 0.84, assembly 1.69). The difference is the compare-and-jump statements, which the measurement below asked for, and the syscall names in `hello`.

## Where the tokens go

Measured on the first `stage1/ailc.ai` without comments: 6181 tokens in 1107 lines, 5.6 a line.

- **The line end is a token**, and so is every statement that an expression language would nest: 1096 of the 6181 tokens are line ends. One operation per line is the main cost against C.
- **`as` is a token** on 422 lines. It is the price of naming every intermediate result.
- **A number after a space is two tokens** (the space, then the digits), and a long decimal is more: `4294967295` is four tokens where `0xffffffff` is two. A name after a space is one token.
- **A comparison used once costs twelve tokens**: `gt n 4096 as e` and `jnz e fail`, against seven for a single compare-and-branch statement. Stage1 has 55 such pairs. `jnz` and `jz` are two tokens each.
- **Working around limits costs lines**: 120 lines of stage1 build constant tables from decimal words, and 50 are calls to the accessors of the packed state buffer.

## What this decides

- Fewer lines matter more than shorter words: prefer one statement that does the work of two (a compare-and-branch, a global scalar read directly as an argument) over abbreviations.
- Keep keywords that are single tokens (`load`, `store`, `data`, `const`, `call`, `label`); a suffix digit costs one more token (`load4` is `load` and `4`) and a suffix letter the same (`loadb`).
- Hex notation is worth having for large values.
- Named constants and named data replace numbers, which are the most expensive kind of argument.

Run the script again after a change of syntax and update the table when an example changes.

## Control flow, measured on 2026-11-20

Before choosing new forms of control flow, the cost of the existing ones was counted in `stage1/ailc.ai` and the examples together: 13447 tokens in 2443 lines.

- Jumps, labels and comparisons were 3894 tokens, 29% of all.
- 160 comparisons were followed by a `jz` or `jnz` on their result. One statement for the pair saves 857 tokens: 6.4% of all, 22% of the control flow.
- 152 of the 242 labels were the target of a single forward conditional jump, the shape of an `if`. A block that needs no label name saves 602 tokens: 4.5% of all, 15% of the control flow.
- 31 labels were the target of a single backward jump, the shape of a loop. A loop statement would save little, since a loop still needs its test and often a second exit.

So the compare-and-jump statements and the `if` blocks were added, and no loop statement. After rewriting stage1 with `tools/fuse.py`, `stage1/ailc.ai` went from 13483 to 12305 tokens.

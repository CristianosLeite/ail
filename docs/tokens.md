# Token cost

AIL exists to be cheap in tokens, so syntax choices are decided by measurement. `tools/tokens.sh` counts the tokens of each example in `examples/` and of the equivalent C, Rust and assembly programs in `bench/`, with comments and blank lines removed. It uses `tiktoken` with the `o200k_base` encoding, installed into `.venv` on first use (that step needs network access). The counts are those of one tokenizer; another model's tokenizer gives other numbers, but the comparison between languages is what matters here.

```
tools/tokens.sh             # the table below
tools/tokens.sh hello fact  # some programs only
tools/bench.sh              # check that bench/ behaves like examples/ (needs gcc and rustc)
python3 tools/perf.py       # time the same programs, see performance.md
```

## Result

| program | AIL | C | Rust | asm |
|---|---:|---:|---:|---:|
| collatz | 115 | 119 | 165 |  |
| compute | 91 | 106 | 120 | 229 |
| count | 118 | 141 | 102 | 232 |
| echo | 56 | 58 | 86 | 150 |
| fact | 40 | 44 | 55 | 101 |
| fnv | 141 | 167 | 126 |  |
| hello | 18 | 29 | 45 | 78 |
| isort | 215 | 239 | 250 |  |
| loop | 44 | 70 | 56 | 135 |
| sieve | 132 | 145 | 186 |  |
| total | 970 | 1118 | 1191 | 925 |
| relative to AIL | 1.00 | 1.15 | 1.23 | 2.52 |

This is the fixed corpus that a change of syntax is judged on: five short programs that are mostly system calls, and five that compute (`compute`, `sieve`, `collatz`, `fnv` and `isort`, described in [performance.md](performance.md)). The last four have no assembly equivalent; a language is compared with the AIL total of the programs it has, so the assembly figure is over six programs.

The examples are written with expressions, `x=e`, `x+=e`, `while` and `if` on a value since 2026-11-20. AIL costs 13% fewer tokens than C that does the same, 19% fewer than Rust and 60% fewer than assembly. It is cheaper than C in every program, and dearer than Rust only in `count` and `fnv`, where Rust formats a number or reads a file with one call. Written with one operation a line, as the language first was, the same ten programs were 1313 tokens, 17% more than C; the [count](#expressions-measured-on-2026-11-20) below chose the spelling that made the difference.

The first measurement, on 2026-11-19 before any of the backlog, gave 411 for AIL (C 0.83, Rust 0.84, assembly 1.69). The difference is the compare-and-jump statements, which the measurement below asked for, and the syscall names in `hello`.

## Where the tokens go

Measured on the first `compiler/ailc.ai` without comments: 6181 tokens in 1107 lines, 5.6 a line.

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

`tools/infix.py` rewrites a source written with statements: each statement that computes as an assignment, a label loop with its test at the top as `while`, and a variable that is assigned on one line and read once on the next, and not again, folded into that line, repeatedly. On the ten examples as they were written with statements it gives 1031 tokens from 1313; written by hand they are 970, the difference being lines that the tool keeps for their comments and loops it does not restructure. It was checked by rewriting the 310 runnable test programs it changes: each behaves as before. On `compiler/ailc.ai` it gave 20172 tokens from 25635, 21% fewer.

## Control flow, measured on 2026-11-20

Before choosing new forms of control flow, the cost of the existing ones was counted in `compiler/ailc.ai` and the examples together: 13447 tokens in 2443 lines.

- Jumps, labels and comparisons were 3894 tokens, 29% of all.
- 160 comparisons were followed by a `jz` or `jnz` on their result. One statement for the pair saves 857 tokens: 6.4% of all, 22% of the control flow.
- 152 of the 242 labels were the target of a single forward conditional jump, the shape of an `if`. A block that needs no label name saves 602 tokens: 4.5% of all, 15% of the control flow.
- 31 labels were the target of a single backward jump, the shape of a loop. A loop statement would save little, since a loop still needs its test and often a second exit.

So the compare-and-jump statements and the `if` blocks were added, and no loop statement then. `while` came with expressions (below): on programs that compute, a loop with its test in one line is worth more than it was in the compiler source, where most loops have a second exit. After rewriting stage1 with `tools/fuse.py`, `compiler/ailc.ai` went from 13483 to 12305 tokens.

## Expressions, measured on 2026-11-20

The redesign adds infix expressions, and how they are spelled was decided by writing the ten programs of the corpus in each candidate and counting. The candidates differ in three things: whether the operators of an expression stand between spaces, what separates the arguments of a statement once an argument can be an expression, and how an assignment is written. All of them use `while` and an `if` whose value is an expression.

| spelling | example | total |
|---|---|---:|
| statements, as before | `mod x 2 as r` | 1313 |
| operators between spaces, `x = e`, a comma between arguments | `storeb out + 1, 48 + n / 100 % 10` | 1104 |
| the same without the comma | `storeb out + 1 48 + n / 100 % 10` | 1092 |
| the comma form with `set e as x` for assignment | `set i + 1 as i` | 1140 |
| operators touch their operands, spaces separate arguments, `x = e` | `storeb out+1 48+n/100%10` | 1024 |
| the same with `set e as x` | `set i+1 as i` | 1060 |
| the same with `x=e` | `x=x*3+1` | 988 |
| the same with `x+=e` beside it | `c+=1` | 975 |
| C | | 1118 |
| Rust | | 1191 |

Per program, the last AIL row against the others:

| program | before | chosen | C | Rust |
|---|---:|---:|---:|---:|
| collatz | 158 | 115 | 119 | 165 |
| compute | 114 | 91 | 106 | 120 |
| count | 189 | 118 | 141 | 102 |
| echo | 56 | 56 | 58 | 86 |
| fact | 52 | 40 | 44 | 55 |
| fnv | 189 | 141 | 167 | 126 |
| hello | 23 | 18 | 29 | 45 |
| isort | 297 | 220 | 239 | 250 |
| loop | 62 | 44 | 70 | 56 |
| sieve | 173 | 132 | 145 | 186 |
| total | 1313 | 975 | 1118 | 1191 |

What the counts show:

- **A space before an operator or a number is paid for.** `x = (x ^ x >> 13) * 1664525 + 1013904223` is 21 tokens and `x=(x^x>>13)*1664525+1013904223` is 16: a space and the digits after it are two tokens, an operator after a space is its own token, and touching characters often merge (`=(`, `)*`, `<n`, `=i`). The spaced forms take a tenth more than the touching ones.
- **Touching operators make the comma unnecessary.** If an expression has no space in it, the spaces separate the arguments as they always did, and `a -1` stays two arguments while `a-1` is one.
- **`x=e` beats `set e as x`** by about two tokens an assignment (`x=n` is 2, `set n as x` is 4), and `x+=e` saves one more where a variable is changed in place, 13 times in the corpus.
- **A load inside an expression would not pay by itself**: `v=[p-8]` and `load p-8 as v` are both 6 tokens. It would only save a line where the value is used once, which the corpus does three times.
- `if a<b` and `iflt a b` cost the same; the expression form needs no table of names.

## What this decides for expressions

- An expression is written without spaces: `a+b*c`, `(h^r)*0x100000001b3`. Spaces separate the arguments of a statement, as before, so every statement that exists keeps its meaning and no comma is needed.
- The operators, tightest first, are `* / %`, then `+ -`, `<< >>`, `&`, `^`, `|`, and last the comparisons `== != < <= > >=`, which are unsigned and give 1 or 0. That is the order of Rust, in which `x^x>>13` needs no parentheses; all are left-associative and parentheses group. A `-` followed by a digit where a value is expected is a negative number, as it is today.
- `name=expression` assigns, and `name+=expression` with any of the ten arithmetic operators before the `=` changes a variable in place. The whole statement is one word.
- `if` takes an expression like any statement takes one, and `while expression` ... `end` is a loop. The `ifeq` and `jlt` families, labels and jumps stay.
- A string stays a whole argument. Signed and float operations, the atomic ones, loads, stores and calls stay statements; a load in an expression is left out until programs show it paying.

With these the corpus was counted at 975 tokens, 26% fewer than before, 13% fewer than C and 18% fewer than Rust. The examples as they were then written came to 970: `isort` lost five more by leaving its loop through a jump instead of a second label.

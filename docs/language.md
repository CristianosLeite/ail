# AIL language reference

This describes exactly what the compiler accepts today. The language is deliberately tiny; see the [roadmap](roadmap.md) for what comes next.

## Design rules

AIL is written by AI, so the cost that matters is tokens, not keystrokes or human readability.

- Short common words separated by spaces. No punctuation unless it carries information.
- No boilerplate: no `main`, no statement terminators, no declarations that the compiler can derive, and one short line to share a file.
- Hardware-oriented: statements map directly onto machine operations. There are no classes or objects.

## Program structure

A program is a sequence of statements, one per line. Execution starts at the first statement and runs downwards unless a [jump](#control-flow) sends it elsewhere. After the last statement the compiler appends `exit(0)`: the syscall `exit_group` with status 0, which ends the whole process. A `sys exit` written in the program ends only the thread that runs it, which is the process when there is one thread; a program with other threads ends with `sys exit_group`.

A [function](#functions) may stand anywhere between the statements. Execution passes around its body, which only runs when the function is called.

Blank lines are ignored. Indentation is ignored.

### `use`

```
use "path"
```

Compiles the file `path` at this place, as if its lines stood here: its functions, global names and top-level statements become part of the program, and its top-level statements run where the `use` stands. A program is thus split into files by listing them, and a file of functions and data is a library.

```
use "lib/io.ai"
call print "hello\n"
```

- A path is compiled **once**: a later `use` of the same path, in any file, does nothing. Two files can therefore each name the library they need. Paths are compared as written, so write a file the same way everywhere.
- The path is taken as it stands between the quotes, with no escapes, on one line, at most 4095 bytes. A relative path starts from the directory the compiler runs in, not from the file that has the `use`.
- `use` is a statement of the top level: it cannot stand inside a function, and a function must end in the file that starts it.
- Because functions, buffers and data may be [used before they are declared](#names), the place of a `use` matters only for the top-level statements of the file, for its `var` and `const` names, which must come before their uses, and for its top-level variables, which it shares with the rest of the top level.

All files of a program together are subject to the [size limit](#errors) of the source.

## Separators

The same rule holds everywhere outside string literals:

- Tokens (the keyword, numbers, strings, names, `as`) are separated by one or more spaces or tabs. Two tokens may not touch: `1"x"` and `"a""b"` are errors.
- A line ends with LF or CRLF. A CR that is not followed by LF is an error, also inside a comment; only a string may contain one.
- `#` starts a comment and may directly follow a token.

No other byte separates anything. A NUL or any other control character between tokens is a syntax error.

## Statements

### `sys`

```
sys n a b c d e f
sys n a b c d e f as name
```

Performs the raw Linux x86-64 syscall number `n` with up to six arguments. With `as name`, the syscall's return value is kept in the variable `name` (see [Variables](#variables)). `n` must be an [integer](#integers), the name of a [`const`](#const) or one of the [syscall names](#syscall-names) below, not a variable or a string. The statement ends at the end of the line.

| Position | Register |
|---|---|
| `n` | `rax` |
| 1st argument | `rdi` |
| 2nd | `rsi` |
| 3rd | `rdx` |
| 4th | `r10` |
| 5th | `r8` |
| 6th | `r9` |

Registers for arguments you leave out are not set and keep whatever they held. Without `as`, the syscall's return value is lost.

Registers for arguments you leave out are not set by the statement either, so a syscall that reads more arguments than it was given sees whatever those registers held.

#### Syscall names

In the place of the number, and only there, `sys` accepts these names for the kernel's numbers:

| | | | |
|---|---|---|---|
| `read` 0 | `write` 1 | `open` 2 | `close` 3 |
| `stat` 4 | `fstat` 5 | `lseek` 8 | `mmap` 9 |
| `mprotect` 10 | `munmap` 11 | `brk` 12 | `rt_sigaction` 13 |
| `ioctl` 16 | `pipe` 22 | `nanosleep` 35 | `getpid` 39 |
| `socket` 41 | `connect` 42 | `accept` 43 | `bind` 49 |
| `listen` 50 | `clone` 56 | `fork` 57 | `execve` 59 |
| `exit` 60 | `wait4` 61 | `kill` 62 | `rename` 82 |
| `mkdir` 83 | `rmdir` 84 | `unlink` 87 | `chmod` 90 |
| `gettimeofday` 96 | `getuid` 102 | `futex` 202 | `sched_getaffinity` 204 |
| `clock_gettime` 228 | `exit_group` 231 | `openat` 257 | `getrandom` 318 |

```
sys write 1 "hello\n"
sys exit 0
```

A name costs one token where a number costs two. The names are not constants: anywhere else `write` is an ordinary name, free for a variable or a function. A `const` of the program with the same name is used instead of the built-in number, and any other syscall is reached by its number or by a `const` of your own.

#### Results and errors

The kernel returns one value: the result, or a negative error number from -1 to -4095. `as` keeps it as it is. Read as signed it is below zero exactly when the call failed, so one line tests it:

```
sys open path 0 0 as fd
jslt fd 0 fail
```

### `args`

```
args as p
```

Keeps in a variable the address of what the kernel passed to the program. At that address stands the number of arguments, 8 bytes; then one address for each argument, the first being the name the program was started with; then a zero; then one address for each environment string, and another zero. Every argument and environment string ends with a NUL byte.

```
args as p
load p as argc
add p 8 as q
load q as name          # address of the program's name
```

`args` is a statement of the top level only: inside a function the stack no longer points there. Keep the address in a [`var`](#var) if functions need it; [`lib/io.ai`](#the-io-library) does that and offers `argc` and `argv`.

### `set` and arithmetic

```
set a as name
add a b as name
```

`set` copies one value into a variable. The arithmetic statements take two values and keep the result in a variable. All of them need `as name`; an operand is any [argument](#arguments), and a string is its address.

| Statement | Result |
|---|---|
| `set a` | `a` |
| `add a b` | `a + b` |
| `sub a b` | `a - b` |
| `mul a b` | `a * b` |
| `div a b` | `a / b`, unsigned, rounded down |
| `mod a b` | remainder of `a / b`, unsigned |
| `and a b`, `or a b`, `xor a b` | bitwise |
| `shl a b` | `a` shifted left by `b` bits |
| `shr a b` | `a` shifted right by `b` bits, zero-filled |
| `sdiv a b` | `a / b`, signed, rounded toward zero |
| `smod a b` | remainder of the signed division, with the sign of `a` |
| `sar a b` | `a` shifted right by `b` bits, filled with its sign bit |

Arithmetic is 64-bit and wraps silently: `sub 0 1` is all ones, which is `-1`. Addition, subtraction, multiplication and `shl` give the same bits for signed and unsigned numbers; only division, remainder, the shift to the right and ordering come in two forms, and the forms with `s` read both values as two's complement. A shift uses only the low 6 bits of `b`.

Nothing is checked: an overflow wraps, and dividing by zero kills the program with `SIGFPE` (exit status 136 in a shell), as does the one signed quotient that does not fit, -9223372036854775808 by -1. Test the divisor with `jz` where it can be zero. The result may go into one of the operands: `add i 1 as i`.

### Assignment

```
x=5
y=x*x+1
i+=1
h=(h^r)*0x100000001b3
```

`name=expression` computes the [expression](#expressions) and keeps it in the variable, as `set expression as name` does, but in the register of the variable where it can, so that `i+=1` is one instruction: the variable is defined if it is new, a `var` of that name is written, and any other global name is `duplicate name`. The statement is one word: no space on either side of the `=`, and nothing after the expression but a comment. A variable that is new cannot stand in its own expression.

With one of the operators `* / % + - << >> & ^ |` directly before the `=`, the variable is changed in place: `x+=e` is `x=x+(e)`, the whole right side being the second operand, so `x*=a+1` multiplies by the sum. The variable must have a value already.

The name is read before the statements are looked at, so a variable may be named like one: `end=add+1`. The comparisons have no such form, and `x==1` at the start of a line is not a statement.

### Floating point

```
itof 3 as a
fdiv a b as x
```

A floating-point number is an IEEE 754 double, and a variable holds its 64 bits like any other value: nothing marks it as a number of that kind. These statements read their values as doubles:

| Statement | Result |
|---|---|
| `itof a` | the signed integer `a` as a double |
| `ftoi a` | the double `a` as a signed integer, rounded toward zero |
| `fadd a b`, `fsub a b`, `fmul a b`, `fdiv a b` | sum, difference, product, quotient |
| `fsqrt a` | square root |
| `flt a b`, `fle a b`, `feq a b` | `1` if `a` is below, below or equal to, equal to `b`, else `0` |

A comparison with a value that is not a number is `0`, also `feq` of it with itself. For "above", swap the values. There are no floating-point literals: make a constant from integers (`itof 1` and `itof 3`, then `fdiv`), or write its bits (`0x3ff8000000000000` is 1.5). The integer statements work on the bits: `add` of two doubles is not their sum, and `lt` orders negative doubles the wrong way round.

```
itof 2 as two
fsqrt two as r
itof 1000 as k
fmul r k as r
ftoi r as n             # n = 1414
```

### Atomic operations

```
xadd p v as old
cas p old new as ok
```

`xadd` adds `v` to the 64 bits at address `p` and keeps what was there before; `cas` stores `new` at `p` only if the 64 bits there equal `old`, and keeps `1` if it stored and `0` if not. Each happens as one step that no other thread or process sharing the memory can come between, where a `load`, an `add` and a `store` can lose an update. Both need `as`.

### Comparisons

```
lt a b as name
```

A comparison takes two values like an arithmetic statement and keeps `1` in the variable if it holds, `0` if not. It needs `as name`; an operand is any [argument](#arguments).

| Statement | `1` when |
|---|---|
| `eq a b` | `a` equals `b` |
| `ne a b` | `a` differs from `b` |
| `lt a b` | `a` is below `b` |
| `le a b` | `a` is below or equals `b` |
| `gt a b` | `a` is above `b` |
| `ge a b` | `a` is above or equals `b` |
| `slt a b`, `sle a b`, `sgt a b`, `sge a b` | the same four orderings with both values read as signed |

All 64 bits of both values are compared and the result is a full 64-bit `1` or `0`. Ordering is unsigned for `lt`, `le`, `gt` and `ge`, like `div` and `mod`: the result of `sub 0 1` is the largest value, so `lt 1 x` is `1` for it. `slt`, `sle`, `sgt` and `sge` order the same bits as signed numbers, where it is `-1` and below 1. `eq` and `ne` need no signed form. A comparison only produces a value; [`jz` and `jnz`](#control-flow) act on it.

```
sub 0 1 as m
gt m 1 as r             # r = 1
```

### Control flow

```
label name
jmp name
jz a name
jnz a name
jlt a b name

if a
...
else
...
end
```

`label` names the point in the program where it stands; it emits no code. `jmp` continues execution at a label. `jz` jumps if the value `a` is zero and `jnz` if it is not, otherwise execution goes on with the next line. All 64 bits of the value are tested, so a comparison result can be used directly. The value is any [argument](#arguments).

The compare-and-jump statements take two values and a label and jump if the comparison holds, without a variable for the result:

| Statement | Jumps when |
|---|---|
| `jeq a b`, `jne a b` | `a` equals `b`, differs from `b` |
| `jlt a b`, `jle a b`, `jgt a b`, `jge a b` | `a` is below, below or equal, above, above or equal, in unsigned order |
| `jslt a b`, `jsle a b`, `jsgt a b`, `jsge a b` | the same in signed order |

`jlt i 10 top` does what `lt i 10 as c` and `jnz c top` do, in one line and five tokens instead of eleven.

#### Blocks

`if a` runs the lines up to the matching `end` when `a` is not zero, and passes over them otherwise. With an `else` line in between, the lines after it run in the other case. The opening line comes in the same forms as the jumps:

| Statement | The block runs when |
|---|---|
| `if a`, `ifz a` | `a` is not zero, is zero |
| `ifeq a b`, `ifne a b` | `a` equals `b`, differs from `b` |
| `iflt a b`, `ifle a b`, `ifgt a b`, `ifge a b` | the unsigned comparison holds |
| `ifslt a b`, `ifsle a b`, `ifsgt a b`, `ifsge a b` | the signed comparison holds |

```
ifgt n 4096
sys 60 1                # too long
end
ifz n
set 1 as n
else
sub n 1 as n
end
```

Blocks nest, and `end` closes the innermost one that is open; only when none is open in a function does it end the function. A block is a jump and a label that need no name, nothing more: labels and jumps work inside and across blocks, and a block has no variables of its own. The check for [unassigned variables](#control-flow) treats it like the jumps it stands for: after `end`, a variable is assigned if both ways there assigned it.

A label may be defined before or after the jumps that use it, and a label after the last statement stands at the appended `exit(0)`. Each label is defined once. Label names follow the rules of variable names but are a separate name space: a label may share its name with a variable or a buffer, and may be called `as`. There is no limit on the number of labels or jumps.

```
set 0 as i
label top
sys 1 1 "x"
add i 1 as i
jlt i 3 top             # prints xxx
```

A jump does not touch any variable. A variable may only be read where every way to that line has assigned it: reading one on a path that may have jumped over its `as` is the error `unassigned variable`.

```
jz a skip
set 1 as x
label skip
sys 60 x                # error: the jump passes the as of x
```

The compiler follows the lines in order. At a jump it notes which variables are assigned; at a label it keeps those that are assigned on the line before, if execution can come from there, and at every jump to the label seen so far. After `jmp` or `ret` no way leads to the next line until a label, and such lines are not checked. Two rules follow for jumps that go back:

- A jump back to a label must come with every variable assigned that was assigned at the label. So assign a variable before the loop if a way into the middle of the loop exists, or simply before the first jump that could pass its `as`.
- A label that execution can only reach from jumps below it, like the body of a loop that is entered at its test, starts with the variables that were assigned before the `jmp` or `ret` above it.

The check does not know values: it treats both outcomes of `jz` and `jnz` as possible, and `sys 60` as a line that goes on. A `var` is zero from the start and is never unassigned.

Labels are local: a label defined inside a [function](#functions) exists only there, and the labels outside every function are not visible inside one. A jump therefore never enters or leaves a function, and the same label name can be reused in each function.


#### Loops

```
i=0
while i<10
    sys write 1 "x"
    i+=1
end
```

`while a` runs the lines up to the matching `end` again and again, as long as `a` is not zero when it is reached; the value is computed before each round, so the lines may run no time at all. The value is one [argument](#arguments), usually an expression. The test is compiled at both ends of the loop, so a round costs one compare and one jump, and a loop that counts down to zero (`while i` ... `i-=1`) only the subtraction and the jump.

A loop is a block: it nests with `if` blocks and other loops, `end` closes the innermost open one, and it must be closed in the function it was opened in. It has no `else`. Nothing leaves a loop but its value becoming zero, a `jmp` to a label, or a `ret`; there is no statement to end the round early, so put the rest of the round in an `if`.

A variable must have a value on every way to a line that reads it. After a loop that is what had a value before it, since the lines in it may not have run: a variable first assigned inside a loop cannot be read after it. What the compiler knows of an address is forgotten where a loop begins.

### Functions

```
fn name a b
...
ret value
end

call name x y as result
call name x y
```

A function can also return several values, and a `call` names one variable for each:

```
ret a b
call name x y as q r
```

`fn` starts a function and `end` closes it. The names after the function name are its parameters; there may be none and at most 64. A function cannot be defined inside another one. Where a function stands does not matter: top-level execution skips its body, and a `call` may come before or after the definition.

`call` passes its values to the parameters in order and runs the function. With `as`, the value the function returns is kept in a variable; without it the value is dropped. A value is any [argument](#arguments), and the number of values must equal the number of parameters; a string is two values, its address and its length, so that a function taking `p n` can be called with a literal.

`ret` returns its values to the caller and is only allowed inside a function. It takes one to six values, and every `ret` of a function must take the same number: that is the number of results of the function. Reaching `end` returns `0` for each of them. A `call` may name fewer variables after `as` than the function has results, and the rest are dropped; naming more is the error `wrong result count`.

```
fn divmod a b
div a b as q
mod a b as r
ret q r
end
call divmod 47 5 as q r     # q = 9, r = 2
```

```
fn fact n
jz n one
sub n 1 as m
call fact m as r        # a function may call itself
mul n r as r
ret r
label one
ret 1
end
call fact 5 as x
sys 60 x                # exit(120)
```

Each function has its own variables and its own labels:

- The parameters are the function's first variables. Together with the variables it defines with `as`, a function has at most 64.
- A function sees none of the variables defined outside it, and its variables do not exist outside it. The same name can be used on both sides for different things. Values go in through the parameters and out through `ret`.
- Every call gets fresh variables: the caller's variables, at top level or in another function, are unchanged when the call returns, also when a function calls itself.
- Global names (`buf`, `data`, `var`, `const`) are visible in every function, and one declared inside a function is the same as one declared outside: its name may not be that of a top-level variable either. See [Names](#names) for what happens when a variable of a function has the name of a global.

Function names follow the rules of variable names but are a separate name space: a function may share its name with a variable, a buffer, a data name or a label, and may be called `as`. Each name is defined once. There is no limit on the number of functions or calls.

Calling convention: the first six values travel in `rax`, `rdi`, `rsi`, `rdx`, `r10` and `r8`, in order, with all 64 bits; the caller pushes any further values on the stack, in order, and removes them after the call. The results come back in the same six registers, the first in `rax`. `callp` has the address in `rcx`. The function saves those of the six variable registers that it uses when it starts and restores them when it returns.

#### Functions as values

```
ref name as p
callp p x y as result
```

`ref` keeps the address of a function in a variable, and `callp` calls the function whose address is its first value, passing the values after it. The function may be defined later. This is how a table of functions or a callback is written:

```
ref inc as f
callp f 10 as x         # the same as: call inc 10 as x
```

Nothing is known about the function at a `callp`: the number of values is not checked against its parameters, nor the names after `as` against its results, and an address that is not a function's is a fault at run time. Otherwise `callp` is a `call`: it has an optional `as` with one name per result wanted, and a string counts as two values.

#### Tasks

```
use "lib/task.ai"
spawn name x y as h
join h as result
```

`spawn` submits the function `name` with up to five values as a task and keeps a handle of it; `join` waits until the task has run and keeps the first result of the function. Tasks are independent pieces of work that may run at the same time as the code that spawned them:

```
use "lib/task.ai"
fn work a b
ret a*b
end
spawn work 6 7 as h
join h as x             # 42
```

The two statements are calls of the functions `spawn` and `join` of the program, which `lib/task.ai` defines; without that `use` they are an `undefined function`. `spawn` needs `as` with one name. The number of its values is checked against the parameters of the function, which may be defined later; a string counts as two values. `join` takes the handle and an optional `as`.

- **The handle** is a number that stands for the task until its `join`. Every task is joined exactly once, by any function, in any order; `join` releases the task, and its handle means nothing afterwards. A task that is never joined keeps its 64 bytes. A handle is 0 when the kernel had no memory for the task, which then never runs; `join` of 0 gives 0.
- **The result** is the first value the function returns, 0 if it reaches its `end`. Further results are lost; a task with more to give writes it to memory it was passed.
- **When it runs** is not defined: at some time between its `spawn` and the return of its `join`, on another thread or inside `join` itself. A program must be right in every such order.
- **Memory**: a task shares all memory with the rest of the program, `var` cells and buffers included. What a task wrote is there for the code after its `join`. Before that, a cell that the task and other code both touch, one of them writing, is only safe through [`xadd` and `cas`](#atomic-operations). Memory whose address is passed to a task must stay valid until its `join` has returned: a `buf` always is, an `alloc` until its `free`, and a `local` if the function that owns it joins the task before it returns.
- **Errors**: a task has no failure of its own. What it reports, it reports in its result. A fault in a task (a trap of `at`, a division by zero, a bad address) ends the whole program, as anywhere else.
- **The end of the program**: reaching the last line ends the program with every task, run or not. So does `sys exit_group`; `sys exit` ends only the thread that runs it.

#### Recursion and the stack

A call uses 8 bytes of stack for the return address, 8 for each register the function saves, 8 for each value after the sixth, 8 for each variable that did not get a register and the bytes of its [locals](#local). A function with two variables, like `fact` above, takes 24 bytes a call, so the usual 8 MiB stack allows some 350000 nested calls.

When the stack runs out, the program dies with `SIGSEGV` (exit status 139 in a shell): the kernel keeps an unmapped guard below the stack, and a function whose frame is a page or more enters it a page at a time, so the guard is hit and never jumped over. Nothing else is checked.

```
tail name x y
```

`tail` calls a function and returns its results, all of them, as `call name x y as r` followed by `ret r` would for one, but it releases the frame of the current function first and jumps: the callee returns directly to the caller's caller, and the stack does not grow. A function that ends each round with a `tail` to itself is a loop, however many rounds it takes:

```
fn count n acc
jz n done
sub n 1 as n
add acc 1 as acc
tail count n acc        # ten million rounds use one frame
label done
ret acc
end
```

`tail` is only allowed inside a function, takes no `as` and at most six values, since values on the stack would lie in the frame it gives up. For the same reason it must not pass the address of a `local`. No way leads to the line after it.

### `buf`

```
buf name size
```

Reserves `size` bytes of writable memory, filled with zeros when the program starts, and makes `name` their address. `size` is an [integer](#integers) or the name of a [`const`](#const) and is rounded up to a multiple of 8, so every buffer is 8-byte aligned. A size of 0 is allowed: the name is then an address with no bytes of its own, for instance a mark between two buffers.

A buffer name is a constant, not a variable: it uses none of the variables of a scope, and it can be used wherever a value is accepted, as one argument. It may be declared before or after the lines that use it. Variables and global names (buffers, data, [`var`](#var) and [`const`](#const)) share one name space. There is no limit on the number of buffers, and together they may take almost 2 GiB; the memory is reserved when the program is loaded, costs nothing until it is touched, and is never freed. Larger storage comes from [`alloc`](#alloc-and-free).

```
buf line 4096
sys 0 0 line 4096 as n     # read stdin into it
sys 1 1 line n             # write what was read
```

### `local`

```
local name size
```

Reserves `size` bytes in the frame of the function it stands in and makes `name` their address. The bytes exist while that call runs: every call has its own, also when a function calls itself, and they are gone when it returns, so their address must not be kept or returned. They are **not** zero-filled. `size` is an integer or a `const`, rounded up to a multiple of 8; 0 is allowed.

```
fn show n
local line 8
add n 48 as d
storeb line d
add line 1 as p
storeb p 10
sys 1 1 line 2
end
```

`local` is only allowed inside a function. The name counts as one of the 64 variables of the function and follows their [rules for names](#names), but it is not a variable: `as` cannot assign it. The locals of one function may take about 2 GiB together, far more than a stack holds; a call uses 8 bytes of stack for each 8 bytes of locals.

### `alloc` and `free`

```
alloc size as p
free p
```

`alloc` asks the kernel for `size` bytes of memory at run time and keeps their address in a variable, or 0 if the kernel refuses. The bytes are zero-filled and the address is a multiple of 16. `free` gives back what one `alloc` returned; `free 0` does nothing. After `free` the address must not be used again.

```
alloc n as p
jz p fail
...
free p
```

Each `alloc` is a memory mapping of its own (`mmap` and `munmap`, with 16 bytes in front for the length), so it costs a system call and at least a page: use it for storage whose size is only known at run time, a `buf` for what is fixed and a `local` for what a call needs. Both statements overwrite the registers of the [`sys`](#sys) arguments; variables are untouched.

### `var`

```
var name name ...
```

Declares global 64-bit cells, zero when the program starts. A `var` name is used like a variable: as an argument it passes the value of the cell, and `as name` stores a result in it. Unlike a variable it is visible in every function and does not count among the variables of a scope, so it is the way to share state between functions.

```
var count
fn tick
add count 1 as count
end
call tick
call tick
sys 60 count            # exit(2)
```

A `var` must be declared on an earlier line than its uses, at top level or inside a function, and lives for the whole program either way. Its name cannot be that of a parameter, and it has no address: `len` does not take it. There is no limit on the number of vars.

### `const`

```
const name number
```

Gives a number a name. The name is used wherever a value is accepted and passes the number; it is also accepted as the syscall number of `sys` and as the size of a `buf`, where a variable is not. A `const` costs nothing at run time and takes no register. It must be declared on an earlier line than its uses, and at top level it cannot be the target of `as`.

```
const exit 60
const size 4096
buf line size
sys exit 0
```

### `data`

```
data name item item ...
data item item ...
```

Puts read-only bytes into the program and makes `name` their address. An item is a [string](#strings), which gives its bytes, or an [integer](#integers) from 0 to 255, which gives one byte; there must be at least one item. Nothing is added: no terminator, no padding, no alignment.

```
data msg "hello" 10
len msg as n            # n = 6
sys 1 1 msg n
```

A data name is a constant like a buffer name: one value, its address, wherever a value is accepted, and it may be declared after the lines that use it. There is no limit on the number of data statements.

`data` statements on consecutive lines are laid out one after the other with nothing between them, so a table can be written a row a line. The name is optional, since only the first row needs one; a name on a later row is the address of that row. A `label` or any statement that produces code ends the run.

```
data days 31 28 31 30 31 30
data 31 31 30 31 30 31
add days 7 as p
loadb p as n            # n = 31, the eighth byte
```

The bytes stand in the code where the statement is, and execution passes around them, so `data` may be written anywhere, also inside a function. They are read-only: a store to them is rejected when the compiler can see it, and otherwise kills the program with `SIGSEGV`.

### `len`

```
len name as n
len "text" as n
```

Keeps the length in bytes of a buffer, a data name or a string in a variable: for a buffer the size as declared, before rounding; for a data name the bytes of its own statement, not of the rows after it. The operand cannot be a number, a variable, a `var` or a `const`.

### `at`

```
at name offset count as p
```

Keeps in a variable the address of the byte at `offset` in the object `name`, after checking **at run time** that `count` bytes from there lie inside it. If they do not, the program stops with an illegal instruction (`SIGILL`, exit status 132 in a shell) instead of touching memory it was not given.

```
buf table 800
at table i 8 as p       # traps unless i + 8 <= 800
load p as x
```

`name` is a buffer, a data name or a [local](#local): an object whose size the compiler knows. It may be declared later. The size is the one declared, and for a data name the bytes to the end of its run, as for the [compile-time check](#load-and-store). `offset` and `count` are any values; an offset that is negative when read as signed, or a sum that wraps, traps like one that is too large. A count of 0 at the very end is allowed.

`at` is the checked form of `add name offset as p`. It costs a comparison and two more tokens, and it only covers the bytes it was asked about: a later `load` of 8 bytes after an `at` with count 1 is not checked.

### `load` and `store`

```
load addr as name       # 64-bit value at addr
load4 addr as name      # 32-bit value at addr, zero-extended
load2 addr as name      # 16-bit value at addr, zero-extended
loadb addr as name      # byte at addr, zero-extended
store addr value        # write the 64 bits of value at addr
store4 addr value       # write the low 32 bits of value at addr
store2 addr value       # write the low 16 bits of value at addr
storeb addr value       # write the low byte of value at addr
```

`addr` is any value: a buffer or data name, a variable holding an address, a string or an integer. Loads need `as name`; stores do not take it. Values are little-endian in memory and need no alignment. A narrow store writes only its own bytes and leaves the ones after them. Nothing is checked at run time: an address outside mapped memory or in read-only memory kills the program with `SIGSEGV`.

The compiler rejects an access that it can prove wrong, with the error `invalid access`. It knows an address when it is a buffer or data name, a string, or a variable that `set`, `add` and `sub` computed from one of those and from numbers on the lines before, with no label in between:

- a load or store that does not lie inside the buffer, counting the size as declared, not as rounded: `buf b 4` followed by `store b 1` writes 8 bytes into 4;
- a load that does not lie inside the data, which for a data name reaches to the end of its run of consecutive `data` lines, or inside the string;
- any store into data or into a string.

```
buf b 16
add b 12 as p
store p 0               # error: bytes 12 to 19 of a 16-byte buffer
```

After a label, after any other statement that assigns the variable, and for a parameter or a `var`, the compiler knows nothing and checks nothing. It is a help against slips, not a guarantee.

```
buf b 8
storeb b 104            # "h"
add b 1 as p
storeb p 10             # newline
sys 1 1 b 2
```

## Arguments

### Integers

```
4096
0xff
-1
```

A decimal integer from 0 to 18446744073709551615, or `0x` followed by one to sixteen hexadecimal digits (`a` to `f` in either case; the `x` is lower case). A `-` directly before either form gives the two's complement, down to -9223372036854775808. All are 64-bit values: `-1` and `0xffffffffffffffff` are the same. There are no separators and no other sign.

A literal that does not fit 64 bits is the error `number too big`; nothing wraps silently. Arithmetic still wraps.

### Strings

```
"text"
```

In `sys` and `call` a string literal counts as **two** arguments: the address of its bytes, then its length in bytes. This matches the `buf, count` pair that syscalls such as `write` take, so the length never has to be written out:

```
sys 1 1 "hello world\n"     # write(1, addr, 12)
```

In every other statement a string is **one** value, the address of its bytes (`set "abc" as p`), except in [`len`](#len), where it is its length. Each literal has its own bytes, also when two are equal; use [`data`](#data) to name bytes that are used more than once.

Strings are not NUL-terminated; add `\0` if the callee needs it (it then counts towards the length). String data is read-only at run time.

| Escape | Byte |
|---|---|
| `\n` | 10, newline |
| `\t` | 9, tab |
| `\0` | 0 |
| `\xHH` | the byte with the hexadecimal value `HH`, two digits, `a` to `f` in either case |
| `\\` | backslash |
| `\"` | double quote |

A backslash before any other character yields that character. A string may span lines; the newline is included as-is.

### Variables

```
sys 1 1 "abc\n" as n     # n = 4, the number of bytes written
sys 60 n                 # exit(4)
```

A variable is a name for a 64-bit value, held in a machine register when one is free. A name starts with a lowercase letter and continues with lowercase letters, digits and `_`. `as` is reserved.

`as name` at the end of a statement defines the variable and stores the statement's result in it; after a `call`, several names take the several results of the function. For `sys` that is the syscall's raw return value: the result, or a negative error number. Nothing but a comment may follow it on the line. Using `as` with a name that already exists overwrites that variable. `as` is the only way to set a variable; `set 5 as x` sets one to a constant.

A variable used as an argument passes its full 64-bit value and counts as one argument. It must be defined by an earlier `as`, and it cannot be the syscall number.

Statement keywords are only special at the start of a line, so `add` or `buf` are valid variable names.

A variable belongs to the top level or to one function. State that several functions share goes into a [`var`](#var).

The top level of a program can define at most 64 variables, and so can each [function](#functions), counting its parameters. Six registers hold variables: `rbx`, `rbp`, `r12`, `r13`, `r14` and `r15`; syscalls and calls do not change them.

- At top level the first six variables get the registers, in order of definition, and each later one a memory cell of its own.
- In a function a variable needs a place only from its definition to the last line that mentions it, or to the end of a loop that it is used in, where a loop is the lines between a label and a jump back to it. A register whose variable is done is given to the next variable defined, so a function can use many short-lived variables without leaving the registers. When all six are busy, the variable lives on the stack.

Where a variable lives changes the speed and size of the code, never its meaning.

Variables hold values only. Memory is always reached through an explicit address: a [buffer](#buf), a [local](#local), or one obtained at run time:

```
alloc 4096 as p               # 4096 zero-filled bytes
sys 0 0 p 4096 as n           # read stdin into them
sys 1 1 p n                   # write what was read
```

### Names

A name used as a value is looked up in this order:

1. a variable of the current scope (the top level, or the function the line is in) that an earlier line defined with `as` or as a parameter;
2. a global name declared on an earlier line: a `buf`, `data`, `var` or `const`;
3. otherwise it is taken as the address of a `buf` or `data` declared on a later line. If the source ends without one, that is `undefined variable`. A `var` or a `const` must come before its uses.

At top level a name means one thing: a variable and a global name cannot share a name, whichever comes first. Inside a function, a parameter or a variable may have the name of a `buf`, `data` or `const`; from its definition to the `end` of the function the name means the variable, and the global is untouched. A `var` is never hidden: `as` with its name writes the cell, and a parameter with its name is an error.

```
buf b 8
fn f b                  # this b is the parameter
ret b
end
call f 9 as x           # x = 9
storeb t x              # t is declared below
buf t 8
```

### Addresses

An address is a 64-bit integer like any other value. Its number is not fixed: the kernel loads a program at a different place on each run, so the address of a buffer, of data or of a function is only the same within one run. Distances between two addresses of the same program do not change. It can be computed, compared, stored in memory, passed to a function and handed to the kernel, and nothing in the language records where it came from or how long it stays valid. That is deliberate: the language describes what the machine does, and the machine has no pointers, only numbers.

What the language offers against mistakes is therefore local and explicit:

- the compiler rejects an access it can prove wrong ([`load` and `store`](#load-and-store)) and a read of a variable that may be unassigned ([control flow](#control-flow));
- [`at`](#at) checks an offset at run time where the program asks for it;
- the lifetime of storage follows from how it was obtained: a `buf` and `data` live as long as the program, a [`local`](#local) until its function returns, and an [`alloc`](#alloc-and-free) until its `free`, after which the memory is unmapped and a use of it faults instead of reading stale bytes, unless a later `alloc` was given the same pages.

There is no ownership or borrow checking. A function receives addresses as plain values and may keep them; a syscall receives them the same way.

### Expressions

```
sys exit 2+3*4
storeb out+1 10
store b+8*(n-1) 0x10<<4
```

An argument may be an expression: values joined by operators, written **without a space**. Spaces separate the arguments of a statement, so `5-1` is one value and `5 -1` is two, the second a negative number. An expression stands wherever a statement takes a value; it does not stand where a name is required (the first value of `at`, the operand of `len`, a label, a name after `as`) or for the number of `sys`.

| Operators | Meaning | Binds |
|---|---|---|
| `*` `/` `%` | product, unsigned quotient and remainder | tightest |
| `+` `-` | sum and difference | |
| `<<` `>>` | shifts, the right one zero-filled | |
| `&` | bitwise and | |
| `^` | bitwise exclusive or | |
| `\|` | bitwise or | |
| `==` `!=` `<` `<=` `>` `>=` | comparison, unsigned, giving 1 or 0 | loosest |

Operators of one row are taken from left to right: `7-2-1` is 4. Parentheses group and may nest: `(2+3)*4`. This is the order of Rust, not of C: a shift binds tighter than `&`, and every bitwise operator tighter than a comparison, so `x&1==0` tests the low bit. The operators do what the statements of the same meaning do (`add`, `shr`, `lt`, ...): 64 bits, wrapping, a shift by the low 6 bits of its count.

A value in an expression is a number, a `const`, a variable, a `var`, or the name of a buffer or of data, which is its address. A `-` before a digit where a value is expected belongs to the number: `2+-1` is 1; there is no other unary operator, so write `0-x`. A string is not a value in an expression.

The compiler computes what it can: an expression of numbers and consts is the number, and a buffer or data name plus or minus a number is one address, checked like any [address](#addresses) the compiler knows: with `buf b 8`, `storeb b+8 0` is `invalid access`. A division by a constant zero is not computed; it fails when it runs.

A load or a store takes its address as an expression and uses it as the operand of one instruction where it has the form of one: `load p-8 as v`, `storeb s+i 1`. A statement and the expression that says the same compile to the same code: `add a b as x` and `x=a+b`, `jlt a b l` and `jnz a<b l`, `iflt a b` and `if a<b`. A comparison that is the whole value of `if`, `ifz`, `jz` or `jnz` is one compare and one jump, and so `if`, `jz` and `jnz` with an expression replace the twelve unsigned statements that compare and jump or open a block; the signed ones have no operator.

The rest is computed when the program runs, the operands of an operator from left to right. Nothing in an expression can fail except a division or a remainder by zero, which kills the program with `SIGFPE` as `div` and `mod` do.

## The io library

`lib/io.ai` is a file of functions written in AIL for what almost every program needs. A program compiled from the top of the repository gets it with `use "lib/io.ai"`; put that line first, since it also records the program's arguments where it stands.

| Function | Does |
|---|---|
| `print p n` | writes the `n` bytes at `p` to stdout, repeating the write until all are out; returns 1, or 0 after an error |
| `eprint p n` | the same to stderr |
| `fdwrite fd p n` | the same to the file `fd` |
| `die p n` | writes the bytes to stderr and ends the program with status 1 |
| `putn n` | prints `n` as an unsigned decimal number; returns like `print` |
| `strlen p` | the length of the NUL-terminated string at `p` |
| `argc` | the number of arguments, the program's name included |
| `argv i` | two results: the address and the length of argument `i`, or 0 and 0 if there is none |

```
use "lib/io.ai"
call argv 1 as p n
ifz p
call die "usage: greet name\n"
end
call print "hello "
call print p n
call print "\n"
```

A string literal is the two values that `print` takes. The library defines the var `argp` besides its functions, and no other global name.

## Comments

`#` starts a comment that runs to the end of the line, either on its own line or after a statement. A `#` inside a string is part of the string. A comment may hold any byte except a CR that is not followed by LF, and it may end the source without a line end.

## Errors

The compiler stops at the first fault it finds, prints one line on stderr and exits with a non-zero status:

```
ailc: 12: undefined label done
ailc: lib/io.ai:7: wrong operand count
ailc: source too big
```

After `ailc: ` comes the place: the line number, with the path of the file in front if the line is in a file that a `use` named, as the path was written there. Then the message, and for some messages the name it is about. The lines of each file count from 1. Messages that are not about a place have none.

A fault that can only be known when the whole source has been read is still reported where it was written: an undefined label, function or name at the line that uses it, a wrong count at the call, an invalid access at the load or store. Such faults are found after all the others, so a source with two faults may report the later line first.

Status 1 means the source is at fault; status 2 means the environment is.

| Message | Status | Cause |
|---|---|---|
| `unknown statement` | 1 | a line that does not start with a statement keyword |
| `not allowed here` | 1 | `ret`, `tail` or `local` outside a function; `fn`, `use` or `args` inside one; `end` with no block and no function open; `else` without an open block, in a `while`, or a second `else` in one |
| `missing end` | 1 | the source, or a file named by `use`, ends inside a function or a block |
| `missing as` | 1 | a statement that produces a value without `as`: `set`, `len`, the arithmetic statements, the comparisons, the loads, `at`, `alloc`, `ref`, `args` |
| `unexpected as` | 1 | `as` on a store, a jump, an `if` form, `ret`, `tail` or `free` |
| `missing label` | 1 | a jump whose values are not followed by a label name |
| `wrong operand count` | 1 | a statement with more or fewer values than it takes; `ret` without a value or with more than six; `tail` with more than six, where a string counts as two; `ref` with a value; `callp` without the address; `spawn` with more than five values; more than seven values after `sys` |
| `unterminated string` | 1 | a string, or the path of a `use`, with no closing quote |
| `expected a name` | 1 | something else where a name must stand: after `fn`, `label`, `call`, `tail`, `ref`, `buf`, `var`, `const`, `local` or `as`; or the name `as` in one of those places |
| `syntax error` | 1 | anything else that is not a statement of the language; see below |
| `undefined variable` *name* | 1 | a name used as a value that is no variable of its scope at that line and that no `buf` or `data` declares anywhere in the source; a `var` or `const` used before its declaration |
| `unassigned variable` *name* | 1 | a variable read on a way that may not have assigned it. Without a name: a jump back to a label that takes more variables as assigned than the jump has; see [Control flow](#control-flow) |
| `too many variables` | 1 | a 65th variable name at top level or in one function, parameters and locals included |
| `duplicate name` *name* | 1 | `buf`, `data`, `var` or `const` with a name already in use (inside a function, also by a top-level variable), `as` at top level with the name of a buffer, of data or of a `const`, `as` with the name of a local, a `local` with a name the function already uses, a parameter with the name of a `var`, a parameter named twice, a second `label` with the same name in one scope, or a second `fn` with the same name |
| `undefined label` *name* | 1 | a jump to a label that is not defined at top level or in the same function as the jump |
| `undefined function` *name* | 1 | a `call`, `tail`, `ref` or `spawn` of a function that the program never defines; a `spawn` or `join` in a program without `lib/task.ai`, with the name `spawn` or `join` |
| `wrong argument count` *name* | 1 | a `call`, `tail` or `spawn` whose number of values differs from the number of parameters of the function named; a `join` without exactly one value |
| `wrong result count` | 1 | two `ret` statements of one function with different numbers of values; with the name of the function, a `call` with more names after `as` than it has results |
| `invalid access` *name* | 1 | a load or store through a known address that leaves the buffer or data named, or a store into data; without a name, the same through a string; see [`load` and `store`](#load-and-store) |
| `number too big` | 1 | an integer above 18446744073709551615, below -9223372036854775808 or with more than sixteen hexadecimal digits |
| `buffers too big` | 1 | a buffer larger than 2 GiB or the locals of a function exceeding it; without a place, buffers that together with the code exceed it |
| `cannot read file` *path* | 1 | the path of a `use` cannot be opened or read |
| `source too big` | 1 | the source and the files it names with `use` are together larger than 8 MiB (8388608 bytes); no place |
| `program too big` | 1 | the compiled code does not fit; with the source limit this cannot happen, and the message exists so that a mistake in that reckoning is an error and not a damaged program; no place |
| `read error` | 2 | reading stdin failed; no place |
| `write error` | 2 | writing the executable to stdout failed, a pipe closed by its reader included; no place |

What remains a plain `syntax error`:

- a keyword not followed by a space or tab
- `sys` not followed by an integer, the name of a `const` or a syscall name
- `len` of a number, a `var` or a `const`; `at` whose first value is not the name of a buffer, data or local
- a size that is neither an integer nor a `const` after `buf` or `local`; a `const` without an integer
- `data` without an item or with an item that is not a string or an integer from 0 to 255
- `use` without a path in quotes, with an empty path or one of more than 4095 bytes
- a statement that defines something followed by anything but a comment: `buf`, `var`, `const`, `data`, `label`, `local`, `use`, `fn`, `else`, `end`
- `while` with nothing after it
- more than one name after `as` on a statement that is not `call` or `callp`, more than six on those, or anything but a comment after the names
- two tokens with no space or tab between them
- a byte other than space or tab used as a separator, or a CR not followed by LF, in a comment too
- `\x` in a string without two hexadecimal digits after it
- an argument that is not an integer, a string, a variable name, a global name or an [expression](#expressions)
- an expression with a parenthesis that is not closed or not opened, an operator without a value on each side, two values without an operator between them, a byte that is no operator, or a string in it
- an expression where a name is required, or for the number of `sys`
- an assignment with a space beside its `=`, with nothing after it, or with a second value
- `-` or `0x` without a digit after it

The output has no debugging information: a fault at run time is reported by the kernel as a signal, with no line. The exit status says which: 139 for an invalid memory access, 136 for a division by zero, 132 for the trap of [`at`](#at).

## Examples

Print the digits 0 to 9, one per line:

```
buf out 2
add out 1 as p
storeb p 10
set 0 as i
label top
add i 48 as d
storeb out d
sys 1 1 out 2
add i 1 as i
jlt i 10 top
```

Copy up to 4096 bytes of stdin to stdout, in upper case only for the first byte:

```
buf b 4096
sys 0 0 b 4096 as n
loadb b as c
sub c 32 as c
storeb b c
sys 1 1 b n
```

Write a string given by address and length, from a function that returns the number of bytes written:

```
fn put p n
sys 1 1 p n as r
ret r
end
call put "ail\n" as n   # a string is two values: address and length
sys 60 n                # exit(4)
```

Print to stdout:

```
sys 1 1 "hello world\n"
```

Print to stderr and exit with status 3:

```
sys 1 2 "failed\n"
sys 60 3
```

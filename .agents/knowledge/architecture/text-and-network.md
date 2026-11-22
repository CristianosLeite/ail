---
title: Numbers from text, JSON and HTTP
last-verified: 2026-11-22
sources: [conversation 2026-11-22 (in the aildb repository), lib/std/num.aiw, lib/std/json.aiw, lib/net/http.aiw, lib/net/httpd.aiw, docs/language.md, tests/lib_num_*, tests/lib_json_*, tests/lib_http_*, tests/lib_httpd_*]
status: current
---
# Numbers from text, JSON and HTTP

**Summary.** Four libraries that a program needs to talk to another one, written on
2026-11-22 for the MCP server of aildb and kept in AIL at the user's word: a decimal text
read as the nearest double, JSON read in place, and an HTTP/1.1 client and server on the
sockets of the async library. The MCP SDK itself is not here: it is a module of
ail-extensions.

## Decisions
- **They are libraries of AIL, not of aildb** (user, 2026-11-22): "the JSON parser, the
  decimal to double, the HTTP client and the HTTP server are native integrations of AIL;
  the MCP SDK is a module of ail-extensions". Asked where an SDK written in AIL should
  live, of three choices (a package inside aildb, a repository of its own, the library
  of AIL), the user gave this split.
- **`numdouble` is correctly rounded for every text** (agent). A model returns a vector
  as decimals, and the test of the program that reads them is that it stores the bytes
  another language stores; a parser that is right for most texts cannot be tested that
  way. The exact path (15 digits, a power of ten up to 22) is Clinger's; the rest is a
  rough double moved to the nearest by comparing whole numbers, which needs
  multiplication by a small number, a shift and a comparison and no division. The bits
  of doubles above zero are in their order, so a neighbour is the bits plus or minus
  one, and the subnormal numbers and the infinity need no case of their own. Rejected:
  Eisel-Lemire, which needs a table of 128-bit powers and still a fallback; and a
  parser without the fallback.
- **The whole numbers are in the frame, 32 bits a limb** (agent): the language has no
  product of 128 bits, and a `buf` would be shared between tasks. About 5 KiB of stack
  a call.
- **JSON makes no tree** (agent). A value is an address, a length and a kind in the
  bytes it was read from, checked once by `jsonvalue`; the walks return such values.
  A tree would need an allocator and a way to free it for every reader; the programs
  that read JSON here take a few members out of a message.
- **Stricter than RFC 8259 in two things, as I-JSON** (agent): well-formed UTF-8 and
  whole surrogate pairs, since a string that is neither cannot be handed on as UTF-8,
  and `jsonstr` could only fail on it later.
- **No double is written** (agent): the shortest digits that name a double are a
  library of their own, and aildb has `fmtfix` for a fixed number of digits. A program
  adds the text of a number it has.
- **The client is one request a connection, by address** (agent): what a program on
  the same machine as its service needs. No TLS, no names, no redirects.
- **The handler of the server is an async function** (agent), called through `callp`
  and awaited, so a handler that asks another service keeps no connection waiting; a
  task a connection.
- **`\x0d`, not `\r`** (learned): a string of AIL has no `\r`, and the first response
  of the server ended its lines in "r". The language was not changed.

## How it was checked
- `numdouble`: `float` of Python on 303,627 made texts, no difference.
- `jsonvalue`: the `json` module of Python with the two stricter rules and the depth
  added, on 80,066 texts; the walks, `jsonstr` and `jsonadds` on 30,005 values written
  again. No difference.
- The client against Ollama 0.40.17: the embedding of a query, read with the two
  libraries and rounded with `f8to4`, is byte for byte what `example/embed.py` of aildb
  writes. The server against curl 8.18.0.
- The programs of these comparisons were not kept; the tests in `tests/` are the cases
  that were read by hand, with outputs that the reference gives.

## Unchecked
- The server under many connections at once, and a slow client that sends a byte at a
  time (only the limit of 30 seconds a read holds it).
- `numdouble` against another `strtod` than that of Python (glibc).
- The version of AIL: the libraries came after the tag `v0.1.0`, and `Ailfile` still
  says 0.1.0, so a package cannot yet ask for an AIL that has them.

## The review of the pull request 28 (Copilot, 2026-11-22)
Eighteen findings, all taken; each is a case of the tests unless said otherwise.
- `numdouble` cut the exponent at 100000, so zeros before or after the digits that made
  up for a larger one gave 0 or an infinity for a text that is 1. The cut is at 10^17
  now, which no text has the digits to make up for.
- `jsoneq` allocated for a string with an escape, against what the library says of
  itself, and a failed allocation made a name that is there absent. It compares an
  escape as the bytes it stands for.
- HTTP, what a message is: a status line needs a digit as its version and an end after
  three digits; a chunk size needs a digit, and one that would pass 2^44 is -90, where
  the guard had held for letters only and seventeen digits were read as 0; a request
  line is read up to its end and no further, with a digit as its version; a head that
  is whole is held to the limits as one that is not.
- HTTP, memory: room for a whole request or response is asked for before it is put
  together, where only the last piece had been checked; a handle of 0, an event or a
  task that could not be made, is -12 and never awaited as if it were a result
  (`httpwait`, which also cancels the operation when its limit cannot be made); a
  connection whose task cannot be made is closed; a handler that could not be started
  is 500. None of these has a test: nothing here can make an allocation fail.
- A body in chunks keeps no line of its chunks: what is not yet taken is moved down to
  the body before more is read, so the buffer is bounded by the body and one read.
- The server sends no body with 204 and 304 and no length with 204, and closes without
  a response when the handler was cancelled (-125), which has no test either.
- A test compared 33 bytes with 32 and so always printed 0, which its expected output
  had.

## The second review of the pull request 28 (Copilot, 2026-11-22)
Eight findings, all taken, each a case of the tests but those of memory.
- Two lines `Content-Length` that differ, and a `Transfer-Encoding` that is not
  `chunked` alone, are no message (-71, 400 from the server): a second parser in front
  of this one could read the body otherwise.
- `httpwait`, the async function of the first review, was itself a task that may not be
  made, and the await of 0 is 0. It is `httplimit` now, a plain function that returns
  the handle to await, and every await of a task or an event of these files is of a
  handle that was looked at: 0 is -12. A limit that cannot be made cancels its
  operation, and the bytes of a write are given back after its await.
- The lines of the chunks are moved out before the limit is compared, at a size line
  and at a trailer too, so the limit is of the body wherever a read ends; a line that
  is not whole may be as long as a head. `httppack` with nothing to move returns at
  once, where it copied every byte onto itself for each read of a long chunk.
- A method is compared as it stands: `head` is not `HEAD`.
- The server answers `Expect: 100-continue` with `100 Continue` before it reads the
  body, and another expectation with 417.

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

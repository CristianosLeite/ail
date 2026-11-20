"""Count the tokens of each benchmark program in each language.

Usage: tokens.py [name ...]   (default: every example in examples/)
The AIL source is examples/<name>.ai; the others are bench/<name>.<ext>.
Comments and blank lines are removed first, so only code is counted.
"""
import os
import re
import sys

import tiktoken

LANGS = [("AIL", "examples/%s.ai", "#"), ("C", "bench/%s.c", "//"),
         ("Rust", "bench/%s.rs", "//"), ("asm", "bench/%s.s", "#")]


def code(path, mark):
    lines = []
    for line in open(path, encoding="utf-8"):
        line = re.sub(r"\s*%s.*" % re.escape(mark), "", line.rstrip("\n"))
        if line.strip():
            lines.append(line)
    return "\n".join(lines) + "\n"


def main():
    enc = tiktoken.get_encoding("o200k_base")
    names = sys.argv[1:] or sorted(
        f[:-3] for f in os.listdir("examples") if f.endswith(".ai"))
    print("| program | " + " | ".join(l for l, _, _ in LANGS) + " |")
    print("|---|" + "---:|" * len(LANGS))
    total = [0] * len(LANGS)
    for name in names:
        row = []
        for i, (_, pattern, mark) in enumerate(LANGS):
            n = len(enc.encode(code(pattern % name, mark)))
            total[i] += n
            row.append(str(n))
        print("| %s | %s |" % (name, " | ".join(row)))
    print("| total | %s |" % " | ".join(str(n) for n in total))
    print("| relative to AIL | %s |" % " | ".join(
        "%.2f" % (n / total[0]) for n in total))


main()

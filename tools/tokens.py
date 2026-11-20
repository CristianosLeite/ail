"""Count the tokens of each benchmark program in each language.

Usage: tokens.py [name ...]   (default: every example in examples/)
The AIL source is examples/<name>.ai; the others are bench/<name>.<ext>.
Comments and blank lines are removed first, so only code is counted.
A program without a source in a language has an empty cell there, and
that language is compared with the AIL total of the programs it has.
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
    base = [0] * len(LANGS)  # AIL tokens of the programs a language has
    for name in names:
        row = []
        ail = 0
        for i, (_, pattern, mark) in enumerate(LANGS):
            if not os.path.exists(pattern % name):
                row.append("")
                continue
            n = len(enc.encode(code(pattern % name, mark)))
            if i == 0:
                ail = n
            total[i] += n
            base[i] += ail
            row.append(str(n))
        print("| %s | %s |" % (name, " | ".join(row)))
    print("| total | %s |" % " | ".join(str(n) for n in total))
    print("| relative to AIL | %s |" % " | ".join(
        "%.2f" % (n / b) for n, b in zip(total, base)))

main()

#!/bin/sh
# Print the token cost of the benchmark programs as a Markdown table.
# Usage: tools/tokens.sh [name ...]
# Uses tiktoken (encoding o200k_base) from a virtual environment in
# .venv, created on first use; that step needs network access. It is
# not under build/, so `make clean` leaves it alone.
set -eu
cd "$(dirname "$0")/.."
venv=.venv
if [ ! -x "$venv/bin/python" ] || ! "$venv/bin/python" -c 'import tiktoken' 2>/dev/null; then
    python3 -m venv "$venv"
    "$venv/bin/pip" install -q tiktoken
fi
exec "$venv/bin/python" tools/tokens.py "$@"

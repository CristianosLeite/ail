#!/bin/sh
# Check that the task programs of bench/par print what their sequential
# forms print, at several numbers of threads and tasks (tools/par.py).
cd "$(dirname "$0")/.." || exit 1
exec python3 tools/par.py --check

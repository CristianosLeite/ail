#!/bin/sh
# Check that stage1/tables.ai is what tools/tables.sh generates from
# stage0/ailc.s: the tables have one definition, the assembly, and a change
# there that was not carried over fails here. Fix it with: make tables
set -u
cd "$(dirname "$0")/.."
out=$(mktemp) || exit 1
trap 'rm -f "$out"' EXIT
if tools/tables.sh > "$out" && cmp -s "$out" stage1/tables.ai; then
    echo "ok   tables_generated"
else
    echo "FAIL tables_generated"
    exit 1
fi

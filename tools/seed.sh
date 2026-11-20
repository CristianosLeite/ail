#!/bin/sh
# usage: tools/seed.sh <output>
#
# Write the pinned seed of the compiler to <output>: the last line of
# seed/MANIFEST names its version, SHA-256 and release address. A local
# copy seed/ailc-<version> is used when there is one; otherwise the file
# is fetched there, with curl, or with gh for a release that needs a
# login. A copy whose checksum is not the manifest's is refused, and a
# fetched one is then removed. The output is written through a temporary
# file, so a failure leaves no output that looks complete.
set -u
cd "$(dirname "$0")/.." || exit 1
out=${1:?usage: tools/seed.sh <output>}
set -- $(grep -v -e '^#' -e '^[[:space:]]*$' seed/MANIFEST | tail -n 1)
[ $# -eq 4 ] || { echo "seed: seed/MANIFEST has no seed line" >&2; exit 1; }
version=$1 sum=$3 url=$4
file=seed/ailc-$version

sum_ok() {
    [ "$(sha256sum < "$1" | cut -d' ' -f1)" = "$sum" ]
}

if [ ! -e "$file" ]; then
    tmp=$(mktemp "$file.tmp.XXXXXX") || exit 1
    trap 'rm -f "$tmp"' EXIT
    trap 'exit 1' HUP INT TERM
    if ! curl -fsSL -o "$tmp" "$url" 2>/dev/null; then
        # https://github.com/<owner>/<repository>/releases/download/<tag>/<name>
        repo=$(echo "$url" | cut -d/ -f4-5)
        tag=$(echo "$url" | cut -d/ -f8)
        gh release download "$tag" --repo "$repo" --pattern "ailc-$version" \
            --output "$tmp" --clobber 2>/dev/null || {
            echo "seed: cannot fetch $url" >&2
            echo "seed: put the file at $file" >&2
            exit 1
        }
    fi
    sum_ok "$tmp" || { echo "seed: $url: wrong checksum" >&2; exit 1; }
    mv "$tmp" "$file" || exit 1
fi
sum_ok "$file" || { echo "seed: $file: wrong checksum" >&2; exit 1; }
tmp2=$(mktemp "$out.tmp.XXXXXX") || exit 1
trap 'rm -f "$tmp2" "${tmp:-}"' EXIT
cp "$file" "$tmp2" && chmod 755 "$tmp2" && mv "$tmp2" "$out"

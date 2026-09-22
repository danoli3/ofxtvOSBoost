#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# Only disposable local build products; never remove tracked legacy libraries.
for path in "$root/build" "$root/.build"; do
    [[ ! -L "$path" ]] || { echo "Refusing symbolic link: $path" >&2; exit 1; }
    rm -rf "$path"
done

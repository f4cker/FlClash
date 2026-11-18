#!/bin/bash
# Usage: build.sh <output> [extra clang arguments]
# Produces an unsigned universal binary; signing is a separate, one-time step (README.md).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
output="${1:?usage: build.sh <output> [extra clang arguments]}"
shift
/usr/bin/xcrun clang -Os -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 -Wall -Wextra -Werror \
  "$@" "$here/main.c" -framework CoreFoundation -framework Security -o "$output"

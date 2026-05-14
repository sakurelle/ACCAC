#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

rm -f \
  "$ROOT_DIR/project1" \
  "$ROOT_DIR/src/project1" \
  "$ROOT_DIR/build/project1" \
  "$ROOT_DIR/accac" \
  "$ROOT_DIR/src/accac" \
  "$ROOT_DIR/build/accac"

rm -rf "$ROOT_DIR/build" "$ROOT_DIR/lib" "$ROOT_DIR/backup" "$ROOT_DIR/src/lib" "$ROOT_DIR/src/backup"

find "$ROOT_DIR/src" -type f \( \
  -name '*.o' -o \
  -name '*.ppu' -o \
  -name '*.compiled' -o \
  -name '*.or' -o \
  -name '*.rst' -o \
  -name '*.lps' \
\) -delete

echo "Cleanup complete."

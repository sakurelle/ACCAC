#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/src"
PROJECT_FILE="$PROJECT_DIR/project1.lpi"
OUTPUT_FILE="$ROOT_DIR/build/project1"

if [ ! -f "$PROJECT_FILE" ]; then
  echo "ERROR: project file not found: $PROJECT_FILE"
  exit 1
fi

if ! command -v lazbuild >/dev/null 2>&1; then
  echo "ERROR: lazbuild command not found"
  exit 1
fi

mkdir -p "$ROOT_DIR/build"
rm -f "$OUTPUT_FILE"

cd "$PROJECT_DIR"
lazbuild -B "$(basename "$PROJECT_FILE")"

if [ ! -f "$OUTPUT_FILE" ]; then
  echo "ERROR: build finished without output binary: $OUTPUT_FILE"
  exit 1
fi

chmod +x "$OUTPUT_FILE"
echo "Built: $OUTPUT_FILE"

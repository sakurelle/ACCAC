#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_FILE="$ROOT_DIR/build/project1"

if [ ! -f "$APP_FILE" ]; then
  echo "ERROR: binary not found: $APP_FILE"
  echo "Run ./scripts/build.sh first."
  exit 1
fi

chmod +x "$APP_FILE"
exec "$APP_FILE"

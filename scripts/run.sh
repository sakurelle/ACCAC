#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/accac.ini"
APP_CANDIDATES=(
  "$ROOT_DIR/accac"
  "$ROOT_DIR/build/accac"
)

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: configuration file not found: $CONFIG_FILE"
  echo "Run ./install_accac.sh first, or create accac.ini from config/accac.example.ini."
  exit 1
fi

APP_FILE=""
for candidate in "${APP_CANDIDATES[@]}"; do
  if [ -f "$candidate" ]; then
    APP_FILE="$candidate"
    break
  fi
done

if [ -z "$APP_FILE" ]; then
  echo "ERROR: ACCAC binary was not found."
  echo "Expected one of:"
  echo "  $ROOT_DIR/accac"
  echo "  $ROOT_DIR/build/accac"
  echo "For source mode, run: ./scripts/build.sh"
  echo "For release mode, check that the archive contains ./accac."
  exit 1
fi

chmod +x "$APP_FILE" 2>/dev/null || true

if [ ! -x "$APP_FILE" ]; then
  echo "ERROR: binary is not executable: $APP_FILE"
  echo "Try: chmod +x $APP_FILE"
  exit 1
fi

echo "Using configuration: $CONFIG_FILE"
cd "$ROOT_DIR"
exec "$APP_FILE"

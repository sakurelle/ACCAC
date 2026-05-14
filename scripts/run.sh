#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_FILE="$ROOT_DIR/build/accac"
CONFIG_CANDIDATES=(
  "$ROOT_DIR/accac.ini"
  "$ROOT_DIR/build/accac.ini"
  "$ROOT_DIR/build/config/accac.ini"
  "$ROOT_DIR/src/config/accac.ini"
)

resolve_config_path() {
  local candidate

  for candidate in "${CONFIG_CANDIDATES[@]}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

if [ ! -f "$APP_FILE" ]; then
  echo "ERROR: binary not found: $APP_FILE"
  echo "Run ./scripts/build.sh first."
  exit 1
fi

if ! CONFIG_FILE="$(resolve_config_path)"; then
  echo "Файл конфигурации accac.ini не найден."
  echo "Создайте его на основе примера:"
  echo "cp src/config/accac.example.ini accac.ini"
  echo "Затем укажите корректные параметры подключения к PostgreSQL."
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

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_DIR="$ROOT_DIR/db/postgresql"
BUILD_SCRIPT="$ROOT_DIR/scripts/build.sh"
DB_SCRIPT="$DB_DIR/run_all.sh"
EXAMPLE_CONFIG="$ROOT_DIR/src/config/accac.example.ini"
LOCAL_CONFIG="$ROOT_DIR/accac.ini"

APP_DB_HOST="${APP_DB_HOST:-${DB_HOST:-localhost}}"
APP_DB_PORT="${APP_DB_PORT:-${DB_PORT:-5432}}"
APP_DB_NAME="${APP_DB_NAME:-${DB_NAME:-accac}}"
APP_DB_USER="${APP_DB_USER:-${DB_USER:-accac_user}}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-${DB_PASSWORD:-change_me}}"
POSTGRES_USER="${POSTGRES_USER:-${PGSYSTEM_USER:-postgres}}"

PSQL="${PSQL:-$(command -v psql || true)}"
SUDO_BIN="${SUDO_BIN:-$(command -v sudo || true)}"
USE_SUDO_AS_POSTGRES=0

run_admin_psql() {
  if [ "$USE_SUDO_AS_POSTGRES" -eq 1 ]; then
    "$SUDO_BIN" -u "$POSTGRES_USER" "$PSQL" \
      -v ON_ERROR_STOP=1 \
      -p "$APP_DB_PORT" \
      "$@"
  else
    "$PSQL" \
      -h "$APP_DB_HOST" \
      -p "$APP_DB_PORT" \
      -U "$POSTGRES_USER" \
      -v ON_ERROR_STOP=1 \
      "$@"
  fi
}

if [ -n "$SUDO_BIN" ] && [ "$POSTGRES_USER" = "postgres" ] && \
  [ "$(id -un)" != "$POSTGRES_USER" ] && \
  { [ "$APP_DB_HOST" = "localhost" ] || [ "$APP_DB_HOST" = "127.0.0.1" ] || [ "$APP_DB_HOST" = "::1" ]; }; then
  USE_SUDO_AS_POSTGRES=1
fi

echo "=== ACCAC installation ==="

if [ ! -d "$DB_DIR" ]; then
  echo "ERROR: database directory not found: $DB_DIR"
  exit 1
fi

if [ ! -f "$BUILD_SCRIPT" ]; then
  echo "ERROR: build script not found: $BUILD_SCRIPT"
  exit 1
fi

if [ ! -f "$DB_SCRIPT" ]; then
  echo "ERROR: database deployment script not found: $DB_SCRIPT"
  exit 1
fi

if [ ! -f "$EXAMPLE_CONFIG" ]; then
  echo "ERROR: example config not found: $EXAMPLE_CONFIG"
  exit 1
fi

chmod +x "$ROOT_DIR"/scripts/*.sh 2>/dev/null || true
chmod +x "$DB_DIR/run_all.sh" 2>/dev/null || true
chmod +x "$ROOT_DIR/tests/jmeter/run_accac_db_limits.sh" 2>/dev/null || true

if [ -z "$PSQL" ] || ! command -v lazbuild >/dev/null 2>&1; then
  echo
  echo "=== Installing system packages ==="
  sudo apt-get update
  sudo apt-get install -y \
    postgresql \
    postgresql-client \
    lazarus \
    fpc \
    fpc-source \
    fp-units-db \
    libpq5 \
    libpq-dev \
    libgtk2.0-dev
  PSQL="${PSQL:-$(command -v psql || true)}"
else
  echo
  echo "=== Required tools are already installed ==="
fi

if [ -z "$PSQL" ]; then
  echo "ERROR: psql command not found after installation"
  exit 1
fi

echo
echo "=== Starting PostgreSQL ==="
if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl enable postgresql
  sudo systemctl start postgresql
else
  echo "WARNING: systemctl not found; make sure PostgreSQL is running."
fi

echo
echo "=== Checking application database role ==="
ROLE_EXISTS="$(
  run_admin_psql \
    -d postgres \
    -v APP_DB_USER="$APP_DB_USER" \
    -tAc "SELECT 1 FROM pg_roles WHERE rolname = :'APP_DB_USER';"
)"

if [ "$ROLE_EXISTS" = "1" ]; then
  echo "Role $APP_DB_USER already exists."
else
  echo "Creating role $APP_DB_USER with temporary password change_me..."
  run_admin_psql \
    -d postgres \
    -v APP_DB_USER="$APP_DB_USER" \
    -v APP_DB_PASSWORD="$APP_DB_PASSWORD" \
    -c "CREATE USER :\"APP_DB_USER\" WITH PASSWORD :'APP_DB_PASSWORD';"
fi

echo
echo "=== Applying migrations and grants ==="
APP_DB_NAME="$APP_DB_NAME" \
APP_DB_HOST="$APP_DB_HOST" \
APP_DB_PORT="$APP_DB_PORT" \
APP_DB_USER="$APP_DB_USER" \
APP_DB_PASSWORD="$APP_DB_PASSWORD" \
POSTGRES_USER="$POSTGRES_USER" \
PSQL="$PSQL" \
"$DB_SCRIPT"

echo
echo "=== Preparing local configuration ==="
if [ -f "$LOCAL_CONFIG" ]; then
  echo "Using existing configuration: $LOCAL_CONFIG"
else
  cat > "$LOCAL_CONFIG" <<EOF
[database]
host=$APP_DB_HOST
port=$APP_DB_PORT
database=$APP_DB_NAME
user=$APP_DB_USER
password=change_me
EOF
  echo "Created: $LOCAL_CONFIG"
fi

echo "Before the first launch, update the password in $LOCAL_CONFIG if it differs from change_me."

echo
echo "=== Building application ==="
"$BUILD_SCRIPT"

echo
echo "=== Installation complete ==="
echo "Configuration file: $LOCAL_CONFIG"
echo "Run the application with: ./scripts/run.sh"

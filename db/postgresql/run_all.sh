#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

APP_DB_NAME="${APP_DB_NAME:-${DB_NAME:-accac}}"
APP_DB_USER="${APP_DB_USER:-${DB_USER:-accac_user}}"
APP_DB_HOST="${APP_DB_HOST:-${DB_HOST:-localhost}}"
APP_DB_PORT="${APP_DB_PORT:-${DB_PORT:-5432}}"
POSTGRES_USER="${POSTGRES_USER:-${PGSYSTEM_USER:-postgres}}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-${DB_PASSWORD:-}}"
PSQL="${PSQL:-$(command -v psql || true)}"
SUDO_BIN="${SUDO_BIN:-$(command -v sudo || true)}"
USE_SUDO_AS_POSTGRES=0

MIGRATIONS=(
  "001_schema.sql"
  "002_tables.sql"
  "003_indexes.sql"
  "004_functions.sql"
  "005_procedures.sql"
  "006_triggers.sql"
  "007_seed.sql"
  "008_grants.sql"
)

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

if [ -z "$PSQL" ]; then
  echo "ERROR: psql command not found"
  exit 1
fi

if [ ! -d "$REPO_ROOT" ]; then
  echo "ERROR: repository root not found: $REPO_ROOT"
  exit 1
fi

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "ERROR: migrations directory not found: $MIGRATIONS_DIR"
  exit 1
fi

if [ -n "$SUDO_BIN" ] && [ "$POSTGRES_USER" = "postgres" ] && \
  [ "$(id -un)" != "$POSTGRES_USER" ] && \
  { [ "$APP_DB_HOST" = "localhost" ] || [ "$APP_DB_HOST" = "127.0.0.1" ] || [ "$APP_DB_HOST" = "::1" ]; }; then
  USE_SUDO_AS_POSTGRES=1
fi

echo "Preparing ACCAC database deployment..."
echo "Repository root: $REPO_ROOT"
echo "Target database: $APP_DB_NAME"
echo "Application role: $APP_DB_USER"

ROLE_EXISTS="$(
  run_admin_psql \
    -d postgres \
    -v APP_DB_USER="$APP_DB_USER" \
    -tAc "SELECT 1 FROM pg_roles WHERE rolname = :'APP_DB_USER';"
)"

if [ "$ROLE_EXISTS" != "1" ]; then
  if [ -n "$APP_DB_PASSWORD" ]; then
    echo "Creating PostgreSQL role $APP_DB_USER..."
    run_admin_psql \
      -d postgres \
      -v APP_DB_USER="$APP_DB_USER" \
      -v APP_DB_PASSWORD="$APP_DB_PASSWORD" \
      -c "CREATE USER :\"APP_DB_USER\" WITH PASSWORD :'APP_DB_PASSWORD';"
  else
    echo "Пользователь БД $APP_DB_USER не найден."
    echo "Создайте его перед развёртыванием БД:"
    echo "sudo -u postgres psql -c \"CREATE USER $APP_DB_USER WITH PASSWORD 'change_me';\""
    echo
    echo "Либо запустите скрипт с APP_DB_PASSWORD для автоматического создания роли."
    exit 1
  fi
fi

DB_EXISTS="$(
  run_admin_psql \
    -d postgres \
    -v APP_DB_NAME="$APP_DB_NAME" \
    -tAc "SELECT 1 FROM pg_database WHERE datname = :'APP_DB_NAME';"
)"

if [ "$DB_EXISTS" = "1" ]; then
  echo "Database $APP_DB_NAME already exists."
else
  echo "Creating database $APP_DB_NAME..."
  run_admin_psql \
    -d postgres \
    -v APP_DB_NAME="$APP_DB_NAME" \
    -v APP_DB_USER="$APP_DB_USER" \
    -c "CREATE DATABASE :\"APP_DB_NAME\" OWNER :\"APP_DB_USER\";"
fi

for migration in "${MIGRATIONS[@]}"; do
  migration_path="$MIGRATIONS_DIR/$migration"

  if [ ! -f "$migration_path" ]; then
    echo "ERROR: migration not found: $migration_path"
    exit 1
  fi

  echo "Applying $migration..."

  if [ "$migration" = "007_seed.sql" ]; then
    run_admin_psql \
      -d "$APP_DB_NAME" \
      -v base_dir="$FIXTURES_DIR" \
      -f "$migration_path"
  elif [ "$migration" = "008_grants.sql" ]; then
    run_admin_psql \
      -d "$APP_DB_NAME" \
      -v APP_DB_NAME="$APP_DB_NAME" \
      -v APP_DB_USER="$APP_DB_USER" \
      -f "$migration_path"
  else
    run_admin_psql \
      -d "$APP_DB_NAME" \
      -f "$migration_path"
  fi
done

echo "Database $APP_DB_NAME is ready, and grants for $APP_DB_USER are applied."

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
RUNUSER_BIN="${RUNUSER_BIN:-$(command -v runuser || true)}"
USE_LOCAL_POSTGRES_OS_USER=0
MIN_SERVER_VERSION_NUM=110000

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

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

run_as_local_postgres() {
  if [ "$(id -un)" = "$POSTGRES_USER" ]; then
    "$PSQL" "$@"
    return 0
  fi

  if [ -n "$SUDO_BIN" ]; then
    "$SUDO_BIN" -u "$POSTGRES_USER" "$PSQL" "$@"
    return 0
  fi

  if [ -n "$RUNUSER_BIN" ] && [ "$(id -u)" -eq 0 ]; then
    "$RUNUSER_BIN" -u "$POSTGRES_USER" -- "$PSQL" "$@"
    return 0
  fi

  fail "Unable to switch to the local PostgreSQL OS user $POSTGRES_USER. Re-run as root, install sudo, or connect with direct PostgreSQL authentication."
}

manual_create_user_command() {
  if [ -n "$SUDO_BIN" ]; then
    printf 'sudo -u %s psql -c "CREATE USER %s WITH PASSWORD '\''change_me'\'';"\n' \
      "$POSTGRES_USER" "$APP_DB_USER"
    return 0
  fi

  if [ -n "$RUNUSER_BIN" ] && [ "$(id -u)" -eq 0 ]; then
    printf 'runuser -u %s -- psql -c "CREATE USER %s WITH PASSWORD '\''change_me'\'';"\n' \
      "$POSTGRES_USER" "$APP_DB_USER"
    return 0
  fi

  printf 'psql -h %s -p %s -U %s -d postgres -c "CREATE USER %s WITH PASSWORD '\''change_me'\'';"\n' \
    "$APP_DB_HOST" "$APP_DB_PORT" "$POSTGRES_USER" "$APP_DB_USER"
}

manual_server_version_check_command() {
  if [ "$USE_LOCAL_POSTGRES_OS_USER" -eq 1 ]; then
    if [ -n "$SUDO_BIN" ]; then
      printf 'sudo -u %s psql -d postgres -tAc "SHOW server_version_num;"\n' \
        "$POSTGRES_USER"
      return 0
    fi

    if [ -n "$RUNUSER_BIN" ] && [ "$(id -u)" -eq 0 ]; then
      printf 'runuser -u %s -- psql -d postgres -tAc "SHOW server_version_num;"\n' \
        "$POSTGRES_USER"
      return 0
    fi
  fi

  printf 'psql -h %s -p %s -U %s -d postgres -tAc "SHOW server_version_num;"\n' \
    "$APP_DB_HOST" "$APP_DB_PORT" "$POSTGRES_USER"
}

run_admin_psql() {
  if [ "$USE_LOCAL_POSTGRES_OS_USER" -eq 1 ]; then
    run_as_local_postgres \
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

query_role_exists() {
  run_admin_psql \
    -d postgres \
    -v APP_DB_USER="$APP_DB_USER" \
    -tA <<'SQL'
SELECT 1
FROM pg_roles
WHERE rolname = :'APP_DB_USER';
SQL
}

query_database_exists() {
  run_admin_psql \
    -d postgres \
    -v APP_DB_NAME="$APP_DB_NAME" \
    -tA <<'SQL'
SELECT 1
FROM pg_database
WHERE datname = :'APP_DB_NAME';
SQL
}

query_server_version_num() {
  run_admin_psql -d postgres -tAc "SHOW server_version_num;" 2>/dev/null | tr -d '[:space:]'
}

require_supported_server_version() {
  local server_version_num

  server_version_num="$(query_server_version_num || true)"

  if ! [[ "$server_version_num" =~ ^[0-9]+$ ]]; then
    fail "Unable to determine the PostgreSQL server version. Check manually with: $(manual_server_version_check_command)"
  fi

  if [ "$server_version_num" -lt "$MIN_SERVER_VERSION_NUM" ]; then
    fail "ACCAC requires PostgreSQL 11 or newer. Detected server_version_num=$server_version_num."
  fi

  echo "PostgreSQL server version is compatible: $((server_version_num / 10000)) (server_version_num=$server_version_num)"
}

create_role_if_missing() {
  run_admin_psql \
    -d postgres \
    -v APP_DB_USER="$APP_DB_USER" \
    -v APP_DB_PASSWORD="$APP_DB_PASSWORD" <<'SQL'
SELECT format(
  'CREATE USER %I WITH PASSWORD %L',
  :'APP_DB_USER',
  :'APP_DB_PASSWORD'
)
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_roles
  WHERE rolname = :'APP_DB_USER'
)
\gexec
SQL
}

create_database_if_missing() {
  run_admin_psql \
    -d postgres \
    -v APP_DB_NAME="$APP_DB_NAME" \
    -v APP_DB_USER="$APP_DB_USER" <<'SQL'
SELECT format(
  'CREATE DATABASE %I OWNER %I',
  :'APP_DB_NAME',
  :'APP_DB_USER'
)
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_database
  WHERE datname = :'APP_DB_NAME'
)
\gexec
SQL
}

if [ -z "$PSQL" ]; then
  fail "psql command not found"
fi

if [ ! -d "$REPO_ROOT" ]; then
  fail "repository root not found: $REPO_ROOT"
fi

if [ ! -d "$MIGRATIONS_DIR" ]; then
  fail "migrations directory not found: $MIGRATIONS_DIR"
fi

if [ "$POSTGRES_USER" = "postgres" ] && \
  [ "$(id -un)" != "$POSTGRES_USER" ] && \
  { [ "$APP_DB_HOST" = "localhost" ] || [ -z "$APP_DB_HOST" ]; }; then
  USE_LOCAL_POSTGRES_OS_USER=1
fi

echo "Preparing ACCAC database deployment..."
echo "Repository root: $REPO_ROOT"
echo "Target database: $APP_DB_NAME"
echo "Application role: $APP_DB_USER"

require_supported_server_version

ROLE_EXISTS="$(query_role_exists | tr -d '[:space:]')"

if [ "$ROLE_EXISTS" != "1" ]; then
  if [ -n "$APP_DB_PASSWORD" ]; then
    echo "Creating PostgreSQL role $APP_DB_USER..."
    create_role_if_missing
  else
    echo "Database role $APP_DB_USER was not found."
    echo "Create it before deploying the database:"
    manual_create_user_command
    echo
    echo "Or rerun the script with APP_DB_PASSWORD to create the role automatically."
    exit 1
  fi
fi

DB_EXISTS="$(query_database_exists | tr -d '[:space:]')"

if [ "$DB_EXISTS" = "1" ]; then
  echo "Database $APP_DB_NAME already exists."
else
  echo "Creating database $APP_DB_NAME..."
  create_database_if_missing
fi

for migration in "${MIGRATIONS[@]}"; do
  migration_path="$MIGRATIONS_DIR/$migration"

  if [ ! -f "$migration_path" ]; then
    fail "migration not found: $migration_path"
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

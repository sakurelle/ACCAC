#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

APP_DB_NAME="${APP_DB_NAME:-accac}"
APP_DB_USER="${APP_DB_USER:-accac_user}"
APP_DB_HOST="${APP_DB_HOST:-localhost}"
APP_DB_PORT="${APP_DB_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-change_me}"
PSQL="${PSQL:-$(command -v psql || true)}"
CREATEDB_BIN="${CREATEDB_BIN:-$(command -v createdb || true)}"
SUDO_BIN="${SUDO_BIN:-$(command -v sudo || true)}"
RUNUSER_BIN="${RUNUSER_BIN:-$(command -v runuser || true)}"
USE_LOCAL_POSTGRES_OS_USER=0
RUNTIME_FIXTURES_DIR=""

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

sql_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

sql_identifier() {
  printf "%s" "$1" | sed 's/"/""/g'
}

cleanup_runtime_fixtures() {
  if [ -n "$RUNTIME_FIXTURES_DIR" ] && [ -d "$RUNTIME_FIXTURES_DIR" ]; then
    rm -rf "$RUNTIME_FIXTURES_DIR"
  fi
}

trap cleanup_runtime_fixtures EXIT

run_as_local_postgres() {
  if [ "$(id -un)" = "$POSTGRES_USER" ]; then
    (cd /tmp && "$@")
    return 0
  fi

  if [ -n "$SUDO_BIN" ]; then
    (cd /tmp && "$SUDO_BIN" -u "$POSTGRES_USER" "$@")
    return 0
  fi

  if [ -n "$RUNUSER_BIN" ] && [ "$(id -u)" -eq 0 ]; then
    (cd /tmp && "$RUNUSER_BIN" -u "$POSTGRES_USER" -- "$@")
    return 0
  fi

  fail "Unable to switch to the local PostgreSQL OS user $POSTGRES_USER. Re-run as root, install sudo, or connect with direct PostgreSQL authentication."
}

run_admin_psql() {
  if [ "$USE_LOCAL_POSTGRES_OS_USER" -eq 1 ]; then
    run_as_local_postgres "$PSQL" -v ON_ERROR_STOP=1 -p "$APP_DB_PORT" "$@"
  else
    "$PSQL" -h "$APP_DB_HOST" -p "$APP_DB_PORT" -U "$POSTGRES_USER" -v ON_ERROR_STOP=1 "$@"
  fi
}

run_admin_createdb() {
  if [ "$USE_LOCAL_POSTGRES_OS_USER" -eq 1 ]; then
    run_as_local_postgres "$CREATEDB_BIN" -p "$APP_DB_PORT" -O "$APP_DB_USER" "$APP_DB_NAME"
  else
    "$CREATEDB_BIN" -h "$APP_DB_HOST" -p "$APP_DB_PORT" -U "$POSTGRES_USER" -O "$APP_DB_USER" "$APP_DB_NAME"
  fi
}

run_psql_file() {
  local database="$1"
  local file="$2"
  shift 2

  if [ ! -r "$file" ]; then
    fail "migration file is not readable by current user: $file"
  fi

  if [ "$USE_LOCAL_POSTGRES_OS_USER" -eq 1 ]; then
    if [ "$(id -un)" = "$POSTGRES_USER" ]; then
      (cd /tmp && "$PSQL" -v ON_ERROR_STOP=1 -v APP_DB_NAME="$APP_DB_NAME" -v APP_DB_USER="$APP_DB_USER" "$@" -p "$APP_DB_PORT" -d "$database" < "$file")
    elif [ -n "$SUDO_BIN" ]; then
      (cd /tmp && "$SUDO_BIN" -u "$POSTGRES_USER" "$PSQL" -v ON_ERROR_STOP=1 -v APP_DB_NAME="$APP_DB_NAME" -v APP_DB_USER="$APP_DB_USER" "$@" -p "$APP_DB_PORT" -d "$database" < "$file")
    elif [ -n "$RUNUSER_BIN" ] && [ "$(id -u)" -eq 0 ]; then
      (cd /tmp && "$RUNUSER_BIN" -u "$POSTGRES_USER" -- "$PSQL" -v ON_ERROR_STOP=1 -v APP_DB_NAME="$APP_DB_NAME" -v APP_DB_USER="$APP_DB_USER" "$@" -p "$APP_DB_PORT" -d "$database" < "$file")
    else
      fail "Unable to switch to the local PostgreSQL OS user $POSTGRES_USER."
    fi
  else
    "$PSQL" -h "$APP_DB_HOST" -p "$APP_DB_PORT" -U "$POSTGRES_USER" -v ON_ERROR_STOP=1 -v APP_DB_NAME="$APP_DB_NAME" -v APP_DB_USER="$APP_DB_USER" "$@" -d "$database" < "$file"
  fi
}

query_server_version_num() {
  run_admin_psql -d postgres -tAc "SHOW server_version_num;" 2>/dev/null | tr -d '[:space:]'
}

require_supported_server_version() {
  local server_version_num

  server_version_num="$(query_server_version_num)"
  if ! [[ "$server_version_num" =~ ^[0-9]+$ ]]; then
    fail "Unable to determine the PostgreSQL server version."
  fi

  if [ "$server_version_num" -lt 110000 ] || [ "$server_version_num" -ge 140000 ]; then
    fail "unsupported PostgreSQL version. ACCAC supports PostgreSQL 11, 12 and 13 only."
  fi
}

query_role_exists() {
  local escaped_user_literal

  escaped_user_literal="$(sql_literal "$APP_DB_USER")"
  run_admin_psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$escaped_user_literal';" | tr -d '[:space:]'
}

query_database_exists() {
  local escaped_db_literal

  escaped_db_literal="$(sql_literal "$APP_DB_NAME")"
  run_admin_psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$escaped_db_literal';" | tr -d '[:space:]'
}

create_role_if_missing() {
  local role_exists
  local escaped_user_ident
  local escaped_password_literal

  role_exists="$(query_role_exists)"
  escaped_user_ident="$(sql_identifier "$APP_DB_USER")"
  escaped_password_literal="$(sql_literal "$APP_DB_PASSWORD")"

  if [ "$role_exists" = "1" ]; then
    echo "Role $APP_DB_USER already exists."
    if [ "${RESET_APP_DB_PASSWORD:-0}" = "1" ]; then
      echo "Updating password for role $APP_DB_USER because RESET_APP_DB_PASSWORD=1."
      run_admin_psql -d postgres -c "ALTER USER \"$escaped_user_ident\" WITH PASSWORD '$escaped_password_literal';"
    fi
    return 0
  fi

  echo "Creating PostgreSQL role $APP_DB_USER..."
  run_admin_psql -d postgres -c "CREATE USER \"$escaped_user_ident\" WITH PASSWORD '$escaped_password_literal';"
}

create_database_if_missing() {
  local db_exists

  db_exists="$(query_database_exists)"
  if [ "$db_exists" = "1" ]; then
    echo "Database $APP_DB_NAME already exists."
    return 0
  fi

  echo "Creating database $APP_DB_NAME..."
  run_admin_createdb
}

prepare_runtime_fixtures() {
  if [ ! -d "$FIXTURES_DIR" ]; then
    fail "fixtures directory not found: $FIXTURES_DIR"
  fi

  RUNTIME_FIXTURES_DIR="$(mktemp -d /tmp/accac-fixtures.XXXXXX)"
  cp -R "$FIXTURES_DIR/." "$RUNTIME_FIXTURES_DIR/"
  chmod -R a+rX "$RUNTIME_FIXTURES_DIR"
  printf '%s\n' "$RUNTIME_FIXTURES_DIR"
}

if [ -z "$PSQL" ]; then
  fail "psql command not found"
fi

if [ -z "$CREATEDB_BIN" ]; then
  fail "createdb command not found"
fi

if [ ! -d "$MIGRATIONS_DIR" ]; then
  fail "migrations directory not found: $MIGRATIONS_DIR"
fi

if [ "$POSTGRES_USER" = "postgres" ] &&
  [ "$(id -un)" != "$POSTGRES_USER" ] &&
  { [ "$APP_DB_HOST" = "localhost" ] || [ -z "$APP_DB_HOST" ]; }; then
  USE_LOCAL_POSTGRES_OS_USER=1
fi

echo "Preparing ACCAC database deployment..."
echo "Repository root: $REPO_ROOT"
echo "Target database: $APP_DB_NAME"
echo "Application role: $APP_DB_USER"

require_supported_server_version
create_role_if_missing
create_database_if_missing

for migration in "${MIGRATIONS[@]}"; do
  migration_path="$MIGRATIONS_DIR/$migration"

  if [ ! -f "$migration_path" ]; then
    fail "migration not found: $migration_path"
  fi

  echo "Applying $migration..."

  if [ "$migration" = "007_seed.sql" ]; then
    runtime_fixtures="$(prepare_runtime_fixtures)"
    run_psql_file "$APP_DB_NAME" "$migration_path" -v base_dir="$runtime_fixtures"
  elif [ "$migration" = "008_grants.sql" ]; then
    run_psql_file "$APP_DB_NAME" "$migration_path" -v APP_DB_NAME="$APP_DB_NAME" -v APP_DB_USER="$APP_DB_USER"
  else
    run_psql_file "$APP_DB_NAME" "$migration_path"
  fi
done

echo "Database $APP_DB_NAME is ready, and grants for $APP_DB_USER are applied."

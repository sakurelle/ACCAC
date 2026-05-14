#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DB_NAME="${APP_DB_NAME:-accac}"
APP_DB_USER="${APP_DB_USER:-accac_user}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-change_me}"
APP_DB_HOST="${APP_DB_HOST:-localhost}"
APP_DB_PORT="${APP_DB_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

DB_DIR="$ROOT_DIR/db/postgresql"
DB_SCRIPT="$DB_DIR/run_all.sh"
BUILD_SCRIPT="$ROOT_DIR/scripts/build.sh"
PREBUILT_BINARY="$ROOT_DIR/accac"
SOURCE_PROJECT="$ROOT_DIR/src/accac.lpi"
CONFIG_FILE="$ROOT_DIR/accac.ini"
CONFIG_EXAMPLE_CANDIDATES=(
  "$ROOT_DIR/config/accac.example.ini"
  "$ROOT_DIR/src/config/accac.example.ini"
)

MIN_POSTGRES_MAJOR=11
MIN_SERVER_VERSION_NUM=110000
APT_UPDATED=0

PSQL="${PSQL:-$(command -v psql || true)}"
CREATEDB_BIN="${CREATEDB_BIN:-$(command -v createdb || true)}"
SUDO_BIN="${SUDO_BIN:-$(command -v sudo || true)}"
RUNUSER_BIN="${RUNUSER_BIN:-$(command -v runuser || true)}"
USE_LOCAL_POSTGRES_OS_USER=0

log_section() {
  echo
  echo "=== $1 ==="
}

warn() {
  echo "WARNING: $*" >&2
}

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

run_with_privileges() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return 0
  fi

  if [ -n "$SUDO_BIN" ]; then
    "$SUDO_BIN" "$@"
    return 0
  fi

  fail "Administrative privileges are required to run: $*. Re-run as root or install sudo."
}

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

  fail "Unable to switch to the local PostgreSQL OS user $POSTGRES_USER. Re-run as root, install sudo, or use direct PostgreSQL authentication."
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

extract_major_from_text() {
  printf '%s\n' "$1" | sed -n 's/.* \([0-9][0-9]*\)\(\..*\)\{0,1\}.*/\1/p' | head -n1
}

find_postgres_binary() {
  local bindir
  local candidate

  if command -v postgres >/dev/null 2>&1; then
    command -v postgres
    return 0
  fi

  if command -v pg_config >/dev/null 2>&1; then
    bindir="$(pg_config --bindir 2>/dev/null || true)"
    if [ -n "$bindir" ] && [ -x "$bindir/postgres" ]; then
      printf '%s\n' "$bindir/postgres"
      return 0
    fi
  fi

  candidate="$(compgen -G '/usr/lib/postgresql/*/bin/postgres' 2>/dev/null | sort -V | tail -n1)"
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

detect_installed_pg_major() {
  local postgres_binary
  local version_text
  local major

  if postgres_binary="$(find_postgres_binary 2>/dev/null || true)"; then
    if [ -n "$postgres_binary" ]; then
      version_text="$("$postgres_binary" --version 2>/dev/null || true)"
      major="$(extract_major_from_text "$version_text" || true)"
      if [ -n "$major" ]; then
        printf '%s\n' "$major"
        return 0
      fi
    fi
  fi

  if command -v pg_config >/dev/null 2>&1; then
    version_text="$(pg_config --version 2>/dev/null || true)"
    major="$(extract_major_from_text "$version_text" || true)"
    if [ -n "$major" ]; then
      printf '%s\n' "$major"
      return 0
    fi
  fi

  if command -v psql >/dev/null 2>&1; then
    version_text="$(psql --version 2>/dev/null || true)"
    major="$(extract_major_from_text "$version_text" || true)"
    if [ -n "$major" ]; then
      printf '%s\n' "$major"
      return 0
    fi
  fi

  return 1
}

apt_update_once() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    run_with_privileges apt-get update
    APT_UPDATED=1
  fi
}

package_available() {
  local package="$1"

  if ! command -v apt-cache >/dev/null 2>&1; then
    return 1
  fi

  apt-cache policy "$package" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" { found = 1 } END { exit(found ? 0 : 1) }'
}

apt_install_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    fail "apt-get is not available. Install the required packages manually and rerun install_accac.sh."
  fi

  apt_update_once
  run_with_privileges apt-get install -y "$@"
}

select_postgresql_server_package() {
  if package_available "postgresql-11"; then
    printf '%s\n' "postgresql-11"
    return 0
  fi

  if package_available "postgresql-13"; then
    printf '%s\n' "postgresql-13"
    return 0
  fi

  if package_available "postgresql"; then
    printf '%s\n' "postgresql"
    return 0
  fi

  fail "No compatible PostgreSQL server package was found in the configured system repositories."
}

ensure_postgresql_available() {
  local installed_major=""
  local server_package=""
  local -a packages_to_install=()

  if find_postgres_binary >/dev/null 2>&1; then
    installed_major="$(detect_installed_pg_major 2>/dev/null || true)"
    if [ -z "$installed_major" ]; then
      fail "PostgreSQL appears to be installed, but its major version could not be determined."
    fi

    if [ "$installed_major" -lt "$MIN_POSTGRES_MAJOR" ]; then
      fail "ACCAC requires PostgreSQL 11 or newer. Found PostgreSQL $installed_major."
    fi

    echo "Using installed PostgreSQL major version: $installed_major"
  else
    log_section "Installing PostgreSQL"
    server_package="$(select_postgresql_server_package)"
    packages_to_install=("$server_package")

    if package_available "postgresql-client"; then
      packages_to_install+=("postgresql-client")
    fi

    apt_install_packages "${packages_to_install[@]}"
  fi

  PSQL="${PSQL:-$(command -v psql || true)}"
  CREATEDB_BIN="${CREATEDB_BIN:-$(command -v createdb || true)}"

  if [ -z "$PSQL" ] || [ -z "$CREATEDB_BIN" ]; then
    apt_install_packages postgresql-client
    PSQL="${PSQL:-$(command -v psql || true)}"
    CREATEDB_BIN="${CREATEDB_BIN:-$(command -v createdb || true)}"
  fi

  if [ -z "$PSQL" ]; then
    fail "psql command not found after installing PostgreSQL packages."
  fi

  if [ -z "$CREATEDB_BIN" ]; then
    fail "createdb command not found after installing PostgreSQL packages."
  fi
}

ensure_lazarus_available() {
  if command -v lazbuild >/dev/null 2>&1 && command -v fpc >/dev/null 2>&1; then
    return 0
  fi

  log_section "Installing Lazarus build dependencies"
  apt_install_packages lazarus fpc fpc-source fp-units-db libpq-dev libgtk2.0-dev
}

start_postgresql_service() {
  log_section "Starting PostgreSQL"

  if command -v systemctl >/dev/null 2>&1; then
    if run_with_privileges systemctl enable --now postgresql; then
      return 0
    fi
    warn "systemctl could not start the postgresql service."
  fi

  if command -v service >/dev/null 2>&1; then
    if run_with_privileges service postgresql start; then
      return 0
    fi
    warn "service could not start PostgreSQL."
  fi

  warn "PostgreSQL was not started automatically. Make sure the service is running before continuing."
}

query_server_version_num() {
  run_admin_psql -d postgres -tAc "SHOW server_version_num;" 2>/dev/null | tr -d '[:space:]'
}

ensure_supported_server_version() {
  local server_version_num

  server_version_num="$(query_server_version_num)"
  if ! [[ "$server_version_num" =~ ^[0-9]+$ ]]; then
    fail "Unable to determine the PostgreSQL server version."
  fi

  if [ "$server_version_num" -lt "$MIN_SERVER_VERSION_NUM" ]; then
    fail "ACCAC requires PostgreSQL 11 or newer. Detected server_version_num=$server_version_num."
  fi

  echo "PostgreSQL server version is compatible: $((server_version_num / 10000)) (server_version_num=$server_version_num)"
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

ensure_role() {
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

ensure_database() {
  local db_exists

  db_exists="$(query_database_exists)"
  if [ "$db_exists" = "1" ]; then
    echo "Database $APP_DB_NAME already exists."
    return 0
  fi

  echo "Creating database $APP_DB_NAME..."
  run_admin_createdb
}

find_config_example() {
  local candidate

  for candidate in "${CONFIG_EXAMPLE_CANDIDATES[@]}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

set_ini_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp_file

  tmp_file="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { written = 0 }
    $0 ~ "^" key "=" {
      print key "=" value
      written = 1
      next
    }
    { print }
    END {
      if (!written) {
        print key "=" value
      }
    }
  ' "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
}

prepare_config() {
  local example_config

  if [ -f "$CONFIG_FILE" ]; then
    echo "Using existing configuration: $CONFIG_FILE"
    return 0
  fi

  if ! example_config="$(find_config_example)"; then
    fail "example config not found. Expected config/accac.example.ini or src/config/accac.example.ini."
  fi

  cp "$example_config" "$CONFIG_FILE"
  set_ini_value "$CONFIG_FILE" "host" "$APP_DB_HOST"
  set_ini_value "$CONFIG_FILE" "port" "$APP_DB_PORT"
  set_ini_value "$CONFIG_FILE" "database" "$APP_DB_NAME"
  set_ini_value "$CONFIG_FILE" "user" "$APP_DB_USER"
  set_ini_value "$CONFIG_FILE" "password" "$APP_DB_PASSWORD"
  echo "Created: $CONFIG_FILE"
}

build_or_use_binary() {
  if [ -f "$PREBUILT_BINARY" ]; then
    chmod +x "$PREBUILT_BINARY" 2>/dev/null || true
    echo "Prebuilt binary found: ./accac"
    echo "Skipping Lazarus build step."
    return 0
  fi

  if [ ! -f "$SOURCE_PROJECT" ]; then
    fail "Prebuilt binary ./accac was not found, and source project is missing: $SOURCE_PROJECT"
  fi

  if [ ! -x "$BUILD_SCRIPT" ]; then
    chmod +x "$BUILD_SCRIPT" 2>/dev/null || true
  fi

  ensure_lazarus_available
  "$BUILD_SCRIPT"
}

if [ "$POSTGRES_USER" = "postgres" ] &&
  [ "$(id -un)" != "$POSTGRES_USER" ] &&
  { [ "$APP_DB_HOST" = "localhost" ] || [ -z "$APP_DB_HOST" ]; }; then
  USE_LOCAL_POSTGRES_OS_USER=1
fi

if [ ! -f "$DB_SCRIPT" ]; then
  fail "database deployment script not found: $DB_SCRIPT"
fi

chmod +x "$ROOT_DIR"/scripts/*.sh 2>/dev/null || true
chmod +x "$DB_SCRIPT" 2>/dev/null || true
chmod +x "$ROOT_DIR/tests/jmeter/run_accac_db_limits.sh" 2>/dev/null || true

ensure_postgresql_available
start_postgresql_service || true

log_section "Checking PostgreSQL server version"
ensure_supported_server_version

log_section "Preparing PostgreSQL role and database"
ensure_role
ensure_database

log_section "Applying migrations and grants"
APP_DB_NAME="$APP_DB_NAME" \
APP_DB_HOST="$APP_DB_HOST" \
APP_DB_PORT="$APP_DB_PORT" \
APP_DB_USER="$APP_DB_USER" \
APP_DB_PASSWORD="$APP_DB_PASSWORD" \
POSTGRES_USER="$POSTGRES_USER" \
PSQL="$PSQL" \
"$DB_SCRIPT"

log_section "Preparing local configuration"
prepare_config

log_section "Preparing application binary"
build_or_use_binary

log_section "Installation complete"
echo "Configuration file: $CONFIG_FILE"
if [ -f "$PREBUILT_BINARY" ]; then
  echo "Run the application with: ./accac"
else
  echo "Run the application with: ./scripts/run.sh"
fi

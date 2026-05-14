#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DB_NAME="${APP_DB_NAME:-accac}"
APP_DB_USER="${APP_DB_USER:-accac_user}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-change_me}"
APP_DB_HOST="${APP_DB_HOST:-localhost}"
APP_DB_PORT="${APP_DB_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

PREBUILT_BINARY="$ROOT_DIR/accac"
PROJECT_FILE="$ROOT_DIR/src/accac.lpi"

DB_SCRIPT="$ROOT_DIR/db/postgresql/run_all.sh"
BUILD_SCRIPT="$ROOT_DIR/scripts/build.sh"
CONFIG_FILE="$ROOT_DIR/accac.ini"
CONFIG_EXAMPLE_CANDIDATES=(
  "$ROOT_DIR/config/accac.example.ini"
  "$ROOT_DIR/src/config/accac.example.ini"
)

APT_UPDATED=0
PSQL="${PSQL:-$(command -v psql || true)}"
CREATEDB_BIN="${CREATEDB_BIN:-$(command -v createdb || true)}"
SUDO_BIN="${SUDO_BIN:-$(command -v sudo || true)}"
RUNUSER_BIN="${RUNUSER_BIN:-$(command -v runuser || true)}"

log_section() {
  echo
  echo "=== $1 ==="
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARNING: $*" >&2
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
  elif [ -n "$SUDO_BIN" ]; then
    "$SUDO_BIN" "$@"
  else
    fail "Administrative privileges are required. Re-run as root or install sudo."
  fi
}

run_as_postgres() {
  if [ "$(id -un)" = "$POSTGRES_USER" ]; then
    (cd /tmp && "$@")
  elif [ -n "$SUDO_BIN" ]; then
    (cd /tmp && "$SUDO_BIN" -u "$POSTGRES_USER" "$@")
  elif [ -n "$RUNUSER_BIN" ] && [ "$(id -u)" -eq 0 ]; then
    (cd /tmp && "$RUNUSER_BIN" -u "$POSTGRES_USER" -- "$@")
  else
    fail "Unable to switch to PostgreSQL OS user $POSTGRES_USER. Install sudo or run as root."
  fi
}

run_admin_psql() {
  if [ "$POSTGRES_USER" = "postgres" ] &&
    { [ "$APP_DB_HOST" = "localhost" ] || [ -z "$APP_DB_HOST" ]; }; then
    run_as_postgres "$PSQL" -v ON_ERROR_STOP=1 -p "$APP_DB_PORT" "$@"
  else
    "$PSQL" -h "$APP_DB_HOST" -p "$APP_DB_PORT" -U "$POSTGRES_USER" -v ON_ERROR_STOP=1 "$@"
  fi
}

run_admin_createdb() {
  if [ "$POSTGRES_USER" = "postgres" ] &&
    { [ "$APP_DB_HOST" = "localhost" ] || [ -z "$APP_DB_HOST" ]; }; then
    run_as_postgres "$CREATEDB_BIN" -p "$APP_DB_PORT" -O "$APP_DB_USER" "$APP_DB_NAME"
  else
    "$CREATEDB_BIN" -h "$APP_DB_HOST" -p "$APP_DB_PORT" -U "$POSTGRES_USER" -O "$APP_DB_USER" "$APP_DB_NAME"
  fi
}

apt_update_once() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    if ! command -v apt-get >/dev/null 2>&1; then
      fail "apt-get is not available. Configure packages manually for Astra Linux."
    fi
    run_with_privileges apt-get update
    APT_UPDATED=1
  fi
}

package_available() {
  local package="$1"
  apt-cache policy "$package" 2>/dev/null | awk '/Candidate:/ { print $2 }' | grep -vq "(none)"
}

postgres_package_error() {
  cat >&2 <<'EOF'
ERROR: PostgreSQL 11, 12 or 13 package was not found in configured APT repositories.

Checked packages:
  - postgresql-13
  - postgresql-12
  - postgresql-11

For Astra Linux 1.7:
  sudo apt update
  sudo apt install -y postgresql-11 postgresql-client libpq5 libgtk2.0-0

For Astra Linux 1.8:
  first check available packages:
    apt-cache policy postgresql-13
    apt-cache policy postgresql-12
    apt-cache policy postgresql-11

  install one of allowed versions only:
    sudo apt install -y postgresql-13 postgresql-client libpq5 libgtk2.0-0
  or:
    sudo apt install -y postgresql-12 postgresql-client libpq5 libgtk2.0-0
  or:
    sudo apt install -y postgresql-11 postgresql-client libpq5 libgtk2.0-0

Do not install PostgreSQL 14, 15 or newer.

For Astra Linux 1.7, configure official Astra 1.7 repositories, then run:
  sudo apt update
  sudo apt install -y postgresql-11 postgresql-client libpq5 libgtk2.0-0

For Astra Linux 1.8, configure official Astra 1.8 repositories, then check allowed packages:
  apt-cache policy postgresql-13
  apt-cache policy postgresql-12
  apt-cache policy postgresql-11

Repository configuration must be performed by the OS user or administrator.
EOF
  exit 1
}

select_postgresql_server_package() {
  local target="${POSTGRES_TARGET_MAJOR:-}"
  local major

  if [ -n "$target" ]; then
    case "$target" in
      11|12|13)
        if package_available "postgresql-$target"; then
          printf 'postgresql-%s\n' "$target"
          return 0
        fi
        postgres_package_error
        ;;
      *)
        fail "POSTGRES_TARGET_MAJOR must be 11, 12 or 13."
        ;;
    esac
  fi

  for major in 13 12 11; do
    if package_available "postgresql-$major"; then
      printf 'postgresql-%s\n' "$major"
      return 0
    fi
  done

  postgres_package_error
}

apt_install_required() {
  local package
  local -a missing=()

  apt_update_once
  for package in "$@"; do
    if ! package_available "$package"; then
      missing+=("$package")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'ERROR: required APT package is not available: %s\n' "${missing[0]}" >&2
    echo "Check configured official Astra Linux repositories." >&2
    exit 1
  fi

  run_with_privileges apt-get install -y "$@"
}

find_postgres_binary() {
  local candidate

  if command -v postgres >/dev/null 2>&1; then
    command -v postgres
    return 0
  fi

  candidate="$(compgen -G '/usr/lib/postgresql/*/bin/postgres' 2>/dev/null | sort -V | tail -n1)"
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

install_runtime_dependencies() {
  apt_install_required postgresql-client libpq5 libgtk2.0-0
  PSQL="${PSQL:-$(command -v psql || true)}"
  CREATEDB_BIN="${CREATEDB_BIN:-$(command -v createdb || true)}"
}

install_postgresql_server_if_needed() {
  local server_package

  if find_postgres_binary >/dev/null 2>&1; then
    return 0
  fi

  log_section "Installing PostgreSQL server"
  apt_update_once
  server_package="$(select_postgresql_server_package)"
  run_with_privileges apt-get install -y "$server_package"
}

start_postgresql_service() {
  log_section "Starting PostgreSQL"

  if command -v systemctl >/dev/null 2>&1; then
    run_with_privileges systemctl enable postgresql || true
    run_with_privileges systemctl start postgresql || true
  elif command -v service >/dev/null 2>&1; then
    run_with_privileges service postgresql start || true
  fi
}

get_postgres_server_version_num() {
  run_as_postgres "$PSQL" -d postgres -tAc "SHOW server_version_num;" 2>/dev/null | tr -d '[:space:]' || true
}

check_postgresql_server_available() {
  if ! run_as_postgres "$PSQL" -d postgres -tAc "SELECT 1;" >/dev/null 2>&1; then
    fail "PostgreSQL server is not available. Start PostgreSQL and rerun install_accac.sh."
  fi
}

check_supported_postgresql_version() {
  local version_num

  version_num="$(get_postgres_server_version_num)"
  if ! [[ "$version_num" =~ ^[0-9]+$ ]]; then
    fail "Unable to determine PostgreSQL server version."
  fi

  if [ "$version_num" -lt 110000 ] || [ "$version_num" -ge 140000 ]; then
    cat >&2 <<'EOF'
ERROR: unsupported PostgreSQL version.
ACCAC supports PostgreSQL 11, 12 and 13 only.
EOF
    exit 1
  fi

  echo "PostgreSQL server version is supported: $version_num"
}

ensure_postgresql() {
  install_runtime_dependencies
  install_postgresql_server_if_needed
  PSQL="${PSQL:-$(command -v psql || true)}"
  CREATEDB_BIN="${CREATEDB_BIN:-$(command -v createdb || true)}"

  if [ -z "$PSQL" ]; then
    fail "psql command not found after installing postgresql-client."
  fi

  if [ -z "$CREATEDB_BIN" ]; then
    fail "createdb command not found after installing postgresql-client."
  fi

  start_postgresql_service
  check_postgresql_server_available
  check_supported_postgresql_version
}

ensure_role() {
  local escaped_user_literal
  local escaped_user_ident
  local escaped_password_literal
  local role_exists

  escaped_user_literal="$(sql_literal "$APP_DB_USER")"
  role_exists="$(run_admin_psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$escaped_user_literal';" | tr -d '[:space:]')"
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
  local escaped_db_literal
  local db_exists

  escaped_db_literal="$(sql_literal "$APP_DB_NAME")"
  db_exists="$(run_admin_psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$escaped_db_literal';" | tr -d '[:space:]')"

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

check_prebuilt_runtime_libraries() {
  local ldd_output
  local missing

  if [ ! -f "$PREBUILT_BINARY" ]; then
    return 0
  fi

  if ! command -v ldd >/dev/null 2>&1; then
    warn "ldd command not found; runtime library check was skipped."
    return 0
  fi

  ldd_output="$(ldd "$PREBUILT_BINARY" 2>&1 || true)"
  missing="$(printf '%s\n' "$ldd_output" | grep 'not found' || true)"

  if [ -n "$missing" ]; then
    echo "ERROR: missing runtime libraries for ./accac" >&2
    printf '%s\n' "$missing" >&2
    echo "Recommended command:" >&2
    echo "  sudo apt install -y postgresql-client libpq5 libgtk2.0-0" >&2
    exit 1
  fi
}

print_build_tool_versions() {
  local lazbuild_version=""
  local fpc_version=""

  lazbuild_version="$(lazbuild --version 2>/dev/null | head -n1 || true)"
  fpc_version="$(fpc -iV 2>/dev/null || true)"
  echo "lazbuild: ${lazbuild_version:-unknown}"
  echo "fpc: ${fpc_version:-unknown}"

  if ! printf '%s\n' "$lazbuild_version" | grep -q '2\.2\.0'; then
    warn "Target Lazarus version is 2.2.0; installed version may differ."
  fi

  if [ "$fpc_version" != "3.2.2" ]; then
    warn "Target Free Pascal version is 3.2.2; installed version may differ."
  fi
}

prepare_application_binary() {
  if [ -f "$PREBUILT_BINARY" ]; then
    chmod +x "$PREBUILT_BINARY" 2>/dev/null || true
    echo "Prebuilt binary found: ./accac"
    echo "Skipping Lazarus build step."
    return 0
  fi

  if [ ! -f "$PROJECT_FILE" ]; then
    fail "neither prebuilt binary nor Lazarus project file was found."
  fi

  if ! command -v lazbuild >/dev/null 2>&1; then
    fail "lazbuild command not found. Install Lazarus 2.2.0 and Free Pascal 3.2.2, or use the release archive with ./accac."
  fi

  if ! command -v fpc >/dev/null 2>&1; then
    fail "fpc command not found. Install Free Pascal 3.2.2."
  fi

  print_build_tool_versions
  chmod +x "$BUILD_SCRIPT" 2>/dev/null || true
  "$BUILD_SCRIPT"
}

if [ ! -f "$PREBUILT_BINARY" ] && [ ! -f "$PROJECT_FILE" ]; then
  fail "neither prebuilt binary nor Lazarus project file was found."
fi

if [ ! -f "$DB_SCRIPT" ]; then
  fail "database deployment script not found: $DB_SCRIPT"
fi

chmod +x "$ROOT_DIR"/scripts/*.sh 2>/dev/null || true
chmod +x "$DB_SCRIPT" 2>/dev/null || true

log_section "Preparing application binary"
prepare_application_binary

log_section "Preparing PostgreSQL"
ensure_postgresql
check_prebuilt_runtime_libraries

log_section "Preparing PostgreSQL role and database"
ensure_role
ensure_database

log_section "Applying migrations and grants"
APP_DB_NAME="$APP_DB_NAME" \
APP_DB_HOST="$APP_DB_HOST" \
APP_DB_PORT="$APP_DB_PORT" \
APP_DB_USER="$APP_DB_USER" \
POSTGRES_USER="$POSTGRES_USER" \
PSQL="$PSQL" \
CREATEDB_BIN="$CREATEDB_BIN" \
"$DB_SCRIPT"

log_section "Preparing local configuration"
prepare_config

log_section "Installation complete"
echo "Configuration file: $CONFIG_FILE"
if [ -f "$PREBUILT_BINARY" ]; then
  echo "Run the application with: ./accac"
else
  echo "Run the application with: ./scripts/run.sh"
fi

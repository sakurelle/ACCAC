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
APP_DB_PASSWORD="${APP_DB_PASSWORD:-${DB_PASSWORD:-}}"
POSTGRES_USER="${POSTGRES_USER:-${PGSYSTEM_USER:-postgres}}"
POSTGRES_TARGET_MAJOR="${POSTGRES_TARGET_MAJOR:-}"

MIN_POSTGRES_MAJOR=11
MIN_SERVER_VERSION_NUM=110000
APT_UPDATED=0

PSQL="${PSQL:-$(command -v psql || true)}"
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

  fail "Unable to switch to the local PostgreSQL OS user $POSTGRES_USER. Re-run as root, install sudo, or use direct PostgreSQL authentication."
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

extract_major_from_text() {
  local text="${1:-}"

  if [[ "$text" =~ ([0-9]+)(\.[0-9]+)? ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
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

  candidate="$(
    compgen -G '/usr/lib/postgresql/*/bin/postgres' 2>/dev/null | sort -V | tail -n1
  )"

  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

postgresql_server_software_present() {
  if find_postgres_binary >/dev/null 2>&1; then
    return 0
  fi

  if command -v pg_lsclusters >/dev/null 2>&1 && \
    pg_lsclusters --no-header 2>/dev/null | grep -q .; then
    return 0
  fi

  return 1
}

detect_installed_pg_major() {
  local postgres_binary
  local version_text
  local major
  local -a majors=()

  if postgres_binary="$(find_postgres_binary 2>/dev/null || true)"; then
    if [ -n "$postgres_binary" ]; then
      version_text="$("$postgres_binary" --version 2>/dev/null || true)"
      major="$(extract_major_from_text "$version_text" || true)"

      if [ -n "$major" ]; then
        majors+=("$major")
      fi
    fi
  fi

  if command -v pg_lsclusters >/dev/null 2>&1; then
    while read -r major; do
      if [[ "$major" =~ ^[0-9]+$ ]]; then
        majors+=("$major")
      fi
    done < <(pg_lsclusters --no-header 2>/dev/null | awk '{print $1}')
  fi

  if command -v pg_config >/dev/null 2>&1; then
    version_text="$(pg_config --version 2>/dev/null || true)"
    major="$(extract_major_from_text "$version_text" || true)"

    if [ -n "$major" ]; then
      majors+=("$major")
    fi
  fi

  if command -v psql >/dev/null 2>&1; then
    version_text="$(psql --version 2>/dev/null || true)"
    major="$(extract_major_from_text "$version_text" || true)"

    if [ -n "$major" ]; then
      majors+=("$major")
    fi
  fi

  if [ "${#majors[@]}" -eq 0 ]; then
    return 1
  fi

  printf '%s\n' "${majors[@]}" | sort -n | tail -n1
}

apt_update_once() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    run_with_privileges apt-get update
    APT_UPDATED=1
  fi
}

apt_install_packages() {
  if [ "$#" -eq 0 ]; then
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    fail "apt-get is not available. Install the required packages manually and rerun install_accac.sh."
  fi

  apt_update_once
  run_with_privileges apt-get install -y "$@"
}

package_available() {
  local candidate

  candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ { print $2; exit }')"
  [ -n "$candidate" ] && [ "$candidate" != "(none)" ]
}

select_postgresql_server_package() {
  if [ -n "$POSTGRES_TARGET_MAJOR" ]; then
    local explicit_package="postgresql-$POSTGRES_TARGET_MAJOR"

    if package_available "$explicit_package"; then
      printf '%s\n' "$explicit_package"
      return 0
    fi

    fail "Package $explicit_package is not available in the configured system repositories. Remove POSTGRES_TARGET_MAJOR or choose a version that exists in the OS repositories."
  fi

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

select_postgresql_client_package() {
  local server_package="$1"
  local major
  local candidate

  if [[ "$server_package" =~ ^postgresql-([0-9]+)$ ]]; then
    major="${BASH_REMATCH[1]}"
    candidate="postgresql-client-$major"

    if package_available "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  if package_available "postgresql-client"; then
    printf '%s\n' "postgresql-client"
    return 0
  fi

  printf '%s\n' ""
}

ensure_postgresql_available() {
  local installed_major=""
  local server_package=""
  local client_package=""
  local -a packages_to_install=()

  if postgresql_server_software_present; then
    installed_major="$(detect_installed_pg_major 2>/dev/null || true)"

    if [ -z "$installed_major" ]; then
      fail "PostgreSQL appears to be installed, but its major version could not be determined."
    fi

    if [ "$installed_major" -lt "$MIN_POSTGRES_MAJOR" ]; then
      fail "ACCAC requires PostgreSQL 11 or newer. Found PostgreSQL $installed_major. Upgrade the existing PostgreSQL installation before continuing."
    fi

    echo "Using installed PostgreSQL major version: $installed_major"

    if [ -z "$PSQL" ]; then
      client_package="postgresql-client-$installed_major"

      if ! package_available "$client_package"; then
        client_package="postgresql-client"
      fi

      log_section "Installing PostgreSQL client"
      apt_install_packages "$client_package"
      PSQL="${PSQL:-$(command -v psql || true)}"
    fi

    if [ -z "$PSQL" ]; then
      fail "psql command not found. Install the PostgreSQL client package and rerun install_accac.sh."
    fi

    return 0
  fi

  log_section "Installing PostgreSQL"
  server_package="$(select_postgresql_server_package)"
  client_package="$(select_postgresql_client_package "$server_package")"

  packages_to_install=("$server_package")

  if [ -n "$client_package" ]; then
    packages_to_install+=("$client_package")
  fi

  packages_to_install+=("libpq5" "libpq-dev")
  apt_install_packages "${packages_to_install[@]}"

  PSQL="${PSQL:-$(command -v psql || true)}"

  if [ -z "$PSQL" ]; then
    fail "psql command not found after installing PostgreSQL packages."
  fi

  installed_major="$(detect_installed_pg_major 2>/dev/null || true)"

  if [ -z "$installed_major" ] || [ "$installed_major" -lt "$MIN_POSTGRES_MAJOR" ]; then
    fail "ACCAC requires PostgreSQL 11 or newer. The installed PostgreSQL version could not be confirmed as compatible."
  fi

  echo "Installed PostgreSQL major version: $installed_major"
}

ensure_build_dependencies() {
  local -a packages_to_install=()

  if ! command -v lazbuild >/dev/null 2>&1 || ! command -v fpc >/dev/null 2>&1; then
    packages_to_install+=("lazarus" "fpc" "fpc-source" "fp-units-db" "libgtk2.0-dev")
  fi

  if [ "${#packages_to_install[@]}" -eq 0 ]; then
    log_section "Build dependencies"
    echo "Lazarus / Free Pascal toolchain is already installed."
    return 0
  fi

  log_section "Installing build dependencies"
  apt_install_packages "${packages_to_install[@]}"
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

query_server_version_num() {
  run_admin_psql -d postgres -tAc "SHOW server_version_num;" 2>/dev/null | tr -d '[:space:]'
}

ensure_supported_server_version() {
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
  return 1
}

if [ "$POSTGRES_USER" = "postgres" ] && \
  [ "$(id -un)" != "$POSTGRES_USER" ] && \
  { [ "$APP_DB_HOST" = "localhost" ] || [ -z "$APP_DB_HOST" ]; }; then
  USE_LOCAL_POSTGRES_OS_USER=1
fi

echo "=== ACCAC installation ==="

if [ ! -d "$DB_DIR" ]; then
  fail "database directory not found: $DB_DIR"
fi

if [ ! -f "$BUILD_SCRIPT" ]; then
  fail "build script not found: $BUILD_SCRIPT"
fi

if [ ! -f "$DB_SCRIPT" ]; then
  fail "database deployment script not found: $DB_SCRIPT"
fi

if [ ! -f "$EXAMPLE_CONFIG" ]; then
  fail "example config not found: $EXAMPLE_CONFIG"
fi

chmod +x "$ROOT_DIR"/scripts/*.sh 2>/dev/null || true
chmod +x "$DB_DIR/run_all.sh" 2>/dev/null || true
chmod +x "$ROOT_DIR/tests/jmeter/run_accac_db_limits.sh" 2>/dev/null || true

ensure_postgresql_available
ensure_build_dependencies
start_postgresql_service || true

log_section "Checking PostgreSQL server version"
ensure_supported_server_version

log_section "Checking application database role"
ROLE_EXISTS="$(query_role_exists | tr -d '[:space:]')"

if [ "$ROLE_EXISTS" = "1" ]; then
  echo "Role $APP_DB_USER already exists."
elif [ -n "$APP_DB_PASSWORD" ]; then
  echo "Role $APP_DB_USER was not found."
  echo "db/postgresql/run_all.sh will create it automatically."
else
  echo "Role $APP_DB_USER was not found."
  echo "Create it before running the installer:"
  manual_create_user_command
  echo
  echo "Or rerun the installer with APP_DB_PASSWORD to allow automatic role creation."
  exit 1
fi

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

log_section "Building application"
"$BUILD_SCRIPT"

log_section "Installation complete"
echo "Configuration file: $LOCAL_CONFIG"
echo "Run the application with: ./scripts/run.sh"

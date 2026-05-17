#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DB_NAME="${APP_DB_NAME:-accac}"
APP_DB_USER="${APP_DB_USER:-accac_user}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-change_me}"
APP_DB_HOST="${APP_DB_HOST:-localhost}"
APP_DB_PORT="${APP_DB_PORT:-5432}"
POSTGRES_TARGET_MAJOR="${POSTGRES_TARGET_MAJOR:-}"

PREBUILT_BINARY="$ROOT_DIR/accac"
BUILD_OUTPUT="$ROOT_DIR/build/accac"
PROJECT_FILE="$ROOT_DIR/src/accac.lpi"
CONFIG_FILE="$ROOT_DIR/accac.ini"

log() {
  printf "\n=== %s ===\n" "$1"
}

warn() {
  echo "WARNING: $*" >&2
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_sudo() {
  if ! command_exists sudo; then
    die "sudo is required for package installation and PostgreSQL setup."
  fi

  if ! sudo -n true 2>/dev/null; then
    echo "sudo password may be required."
    sudo true || die "sudo access is required."
  fi
}

sql_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

sql_identifier() {
  printf "%s" "$1" | sed 's/"/""/g'
}

package_available() {
  local package="$1"
  local candidate

  candidate="$(apt-cache policy "$package" 2>/dev/null | awk '/Candidate:/ { print $2 }' | head -n 1)"

  [ -n "$candidate" ] && [ "$candidate" != "(none)" ]
}

install_package_if_available() {
  local package="$1"

  if package_available "$package"; then
    echo "Installing package: $package"
    sudo apt-get install -y "$package"
    return 0
  fi

  echo "Package is not available, skipping: $package"
  return 1
}

install_first_available_package() {
  local title="$1"
  shift

  local package

  for package in "$@"; do
    if package_available "$package"; then
      echo "Installing $title: $package"
      sudo apt-get install -y "$package"
      return 0
    fi
  done

  warn "no available package found for: $title"
  warn "checked: $*"
  return 1
}

get_astra_version() {
  if [ ! -r /etc/os-release ]; then
    echo "unknown"
    return 0
  fi

  local os_info
  os_info="$(cat /etc/os-release)"

  if echo "$os_info" | grep -qi "astra"; then
    if echo "$os_info" | grep -q "1\.7"; then
      echo "1.7"
      return 0
    fi

    if echo "$os_info" | grep -q "1\.8"; then
      echo "1.8"
      return 0
    fi
  fi

  echo "unknown"
}

ensure_psql_command() {
  if command_exists psql; then
    return 0
  fi

  install_package_if_available "postgresql-client" || true

  if ! command_exists psql; then
    die "psql command was not found.

Install PostgreSQL client package, for example:
  sudo apt install -y postgresql-client
or version-specific client package:
  sudo apt install -y postgresql-client-13
  sudo apt install -y postgresql-client-11"
  fi
}

get_postgres_server_version_num() {
  if ! command_exists psql; then
    return 0
  fi

  sudo -u postgres psql -d postgres -tAc "SHOW server_version_num;" 2>/dev/null | tr -d '[:space:]' || true
}

check_supported_postgres_version() {
  local version_num="$1"

  if [ -z "$version_num" ]; then
    return 1
  fi

  if ! [[ "$version_num" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if [ "$version_num" -lt 110000 ]; then
    die "unsupported PostgreSQL version. ACCAC requires PostgreSQL 11 or newer."
  fi

  return 0
}

start_postgresql() {
  log "Starting PostgreSQL"

  if command_exists systemctl; then
    sudo systemctl enable postgresql || true
    sudo systemctl start postgresql || true
  else
    sudo service postgresql start || true
  fi

  ensure_psql_command

  if ! sudo -u postgres psql -d postgres -tAc "SELECT 1;" >/dev/null 2>&1; then
    die "PostgreSQL server is not available after start attempt."
  fi
}

install_runtime_libraries() {
  log "Installing runtime libraries"

  install_first_available_package "PostgreSQL runtime library" \
    libpq5 || true

  install_first_available_package "GTK2 runtime library" \
    libgtk2.0-0t64 \
    libgtk2.0-0 || true

  echo "Runtime packages check completed."
  echo "The installer will additionally verify ./accac with ldd."
}

install_versioned_postgresql() {
  local major="$1"
  local server_package="postgresql-$major"
  local client_package="postgresql-client-$major"

  if ! package_available "$server_package"; then
    return 1
  fi

  echo "Selected PostgreSQL server package: $server_package"
  sudo apt-get install -y "$server_package"

  if package_available "$client_package"; then
    echo "Installing PostgreSQL client package: $client_package"
    sudo apt-get install -y "$client_package"
  else
    echo "PostgreSQL client package not found: $client_package"
    echo "Will check psql command after server installation."
  fi

  ensure_psql_command
  start_postgresql

  local version_num
  version_num="$(get_postgres_server_version_num)"
  check_supported_postgres_version "$version_num"

  echo "PostgreSQL server version is compatible: $version_num"
  return 0
}

install_generic_postgresql() {
  if ! package_available "postgresql"; then
    return 1
  fi

  echo "Version-specific PostgreSQL package was not found."
  echo "Installing generic PostgreSQL package available in configured repositories: postgresql"

  sudo apt-get install -y postgresql

  if package_available "postgresql-client"; then
    sudo apt-get install -y postgresql-client
  fi

  ensure_psql_command
  start_postgresql

  local version_num
  version_num="$(get_postgres_server_version_num)"
  check_supported_postgres_version "$version_num"

  echo "PostgreSQL server version is compatible: $version_num"
  return 0
}

install_postgresql_server() {
  log "Installing PostgreSQL"

  sudo apt-get update

  local astra_version
  astra_version="$(get_astra_version)"

  local versions=()

  if [ -n "$POSTGRES_TARGET_MAJOR" ]; then
    case "$POSTGRES_TARGET_MAJOR" in
      11|12|13)
        versions=("$POSTGRES_TARGET_MAJOR")
        echo "POSTGRES_TARGET_MAJOR is set. Preferred PostgreSQL version: $POSTGRES_TARGET_MAJOR."
        ;;
      *)
        die "POSTGRES_TARGET_MAJOR must be 11, 12 or 13."
        ;;
    esac
  else
    case "$astra_version" in
      1.7)
        echo "Detected Astra Linux 1.7. Preferred PostgreSQL version: 11."
        versions=(11)
        ;;
      1.8)
        echo "Detected Astra Linux 1.8. Preferred PostgreSQL version: 13."
        versions=(13)
        ;;
      *)
        echo "Astra Linux version was not detected. Trying PostgreSQL versions: 13, 12, 11."
        versions=(13 12 11)
        ;;
    esac
  fi

  local major

  for major in "${versions[@]}"; do
    if install_versioned_postgresql "$major"; then
      return 0
    fi
  done

  if install_generic_postgresql; then
    return 0
  fi

  die "PostgreSQL package was not found in configured APT repositories.

Checked preferred packages:
  - postgresql-13
  - postgresql-12
  - postgresql-11
  - postgresql

For Astra Linux 1.7:
  sudo apt update
  sudo apt install -y postgresql-11 postgresql-client-11

For Astra Linux 1.8:
  sudo apt update
  apt-cache policy postgresql-13
  apt-cache policy postgresql
  sudo apt install -y postgresql"
}

prepare_postgresql() {
  log "Preparing PostgreSQL"

  sudo apt-get update

  local version_num
  version_num="$(get_postgres_server_version_num)"

  if [ -n "$version_num" ]; then
    start_postgresql

    version_num="$(get_postgres_server_version_num)"
    check_supported_postgres_version "$version_num"

    echo "Using installed PostgreSQL server version: $version_num"
    ensure_psql_command
    install_runtime_libraries
    return 0
  fi

  install_postgresql_server
  ensure_psql_command
  install_runtime_libraries
}

create_application_role() {
  log "Checking application database role"

  local escaped_user_literal
  escaped_user_literal="$(sql_literal "$APP_DB_USER")"

  local role_exists
  role_exists="$(
    sudo -u postgres psql -d postgres -tAc \
      "SELECT 1 FROM pg_roles WHERE rolname = '$escaped_user_literal';" \
      | tr -d '[:space:]'
  )"

  local escaped_user_ident
  local escaped_password_literal

  escaped_user_ident="$(sql_identifier "$APP_DB_USER")"
  escaped_password_literal="$(sql_literal "$APP_DB_PASSWORD")"

  if [ "$role_exists" = "1" ]; then
    echo "Role $APP_DB_USER already exists."

    if [ "${RESET_APP_DB_PASSWORD:-0}" = "1" ]; then
      echo "Resetting password for role $APP_DB_USER."
      sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 \
        -c "ALTER USER \"$escaped_user_ident\" WITH PASSWORD '$escaped_password_literal';"
    fi

    return 0
  fi

  echo "Creating role $APP_DB_USER."
  sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 \
    -c "CREATE USER \"$escaped_user_ident\" WITH PASSWORD '$escaped_password_literal';"
}

create_application_database() {
  log "Checking application database"

  local escaped_db_literal
  escaped_db_literal="$(sql_literal "$APP_DB_NAME")"

  local db_exists
  db_exists="$(
    sudo -u postgres psql -d postgres -tAc \
      "SELECT 1 FROM pg_database WHERE datname = '$escaped_db_literal';" \
      | tr -d '[:space:]'
  )"

  if [ "$db_exists" = "1" ]; then
    echo "Database $APP_DB_NAME already exists."
    return 0
  fi

  echo "Creating database $APP_DB_NAME."
  sudo -u postgres createdb -O "$APP_DB_USER" "$APP_DB_NAME"
}

prepare_runtime_fixtures() {
  local fixtures_dir="$ROOT_DIR/db/postgresql/fixtures"

  if [ ! -d "$fixtures_dir" ]; then
    die "fixtures directory not found: $fixtures_dir"
  fi

  local runtime_fixtures
  runtime_fixtures="$(mktemp -d /tmp/accac-fixtures.XXXXXX)"

  cp -R "$fixtures_dir/." "$runtime_fixtures/"
  chmod -R a+rX "$runtime_fixtures"

  printf "%s" "$runtime_fixtures"
}

run_psql_file() {
  local database="$1"
  local file="$2"
  shift 2

  if [ ! -r "$file" ]; then
    die "migration file is not readable by current user: $file"
  fi

  echo "Applying $(basename "$file")..."

  (
    cd /tmp
    sudo -u postgres psql \
      -v ON_ERROR_STOP=1 \
      -v APP_DB_NAME="$APP_DB_NAME" \
      -v APP_DB_USER="$APP_DB_USER" \
      "$@" \
      -d "$database" < "$file"
  )
}

apply_migrations() {
  log "Applying migrations and grants"

  local migrations_dir="$ROOT_DIR/db/postgresql/migrations"

  if [ ! -d "$migrations_dir" ]; then
    die "migrations directory not found: $migrations_dir"
  fi

  local migrations=(
    "001_schema.sql"
    "002_tables.sql"
    "003_indexes.sql"
    "004_functions.sql"
    "005_procedures.sql"
    "006_triggers.sql"
    "007_seed.sql"
    "008_grants.sql"
  )

  local migration
  local runtime_fixtures=""

  for migration in "${migrations[@]}"; do
    local file="$migrations_dir/$migration"

    if [ ! -f "$file" ]; then
      die "required migration not found: $file"
    fi

    if [ "$migration" = "007_seed.sql" ]; then
      runtime_fixtures="$(prepare_runtime_fixtures)"
      run_psql_file "$APP_DB_NAME" "$file" -v base_dir="$runtime_fixtures"
    elif [ "$migration" = "008_grants.sql" ]; then
      run_psql_file "$APP_DB_NAME" "$file" \
        -v APP_DB_NAME="$APP_DB_NAME" \
        -v APP_DB_USER="$APP_DB_USER"
    else
      run_psql_file "$APP_DB_NAME" "$file"
    fi
  done

  if [ -n "$runtime_fixtures" ] && [ -d "$runtime_fixtures" ]; then
    rm -rf "$runtime_fixtures"
  fi
}

find_config_example() {
  local candidates=(
    "$ROOT_DIR/config/accac.example.ini"
    "$ROOT_DIR/src/config/accac.example.ini"
  )

  local candidate

  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf "%s" "$candidate"
      return 0
    fi
  done

  echo "ERROR: example config not found." >&2
  echo "Checked:" >&2

  for candidate in "${candidates[@]}"; do
    echo "  - $candidate" >&2
  done

  exit 1
}

set_ini_value() {
  local key="$1"
  local value="$2"
  local tmp_file

  tmp_file="$(mktemp)"

  if grep -Eq "^[[:space:]]*$key[[:space:]]*=" "$CONFIG_FILE"; then
    awk -v key="$key" -v value="$value" '
      $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
        print key "=" value
        next
      }
      { print }
    ' "$CONFIG_FILE" > "$tmp_file"

    mv "$tmp_file" "$CONFIG_FILE"
  else
    rm -f "$tmp_file"
    printf "%s=%s\n" "$key" "$value" >> "$CONFIG_FILE"
  fi
}

prepare_config() {
  log "Preparing application config"

  if [ -f "$CONFIG_FILE" ]; then
    echo "Local config already exists: $CONFIG_FILE"
    return 0
  fi

  local config_example
  config_example="$(find_config_example)"

  cp "$config_example" "$CONFIG_FILE"

  set_ini_value "host" "$APP_DB_HOST"
  set_ini_value "port" "$APP_DB_PORT"
  set_ini_value "database" "$APP_DB_NAME"
  set_ini_value "user" "$APP_DB_USER"
  set_ini_value "password" "$APP_DB_PASSWORD"

  echo "Created local config: $CONFIG_FILE"
}

check_binary_runtime_libraries() {
  if [ ! -f "$PREBUILT_BINARY" ]; then
    return 0
  fi

  if ! command_exists ldd; then
    warn "ldd command not found. Runtime library check skipped."
    return 0
  fi

  local missing
  missing="$(ldd "$PREBUILT_BINARY" 2>/dev/null | grep "not found" || true)"

  if [ -n "$missing" ]; then
    echo "$missing"
    die "missing runtime libraries for ./accac.

Check Astra Linux repositories and install the missing runtime packages."
  fi
}

version_greater_than() {
  local current="$1"
  local maximum="$2"

  if ! command_exists sort; then
    return 1
  fi

  local highest
  highest="$(printf "%s\n%s\n" "$current" "$maximum" | sort -V | tail -n 1)"

  [ "$highest" != "$maximum" ]
}

check_lazarus_version_for_source_mode() {
  if ! command_exists lazbuild; then
    die "lazbuild not found.

For release installation use archive with prebuilt ./accac.
For source build install Lazarus 2.2.0 and Free Pascal 3.2.2."
  fi

  local raw_version
  local version

  raw_version="$(lazbuild --version 2>/dev/null | head -n 1 || true)"
  version="$(printf "%s" "$raw_version" | grep -Eo '[0-9]+(\.[0-9]+){1,2}' | head -n 1 || true)"

  echo "Detected lazbuild version: ${raw_version:-unknown}"

  if [ -z "$version" ]; then
    warn "could not parse Lazarus version. Expected Lazarus 2.2.0 or older."
    return 0
  fi

  if version_greater_than "$version" "2.2.0"; then
    die "unsupported Lazarus version: $version. ACCAC source build requires Lazarus 2.2.0 or older."
  fi
}

publish_built_binary() {
  if [ ! -f "$BUILD_OUTPUT" ]; then
    die "source build finished without binary: $BUILD_OUTPUT"
  fi

  cp "$BUILD_OUTPUT" "$PREBUILT_BINARY"
  chmod +x "$PREBUILT_BINARY"
  echo "Prepared launch binary: ./accac"
}

prepare_application_binary() {
  log "Preparing application binary"

  if [ -f "$PROJECT_FILE" ]; then
    echo "Source mode detected."

    check_lazarus_version_for_source_mode

    if [ ! -x "$ROOT_DIR/scripts/build.sh" ]; then
      chmod +x "$ROOT_DIR/scripts/build.sh"
    fi

    bash "$ROOT_DIR/scripts/build.sh"
    publish_built_binary
    return 0
  fi

  if [ -f "$PREBUILT_BINARY" ]; then
    chmod +x "$PREBUILT_BINARY"
    echo "Prebuilt binary found: ./accac"
    echo "Skipping Lazarus build step."
    return 0
  fi

  if [ ! -f "$PROJECT_FILE" ]; then
    die "neither prebuilt binary nor Lazarus project file was found."
  fi
}

launch_application() {
  log "Launching ACCAC"

  if [ ! -f "$PREBUILT_BINARY" ]; then
    die "launch binary was not found: $PREBUILT_BINARY"
  fi

  chmod +x "$PREBUILT_BINARY"
  echo "Starting ./accac"
  cd "$ROOT_DIR"
  exec "./accac"
}

main() {
  log "ACCAC installation"

  require_sudo
  prepare_application_binary
  prepare_postgresql
  create_application_role
  create_application_database
  apply_migrations
  prepare_config
  check_binary_runtime_libraries

  log "Installation completed"
  launch_application
}

main "$@"

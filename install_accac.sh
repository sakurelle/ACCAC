#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_DIR="$ROOT_DIR/db/postgresql"
CONFIG_DIR="$ROOT_DIR/src/config"
BUILD_SCRIPT="$ROOT_DIR/scripts/build.sh"
DB_SCRIPT="$DB_DIR/run_all.sh"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-accac}"
DB_USER="${DB_USER:-accac_user}"
DB_PASSWORD="${DB_PASSWORD:-change_me}"
DB_SCHEMA="${DB_SCHEMA:-sc_accac}"
PGSYSTEM_USER="${PGSYSTEM_USER:-postgres}"

PSQL="${PSQL:-$(command -v psql || true)}"

echo "=== ACCAC installation ==="

if [ ! -d "$DB_DIR" ]; then
  echo "ERROR: database directory not found: $DB_DIR"
  exit 1
fi

if [ ! -f "$BUILD_SCRIPT" ]; then
  echo "ERROR: build script not found: $BUILD_SCRIPT"
  exit 1
fi

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

if [ -z "$PSQL" ]; then
  echo "ERROR: psql command not found after installation"
  exit 1
fi

echo
echo "=== Starting PostgreSQL ==="
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo
echo "=== Creating or updating database role ==="
sudo -u "$PGSYSTEM_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d postgres <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE ROLE "$DB_USER" LOGIN PASSWORD '$DB_PASSWORD';
  ELSE
    ALTER ROLE "$DB_USER" WITH LOGIN PASSWORD '$DB_PASSWORD';
  END IF;
END
\$\$;
EOF

echo
echo "=== Applying migrations ==="
chmod +x "$DB_SCRIPT"
DB_NAME="$DB_NAME" \
DB_PORT="$DB_PORT" \
DB_USER="$DB_USER" \
PGSYSTEM_USER="$PGSYSTEM_USER" \
PSQL="$PSQL" \
"$DB_SCRIPT"

echo
echo "=== Writing local configuration ==="
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/accac.ini" <<EOF
[database]
host=$DB_HOST
port=$DB_PORT
database=$DB_NAME
user=$DB_USER
password=$DB_PASSWORD
schema=$DB_SCHEMA
EOF

echo "Created: $CONFIG_DIR/accac.ini"

echo
echo "=== Building application ==="
chmod +x "$BUILD_SCRIPT"
"$BUILD_SCRIPT"

echo
echo "=== Installation complete ==="
echo "Run the application with: ./scripts/run.sh"

#!/usr/bin/env bash
set -euo pipefail

DB_NAME="${DB_NAME:-accac}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-accac_user}"
PGSYSTEM_USER="${PGSYSTEM_USER:-postgres}"
PSQL="${PSQL:-$(command -v psql || true)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
MIGRATIONS=(
  "001_schema.sql"
  "002_tables.sql"
  "003_indexes.sql"
  "004_functions.sql"
  "005_procedures.sql"
  "006_triggers.sql"
  "007_seed.sql"
)

if [ -z "$PSQL" ]; then
  echo "ERROR: psql command not found"
  exit 1
fi

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "ERROR: migrations directory not found: $MIGRATIONS_DIR"
  exit 1
fi

echo "Checking database $DB_NAME..."

DB_EXISTS="$(sudo -u "$PGSYSTEM_USER" "$PSQL" -p "$DB_PORT" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")"

if [ "$DB_EXISTS" != "1" ]; then
  echo "Creating database $DB_NAME..."
  sudo -u "$PGSYSTEM_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
else
  echo "Database $DB_NAME already exists."
fi

for migration in "${MIGRATIONS[@]}"; do
  migration_path="$MIGRATIONS_DIR/$migration"

  if [ ! -f "$migration_path" ]; then
    echo "ERROR: migration not found: $migration_path"
    exit 1
  fi

  echo "Applying $migration..."

  if [ "$migration" = "007_seed.sql" ]; then
    sudo -u "$PGSYSTEM_USER" "$PSQL" \
      -v ON_ERROR_STOP=1 \
      -v base_dir="$FIXTURES_DIR" \
      -p "$DB_PORT" \
      -d "$DB_NAME" \
      -f "$migration_path"
  else
    sudo -u "$PGSYSTEM_USER" "$PSQL" \
      -v ON_ERROR_STOP=1 \
      -p "$DB_PORT" \
      -d "$DB_NAME" \
      -f "$migration_path"
  fi
done

echo "Database $DB_NAME is ready."

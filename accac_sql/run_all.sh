#!/bin/bash
set -e

DB_NAME="${DB_NAME:-db_ics_accac}"
DB_PORT="${DB_PORT:-5433}"
DB_USER="${DB_USER:-postgres}"

if [ -z "$PSQL" ]; then
  echo "Ошибка: psql не найден"
  exit 1
fi

PSQL="${PSQL:-$(command -v psql)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="$SCRIPT_DIR"

echo "Проверка наличия БД $DB_NAME..."

DB_EXISTS=$(sudo -u "$DB_USER" "$PSQL" -p "$DB_PORT" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")

if [ "$DB_EXISTS" != "1" ]; then
    echo "БД $DB_NAME не найдена. Создаю..."
    sudo -u "$DB_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
else
    echo "БД $DB_NAME уже существует."
fi

echo "Запуск schema.sql..."
sudo -u "$DB_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d "$DB_NAME" -f "$SQL_DIR/schema.sql"

echo "Запуск tables.sql..."
sudo -u "$DB_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d "$DB_NAME" -f "$SQL_DIR/tables.sql"

echo "Запуск indexes.sql..."
sudo -u "$DB_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d "$DB_NAME" -f "$SQL_DIR/indexes.sql"

echo "Запуск functions.sql..."
sudo -u "$DB_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d "$DB_NAME" -f "$SQL_DIR/functions.sql"

echo "Запуск procedure.sql..."
sudo -u "$DB_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d "$DB_NAME" -f "$SQL_DIR/procedure.sql"

echo "Запуск triggers.sql..."
sudo -u "$DB_USER" "$PSQL" -v ON_ERROR_STOP=1 -p "$DB_PORT" -d "$DB_NAME" -f "$SQL_DIR/triggers.sql"

echo "Запуск seed.sql..."
sudo -u "$DB_USER" "$PSQL" -v ON_ERROR_STOP=1 -v base_dir="$SQL_DIR" -p "$DB_PORT" -d "$DB_NAME" -f "$SQL_DIR/seed.sql"

echo "Готово. БД $DB_NAME полностью подготовлена."

#!/bin/bash

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_DIR="$ROOT_DIR/accac_sql"
APP_DIR="$ROOT_DIR/accac_lazarus"

DB_NAME="db_ics_accac"
DB_USER="postgres"
DB_PASSWORD="1234"
DB_PORT="5433"

echo "=== Установка ACCAC ==="

if [ ! -d "$SQL_DIR" ]; then
  echo "Ошибка: не найдена папка accac_sql"
  exit 1
fi

if [ ! -d "$APP_DIR" ]; then
  echo "Ошибка: не найдена папка accac_lazarus"
  exit 1
fi

echo
echo "=== 1. Обновление пакетов ==="
sudo apt update

echo
echo "=== 2. Установка PostgreSQL 13 ==="
if ! dpkg -s postgresql-13 >/dev/null 2>&1; then
  echo "PostgreSQL 13 не найден. Устанавливаю..."
  sudo apt install -y postgresql-13 postgresql-client-13
else
  echo "PostgreSQL 13 уже установлен."
fi

echo
echo "=== 3. Проверка запуска PostgreSQL ==="
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo
echo "=== 4. Настройка пароля пользователя postgres ==="
sudo -u postgres /usr/lib/postgresql/13/bin/psql -p "$DB_PORT" -d postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" || true

echo
echo "=== 5. Подготовка SQL-скрипта ==="
chmod +x "$SQL_DIR/run_all.sh"

echo
echo "=== 6. Развертывание базы данных ==="
cd "$SQL_DIR"
./run_all.sh

echo
echo "=== 7. Проверка файла accac.ini ==="
INI_FILE="$APP_DIR/accac.ini"

cat > "$INI_FILE" <<EOF
[database]
Host=localhost
Port=$DB_PORT
Database=$DB_NAME
User=$DB_USER
Password=$DB_PASSWORD
Schema=sc_accac
EOF

echo "Файл accac.ini обновлен: $INI_FILE"

echo
echo "=== Установка завершена ==="
echo "База данных создана и заполнена."
echo
echo "Для запуска программы выполните:"
echo "cd \"$APP_DIR\""
echo "chmod +x project1"
echo "./project1"

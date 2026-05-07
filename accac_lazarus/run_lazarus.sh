#!/bin/bash
set -e

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$APP_DIR/project1.lpi"
EXEC_FILE="$APP_DIR/project1"

echo "=== Установка Lazarus / Free Pascal ==="

sudo apt update

sudo apt install -y \
  lazarus \
  fpc \
  fpc-source \
  fp-units-db \
  libpq5 \
  libpq-dev

echo
echo "=== Проверка проекта Lazarus ==="

if [ ! -f "$PROJECT_FILE" ]; then
  echo "Ошибка: не найден файл project1.lpi"
  exit 1
fi

cd "$APP_DIR"

echo
echo "=== Удаление старого исполняемого файла ==="
rm -f "$EXEC_FILE"

echo
echo "=== Компиляция проекта Lazarus ==="
lazbuild -B project1.lpi

echo
echo "=== Проверка исполняемого файла ==="

if [ ! -f "$EXEC_FILE" ]; then
  echo "Ошибка: после сборки файл project1 не создан"
  exit 1
fi

chmod +x "$EXEC_FILE"

echo
echo "=== Запуск приложения ==="
"$EXEC_FILE"
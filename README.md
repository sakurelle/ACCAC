# ACCAC

## Назначение проекта

ACCAC — настольное приложение для работы с данными антенных систем. Приложение использует PostgreSQL как хранилище данных, а пользовательский интерфейс реализован на Lazarus / Free Pascal.

## Требования

Для запуска готового release-архива:

- Astra Linux 1.7 или 1.8;
- PostgreSQL 11 и выше;
- libpq5;
- libgtk2.0-0.

Для сборки из исходников:

- Lazarus 2.2.0;
- Free Pascal 3.2.2.

## Установка

Основной сценарий — установка из готового release-архива:

```bash
tar -xzf accac-linux-astra.tar.gz
cd accac
chmod +x accac install_accac.sh scripts/*.sh db/postgresql/run_all.sh
./install_accac.sh
./accac
```

Ручные SQL-команды не нужны. Установщик сам создаёт роль `accac_user`, создаёт базу `accac`, применяет миграции и создаёт `accac.ini`. Может потребоваться ввод sudo-пароля ОС. Lazarus и Free Pascal для release-архива не требуются.

Если установщик сообщает, что PostgreSQL 11, 12 или 13 не найден в репозиториях, нужно подключить системные репозитории Astra Linux. Установщик не подключает репозитории автоматически, потому что это системная настройка ОС.

Для Astra Linux 1.7 рекомендуемый пакет:

```bash
sudo apt update
sudo apt install -y postgresql-11 postgresql-client libpq5 libgtk2.0-0
```

Для Astra Linux 1.8 сначала проверьте доступные пакеты:

```bash
apt-cache policy postgresql-13
apt-cache policy postgresql-12
apt-cache policy postgresql-11
```

Затем установите одну из разрешённых версий:

```bash
sudo apt install -y postgresql-13 postgresql-client libpq5 libgtk2.0-0
# или
sudo apt install -y postgresql-12 postgresql-client libpq5 libgtk2.0-0
# или
sudo apt install -y postgresql-11 postgresql-client libpq5 libgtk2.0-0
```

Сборка из исходников:

```bash
git clone https://github.com/sakurelle/ACCAC.git
cd ACCAC
chmod +x install_accac.sh scripts/*.sh db/postgresql/run_all.sh tests/jmeter/run_accac_db_limits.sh
./install_accac.sh
./scripts/run.sh
```

## Настройка конфигурации

Рабочий конфиг `accac.ini` создаётся установщиком автоматически и не хранится в Git. В release-архиве шаблон лежит в `config/accac.example.ini`, а в исходниках — в `src/config/accac.example.ini`.

По умолчанию используются значения:

```ini
[database]
host=localhost
port=5432
database=accac
user=accac_user
password=change_me
```

Их можно переопределить перед запуском установщика через переменные окружения, например:

```bash
APP_DB_NAME=accac APP_DB_USER=accac_user APP_DB_PASSWORD=change_me ./install_accac.sh
```

Если роль уже существует и нужно принудительно обновить пароль, используйте:

```bash
RESET_APP_DB_PASSWORD=1 ./install_accac.sh
```

## Структура репозитория

```text
ACCAC/
├── README.md
├── install_accac.sh
├── src/
├── db/
├── scripts/
├── tests/
├── docs/
└── .github/
```

- `src/` — исходный код Lazarus / Free Pascal;
- `db/postgresql/migrations/` — SQL-миграции;
- `scripts/` — вспомогательные скрипты;
- `tests/jmeter/` — JMeter-тесты;
- `docs/` — документация и материалы отчёта;
- `.github/` — CI/CD.

Release-архив имеет структуру:

```text
accac/
├── accac
├── install_accac.sh
├── scripts/
├── db/
├── config/
│   └── accac.example.ini
└── README.md
```
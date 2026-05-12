# ACCAC

## Назначение проекта

ACCAC - настольное приложение для отображения состава и состояния антенных комплексов. Система хранит предметные данные и параметры интерфейсного макета в PostgreSQL, а клиент на Lazarus визуализирует макет, антенны, связанные города, центры и статусы.

## Используемые технологии

- Lazarus / Free Pascal
- PostgreSQL
- Bash-скрипты для сборки и разворачивания БД
- Apache JMeter для функционального и нагрузочного тестирования
- PowerShell для генерации итогового DOCX-отчета

## Структура репозитория

```text
ACCAC/
├── install_accac.sh
├── src/
│   ├── forms/
│   ├── domain/
│   ├── infrastructure/
│   └── config/
├── db/postgresql/
│   ├── migrations/
│   ├── fixtures/hex/
│   └── run_all.sh
├── tests/jmeter/
│   ├── plans/
│   ├── data/
│   └── run_accac_db_limits.sh
├── docs/
│   ├── architecture/
│   ├── testing/
│   └── build_testing_report.ps1
└── scripts/
    ├── build.sh
    ├── run.sh
    └── clean.sh
```

## Требования

- Linux с Bash
- PostgreSQL и утилита `psql`
- Lazarus / Free Pascal (`lazbuild`, `fpc`)
- `libpq` и `libgtk2.0-dev` для сборки клиента
- Apache JMeter 5.6.x для запуска тестов

## Установка

Главный установочный сценарий расположен в корне репозитория:

```bash
chmod +x install_accac.sh
./install_accac.sh
```

Скрипт:

- устанавливает необходимые пакеты;
- подготавливает роль и базу PostgreSQL;
- применяет миграции из `db/postgresql/migrations/`;
- создает локальный конфиг `src/config/accac.ini`;
- собирает приложение через `scripts/build.sh`.

## Настройка конфигурации

В репозитории хранится только шаблон:

```text
src/config/accac.example.ini
```

Для локального запуска создайте рабочий конфиг:

```bash
cp src/config/accac.example.ini src/config/accac.ini
```

При необходимости измените параметры подключения:

```ini
[database]
host=localhost
port=5432
database=accac
user=accac_user
password=change_me
schema=sc_accac
```

## Развертывание БД

Полный прогон миграций:

```bash
chmod +x db/postgresql/run_all.sh
DB_NAME=accac DB_USER=accac_user DB_PORT=5432 ./db/postgresql/run_all.sh
```

Скрипт выполняет файлы в фиксированном порядке:

1. `db/postgresql/migrations/001_schema.sql`
2. `db/postgresql/migrations/002_tables.sql`
3. `db/postgresql/migrations/003_indexes.sql`
4. `db/postgresql/migrations/004_functions.sql`
5. `db/postgresql/migrations/005_procedures.sql`
6. `db/postgresql/migrations/006_triggers.sql`
7. `db/postgresql/migrations/007_seed.sql`

Для `007_seed.sql` автоматически используется каталог `db/postgresql/fixtures/hex/`.

## Сборка

```bash
chmod +x scripts/build.sh
./scripts/build.sh
```

Сборка использует Lazarus-проект:

```text
src/project1.lpi
```

Исполняемый файл создается в:

```text
build/project1
```

## Запуск

```bash
chmod +x scripts/run.sh
./scripts/run.sh
```

Приложение читает локальный конфиг `src/config/accac.ini`. Если файл лежит рядом с бинарником, он тоже будет найден.

## Тестирование

Функциональный и нагрузочный планы JMeter:

- `tests/jmeter/plans/ACCAC.jmx`
- `tests/jmeter/plans/ACCAC_DB_LIMITS.jmx`

CSV-данные для параметризации:

- `tests/jmeter/data/cmp_ids.csv`
- `tests/jmeter/data/ant_ids.csv`

Пример запуска основного плана:

```bash
mkdir -p tests/jmeter/jmeter-results/accac

jmeter \
  -n \
  -t tests/jmeter/plans/ACCAC.jmx \
  -l tests/jmeter/jmeter-results/accac/result.jtl \
  -j tests/jmeter/jmeter-results/accac/jmeter.log \
  -e \
  -o tests/jmeter/jmeter-results/accac/report
```

Пример поиска лимита по потокам:

```bash
chmod +x tests/jmeter/run_accac_db_limits.sh
./tests/jmeter/run_accac_db_limits.sh
```

## Документация

- Архитектурное описание: `docs/architecture/architecture.md`
- Исходный markdown-отчет по тестированию: `docs/testing/testing_report.md`
- Генератор DOCX-отчета: `docs/build_testing_report.ps1`
- Дополнительный архитектурный документ: `docs/architecture/Архитектура_ACCAC.docx`

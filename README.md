# ACCAC

## Назначение проекта

ACCAC — настольное приложение на Lazarus / Free Pascal для отображения и редактирования данных об антенных комплексах. Клиентское приложение получает данные из PostgreSQL, строит визуальный макет комплекса и позволяет работать с центрами, городами, антеннами, состояниями, моделями и layout-компонентами.

## Используемые технологии

- Lazarus / Free Pascal
- PostgreSQL
- Bash-скрипты для установки, развёртывания БД и запуска
- Apache JMeter для функционального и нагрузочного тестирования
- PowerShell для сборки итогового DOCX-отчёта

## Структура репозитория

```text
ACCAC/
├── install_accac.sh
├── src/
│   ├── project1.lpi
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

- проверяет наличие PostgreSQL и инструментов сборки;
- при необходимости устанавливает системные пакеты;
- проверяет роль приложения в PostgreSQL;
- запускает миграции и выдачу прав через `db/postgresql/run_all.sh`;
- подготавливает локальный `accac.ini`, если он ещё не создан;
- собирает приложение через `scripts/build.sh`.

### Подготовка shell-скриптов

В Linux shell-скрипты должны иметь право на выполнение. Обычно оно уже хранится в репозитории, но если при запуске появляется ошибка `Отказано в доступе`, выполните:

```bash
chmod +x install_accac.sh scripts/*.sh db/postgresql/run_all.sh tests/jmeter/run_accac_db_limits.sh
```

## Настройка конфигурации

В Git хранится только шаблон:

```text
src/config/accac.example.ini
```

Рекомендуемое рабочее расположение локального конфига:

```text
accac.ini
```

Создайте его на основе примера:

```bash
cp src/config/accac.example.ini accac.ini
```

Приложение ищет `accac.ini` в нескольких местах:

- в корне репозитория;
- рядом с бинарником `build/project1`;
- в `build/config/`;
- в `src/config/`.

Рекомендуемый вариант для ручного запуска и сопровождения — держать локальный файл в корне репозитория.

Ожидаемые параметры подключения:

```ini
[database]
host=localhost
port=5432
database=accac
user=accac_user
password=change_me
```

Параметр `schema` в конфиге сейчас не используется: SQL-запросы приложения обращаются к схеме `sc_accac` напрямую, поэтому права должны быть выданы именно на неё.

## Развёртывание БД

Основной скрипт развёртывания:

```bash
chmod +x db/postgresql/run_all.sh
APP_DB_NAME=accac APP_DB_USER=accac_user POSTGRES_USER=postgres ./db/postgresql/run_all.sh
```

Скрипт:

- проверяет существование роли приложения;
- при наличии `APP_DB_PASSWORD` может создать роль автоматически;
- создаёт базу данных, если она ещё не существует;
- применяет миграции;
- применяет `008_grants.sql` для выдачи прав пользователю приложения.

Порядок миграций:

1. `db/postgresql/migrations/001_schema.sql`
2. `db/postgresql/migrations/002_tables.sql`
3. `db/postgresql/migrations/003_indexes.sql`
4. `db/postgresql/migrations/004_functions.sql`
5. `db/postgresql/migrations/005_procedures.sql`
6. `db/postgresql/migrations/006_triggers.sql`
7. `db/postgresql/migrations/007_seed.sql`
8. `db/postgresql/migrations/008_grants.sql`

Для `007_seed.sql` автоматически используется каталог `db/postgresql/fixtures/hex/`.

## Первый запуск

1. Создайте пользователя БД:

```bash
sudo -u postgres psql -c "CREATE USER accac_user WITH PASSWORD 'change_me';"
```

2. Создайте базу данных, если она ещё не создана:

```bash
sudo -u postgres createdb accac
```

3. Примените миграции и выдайте права:

```bash
APP_DB_NAME=accac APP_DB_USER=accac_user POSTGRES_USER=postgres ./db/postgresql/run_all.sh
```

4. Создайте локальный конфиг:

```bash
cp src/config/accac.example.ini accac.ini
```

5. Отредактируйте `accac.ini` и укажите реальный пароль пользователя БД.

6. Соберите и запустите проект:

```bash
./scripts/build.sh
./scripts/run.sh
```

Если при выполнении `./install_accac.sh` появляется ошибка вида:

```text
ОШИБКА: ошибка синтаксиса около ":"
SELECT 1 FROM pg_roles WHERE rolname = :'APP_DB_USER';
```

это означает, что скрипт использует psql-переменную внутри `psql -c`. После исправления скриптов в этом репозитории такой ошибки быть не должно. Если проблема повторится, обновите рабочее дерево и повторно запустите `./install_accac.sh`.

## Сборка

```bash
./scripts/build.sh
```

Сборка использует Lazarus-проект `src/project1.lpi`, а готовый бинарник размещается в `build/project1`.

## Запуск

Основной вариант, если права на выполнение уже сохранены в Git:

```bash
./scripts/build.sh
./scripts/run.sh
```

Резервный вариант, если система сняла права на выполнение:

```bash
chmod +x install_accac.sh scripts/*.sh db/postgresql/run_all.sh tests/jmeter/run_accac_db_limits.sh
./scripts/run.sh
```

`scripts/run.sh` перед запуском проверяет наличие бинарника и локального `accac.ini`. Если конфиг отсутствует, приложение не будет запущено, а скрипт подскажет команду для его создания.

## Типовая ошибка

Если при запуске приложения появляется ошибка:

```text
PostgreSQL: ОШИБКА: нет доступа к схеме sc_accac
SQL State: 42501
```

это означает, что пользователь из `accac.ini` не имеет прав на схему `sc_accac` и объекты внутри неё.

Для исправления заново примените миграции и выдачу прав:

```bash
APP_DB_NAME=accac APP_DB_USER=accac_user POSTGRES_USER=postgres ./db/postgresql/run_all.sh
```

Либо вручную выполните `GRANT USAGE ON SCHEMA sc_accac` и права на таблицы, последовательности, функции и процедуры.

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
./tests/jmeter/run_accac_db_limits.sh
```

## Документация

- Архитектурное описание: `docs/architecture/architecture.md`
- Исходный markdown-отчёт по тестированию: `docs/testing/testing_report.md`
- Генератор DOCX-отчёта: `docs/build_testing_report.ps1`
- Дополнительный архитектурный документ: `docs/architecture/Архитектура_ACCAC.docx`

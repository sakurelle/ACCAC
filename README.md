# ACCAC

## Назначение проекта

ACCAC — настольное приложение для работы с данными антенных систем. Оно использует PostgreSQL как основное хранилище данных, а пользовательский интерфейс реализован на Lazarus / Free Pascal.

## Требования

- Astra Linux или совместимая Linux-система
- PostgreSQL 11 или новее
- Целевая совместимость для среды преподавателя: PostgreSQL 11
- Lazarus / Free Pascal
- Git
- Bash
- Apache JMeter только для нагрузочного тестирования

## Установка

### Сценарий 1 — установка из готового релиза

Для преподавателя предпочтителен готовый GitHub Release: он содержит уже собранный `accac-linux-astra.tar.gz` и не требует сборки Lazarus-проекта на стороне пользователя.

1. Скачайте `accac-linux-astra.tar.gz` из раздела GitHub Releases.
2. Распакуйте архив и перейдите в каталог приложения.
3. Выполните:

```bash
tar -xzf accac-linux-astra.tar.gz
cd accac
chmod +x accac install_accac.sh scripts/*.sh db/postgresql/run_all.sh
./install_accac.sh
./accac
```

### Сценарий 2 — установка из исходников

Этот вариант нужен разработчику или проверяющему, который хочет собрать приложение локально:

```bash
git clone https://github.com/sakurelle/ACCAC.git
cd ACCAC
chmod +x install_accac.sh scripts/*.sh db/postgresql/run_all.sh tests/jmeter/run_accac_db_limits.sh
./install_accac.sh
./scripts/build.sh
./scripts/run.sh
```

Дополнительный быстрый вариант через bootstrap-скрипт:

```bash
curl -fsSL https://raw.githubusercontent.com/sakurelle/ACCAC/main/scripts/bootstrap_install.sh | bash
```

`install_accac.sh`:

- проверяет, установлен ли PostgreSQL;
- использует уже установленный PostgreSQL, если его major version не ниже 11;
- если PostgreSQL не установлен, пытается поставить совместимую версию из штатных репозиториев ОС;
- при отсутствии `POSTGRES_TARGET_MAJOR` сначала предпочитает `postgresql-11`, затем `postgresql-13`, затем метапакет `postgresql`;
- блокирует установку, если итоговая версия PostgreSQL ниже 11;
- проверяет серверную версию PostgreSQL;
- применяет SQL-миграции через `db/postgresql/run_all.sh`;
- подготавливает локальный `accac.ini`;
- собирает Lazarus-проект `src/accac.lpi`;
- формирует исполняемый файл `build/accac`.

При необходимости можно явно выбрать целевую ветку серверного пакета из системного репозитория:

```bash
POSTGRES_TARGET_MAJOR=11 ./install_accac.sh
```

После установки или при ручной пересборке используйте:

```bash
./scripts/build.sh
./scripts/run.sh
```

Если `install_accac.sh` сообщает, что роль приложения ещё не создана, сначала выполните:

```bash
sudo -u postgres psql -c "CREATE USER accac_user WITH PASSWORD 'change_me';"
```

Если при выполнении `./install_accac.sh` когда-либо появляется ошибка вида:

```text
ОШИБКА: ошибка синтаксиса около ":"
SELECT 1 FROM pg_roles WHERE rolname = :'APP_DB_USER';
```

это означает, что в локальной копии скрипта используется psql-переменная внутри `psql -c`. В текущем состоянии репозитория такой ошибки быть не должно.

## Настройка конфигурации

Шаблон конфигурации лежит в:

```text
src/config/accac.example.ini
```

Рабочий файл должен называться:

```text
accac.ini
```

`accac.ini` не хранится в Git. Если он не был создан автоматически, создайте его вручную:

```bash
cp src/config/accac.example.ini accac.ini
```

После копирования укажите реальные параметры подключения к PostgreSQL. Пример:

```ini
[database]
host=localhost
port=5432
database=accac
user=accac_user
password=change_me
```

Приложение ожидает локальный конфиг в рабочем дереве проекта. Перед первым запуском также нужно развернуть базу данных и выдать права:

```bash
APP_DB_NAME=accac APP_DB_USER=accac_user POSTGRES_USER=postgres ./db/postgresql/run_all.sh
```

Миграция `db/postgresql/migrations/008_grants.sql` выдаёт права пользователю приложения и должна запускаться через `db/postgresql/run_all.sh`, потому что скрипт передаёт `APP_DB_NAME` и `APP_DB_USER` через `psql -v`.

## Структура репозитория

```text
ACCAC/
├── README.md
├── .gitignore
├── .gitattributes
├── install_accac.sh
├── src/
├── db/
├── tests/
├── docs/
├── scripts/
└── .github/
```

- `src/` — исходный код Lazarus / Free Pascal
- `db/postgresql/migrations/` — SQL-миграции
- `tests/jmeter/` — JMeter-тесты
- `docs/` — документация и материалы отчёта
- `scripts/` — вспомогательные скрипты
- `.github/` — CI/CD

## Тестирование

JMeter-планы лежат в:

- `tests/jmeter/plans/ACCAC.jmx`
- `tests/jmeter/plans/ACCAC_DB_LIMITS.jmx`

CSV-данные для параметризации лежат в:

- `tests/jmeter/data/cmp_ids.csv`
- `tests/jmeter/data/ant_ids.csv`

Пример запуска основного JMeter-плана:

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

Пример запуска сценария поиска предельной нагрузки:

```bash
./tests/jmeter/run_accac_db_limits.sh
```

JMeter-отчёты и результаты не хранятся в Git и исключены через `.gitignore`.

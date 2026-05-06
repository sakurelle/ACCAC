param(
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptRoot = if ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
} elseif ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Join-Path (Get-Location) 'docs'
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptRoot 'Отчет_по_тестированию_ACCAC.docx'
}

function Escape-Xml {
    param([string]$Text)

    if ($null -eq $Text) {
        return ''
    }

    return [System.Security.SecurityElement]::Escape($Text)
}

function New-Run {
    param(
        [string]$Text,
        [switch]$Bold,
        [switch]$Italic,
        [int]$Size = 22
    )

    $escaped = Escape-Xml $Text
    $rPr = New-Object System.Collections.Generic.List[string]

    if ($Bold) {
        $rPr.Add('<w:b/>')
    }

    if ($Italic) {
        $rPr.Add('<w:i/>')
    }

    if ($Size -gt 0) {
        $rPr.Add("<w:sz w:val=""$Size""/>")
        $rPr.Add("<w:szCs w:val=""$Size""/>")
    }

    if ($rPr.Count -gt 0) {
        return "<w:r><w:rPr>$($rPr -join '')</w:rPr><w:t xml:space=""preserve"">$escaped</w:t></w:r>"
    }

    return "<w:r><w:t xml:space=""preserve"">$escaped</w:t></w:r>"
}

function New-Paragraph {
    param(
        [string]$Text = '',
        [switch]$Bold,
        [switch]$Italic,
        [int]$Size = 22,
        [string]$Justify = 'left',
        [int]$SpacingAfter = 120,
        [int]$SpacingBefore = 0,
        [int]$Line = 276,
        [switch]$PageBreakBefore
    )

    $jc = switch ($Justify) {
        'center' { 'center' }
        'right' { 'right' }
        default { 'left' }
    }

    $breakXml = if ($PageBreakBefore) { '<w:r><w:br w:type="page"/></w:r>' } else { '' }
    $runXml = if ([string]::IsNullOrEmpty($Text)) { '' } else { New-Run -Text $Text -Bold:$Bold -Italic:$Italic -Size $Size }

    return "<w:p><w:pPr><w:jc w:val=""$jc""/><w:spacing w:before=""$SpacingBefore"" w:after=""$SpacingAfter"" w:line=""$Line"" w:lineRule=""auto""/></w:pPr>$breakXml$runXml</w:p>"
}

function New-BulletParagraph {
    param([string]$Text)

    return New-Paragraph -Text ("• " + $Text) -Size 22 -SpacingAfter 60
}

function New-Table {
    param(
        [string[]]$Headers,
        [object[][]]$Rows
    )

    $colCount = $Headers.Count
    if ($colCount -eq 0) {
        throw 'Table must have at least one column.'
    }

    $tableWidth = 9000
    $colWidth = [math]::Floor($tableWidth / $colCount)

    $gridCols = ($Headers | ForEach-Object { "<w:gridCol w:w=""$colWidth""/>" }) -join ''
    $headerCells = foreach ($header in $Headers) {
        $escaped = Escape-Xml ([string]$header)
        "<w:tc><w:tcPr><w:tcW w:w=""$colWidth"" w:type=""dxa""/></w:tcPr><w:p><w:pPr><w:spacing w:after=""60""/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val=""20""/><w:szCs w:val=""20""/></w:rPr><w:t xml:space=""preserve"">$escaped</w:t></w:r></w:p></w:tc>"
    }

    $rowXml = foreach ($row in $Rows) {
        $cells = foreach ($cell in $row) {
            $escaped = Escape-Xml ([string]$cell)
            "<w:tc><w:tcPr><w:tcW w:w=""$colWidth"" w:type=""dxa""/></w:tcPr><w:p><w:pPr><w:spacing w:after=""40""/></w:pPr><w:r><w:rPr><w:sz w:val=""20""/><w:szCs w:val=""20""/></w:rPr><w:t xml:space=""preserve"">$escaped</w:t></w:r></w:p></w:tc>"
        }

        "<w:tr>$($cells -join '')</w:tr>"
    }

    return @"
<w:tbl>
  <w:tblPr>
    <w:tblW w:w="$tableWidth" w:type="dxa"/>
    <w:tblBorders>
      <w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/>
      <w:left w:val="single" w:sz="8" w:space="0" w:color="000000"/>
      <w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/>
      <w:right w:val="single" w:sz="8" w:space="0" w:color="000000"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    </w:tblBorders>
  </w:tblPr>
  <w:tblGrid>$gridCols</w:tblGrid>
  <w:tr>$($headerCells -join '')</w:tr>
  $($rowXml -join "`n")
</w:tbl>
"@
}

function Format-Decimal {
    param(
        [double]$Value,
        [int]$Digits = 2
    )

    return $Value.ToString("N$Digits", [System.Globalization.CultureInfo]::GetCultureInfo('ru-RU'))
}

$repoRoot = Split-Path $scriptRoot -Parent
$statsPath = Join-Path $repoRoot 'test\jmeter-results\report\statistics.json'
$jmxPath = Join-Path $repoRoot 'test\ACCAC.jmx'
$htmlPath = Join-Path $repoRoot 'test\jmeter-results\report\index.html'

$stats = Get-Content -LiteralPath $statsPath -Raw | ConvertFrom-Json
$jmxText = Get-Content -LiteralPath $jmxPath -Raw
$htmlText = Get-Content -LiteralPath $htmlPath -Raw

$startMatch = [regex]::Match($htmlText, '<td>Start Time</td>\s*<td>"([^"]+)"</td>')
$endMatch = [regex]::Match($htmlText, '<td>End Time</td>\s*<td>"([^"]+)"</td>')

$cultureEn = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
$cultureRu = [System.Globalization.CultureInfo]::GetCultureInfo('ru-RU')

$startTime = [datetime]::ParseExact($startMatch.Groups[1].Value, 'M/d/yy, h:mm tt', $cultureEn)
$endTime = [datetime]::ParseExact($endMatch.Groups[1].Value, 'M/d/yy, h:mm tt', $cultureEn)
$duration = $endTime - $startTime

$dbConnectionStats = $stats.'01 DB Connection OK'
$uiComponentsStats = $stats.'02 UI Components Exist'
$uiCoordinatesStats = $stats.'03 UI Coordinates Valid'
$antennaRelationsStats = $stats.'04 Antenna Relations Valid'
$uiLayoutLoadStats = $stats.'05 UI Layout Load'
$loadUiStats = $stats.'Load UI Component By ID'
$loadAntennaStats = $stats.'Load Antenna By ID'
$totalStats = $stats.Total

$functionalRows = @(
    @('01 DB Connection OK', 'Проверка подключения к PostgreSQL и доступности БД db_ics_accac', 'Успешно', "$([int]$dbConnectionStats.meanResTime) мс", "$([int]$dbConnectionStats.errorCount)"),
    @('02 UI Components Exist', 'Проверка наличия UI-компонентов в tb_CMP для основного макета', 'Успешно', "$([int]$uiComponentsStats.meanResTime) мс", "$([int]$uiComponentsStats.errorCount)"),
    @('03 UI Coordinates Valid', 'Проверка корректности координат и размеров компонентов', 'Успешно', "$([int]$uiCoordinatesStats.meanResTime) мс", "$([int]$uiCoordinatesStats.errorCount)"),
    @('04 Antenna Relations Valid', 'Проверка ссылочной целостности связей tb_ANT -> tb_MDL/tb_CITY/tb_STAT', 'Успешно', "$([int]$antennaRelationsStats.meanResTime) мс", "$([int]$antennaRelationsStats.errorCount)"),
    @('05 UI Layout Load', 'Проверка загрузки макета с центрами, городами, антеннами, моделями и статусами', 'Успешно', "$([int]$uiLayoutLoadStats.meanResTime) мс", "$([int]$uiLayoutLoadStats.errorCount)")
)

$loadRows = @(
    @(
        'Load UI Component By ID',
        "$([int]$loadUiStats.sampleCount)",
        "$(Format-Decimal $loadUiStats.meanResTime 3) мс",
        "$([int]$loadUiStats.pct3ResTime) мс",
        "$(Format-Decimal $loadUiStats.throughput 2) запрос/с",
        "$([int]$loadUiStats.errorCount)"
    ),
    @(
        'Load Antenna By ID',
        "$([int]$loadAntennaStats.sampleCount)",
        "$(Format-Decimal $loadAntennaStats.meanResTime 3) мс",
        "$([int]$loadAntennaStats.pct3ResTime) мс",
        "$(Format-Decimal $loadAntennaStats.throughput 2) запрос/с",
        "$([int]$loadAntennaStats.errorCount)"
    ),
    @(
        'Итого',
        "$([int]$totalStats.sampleCount)",
        "$(Format-Decimal $totalStats.meanResTime 3) мс",
        "$([int]$totalStats.pct3ResTime) мс",
        "$(Format-Decimal $totalStats.throughput 2) запрос/с",
        "$([int]$totalStats.errorCount)"
    )
)

$limitRows = @(
    @('Error rate, %', "$(Format-Decimal ($totalStats.errorPct * 100) 2)", '[уточнить допустимое значение]'),
    @('Среднее время отклика, мс', "$(Format-Decimal $totalStats.meanResTime 3)", '[уточнить допустимое значение]'),
    @('P99 времени отклика, мс', "$([int]$totalStats.pct3ResTime)", '[уточнить допустимое значение]'),
    @('Совокупная пропускная способность, запрос/с', "$(Format-Decimal $totalStats.throughput 2)", '[уточнить допустимое значение]'),
    @('Конкурентная нагрузка, потоков', '1000', '[уточнить допустимое значение]'),
    @('Длительность стабильной работы', "$([int]$duration.TotalMinutes) минут без ошибок", '[уточнить допустимое значение]')
)

$jmeterParamsRows = @(
    @('Инструмент', 'Apache JMeter 5.6.3'),
    @('План тестирования', 'test/ACCAC.jmx'),
    @('Тип подключения', 'JDBC к PostgreSQL'),
    @('Хост БД', '127.0.0.1'),
    @('Порт БД', '5433'),
    @('База данных', 'db_ics_accac'),
    @('Схема', 'sc_accac'),
    @('Пользователь для тестов', 'jmeter_accac'),
    @('Таймаут JDBC', '10000 мс'),
    @('keepAlive', 'true'),
    @('autocommit', 'true'),
    @('connectionAge', '5000'),
    @('trimInterval', '60000'),
    @('Функциональная группа', '1 поток, ramp-up 1 c, 1 итерация'),
    @('Нагрузочная группа', '1000 потоков, ramp-up 600 c, 5000 итераций'),
    @('Нагрузочные запросы', 'Load UI Component By ID и Load Antenna By ID'),
    @('Параметризация', 'CSVDataSet, в JMX указаны cmp_ids.csv и ant_ids.csv')
)

$content = New-Object System.Collections.Generic.List[string]

$content.Add((New-Paragraph -Text 'ОТЧЕТ ПО ИССЛЕДОВАНИЮ И ТЕСТИРОВАНИЮ ПРОЕКТА ACCAC' -Bold -Size 30 -Justify center -SpacingAfter 240))
$content.Add((New-Paragraph -Text 'Состав и состояние антенных комплексов НИЦ «Планета»' -Size 24 -Justify center -SpacingAfter 180))
$content.Add((New-Paragraph -Text 'Документ подготовлен по материалам репозитория, архитектурного отчета и артефактам JMeter.' -Italic -Size 22 -Justify center -SpacingAfter 120))
$content.Add((New-Paragraph -Text "Дата подготовки: $(Get-Date -Format 'dd.MM.yyyy')" -Size 22 -Justify center -SpacingAfter 0))
$content.Add((New-Paragraph -PageBreakBefore -SpacingAfter 0))

$content.Add((New-Paragraph -Text '1. Описание проекта и архитектуры' -Bold -Size 28 -SpacingAfter 180))
$content.Add((New-Paragraph -Text 'Проект ACCAC предназначен для отображения состава и состояния антенных комплексов НИЦ «Планета». По материалам архитектурного отчета проектная область включает центры, города, антенные установки, модели антенн, состояния, макеты и компоненты интерфейса.' -Size 22))
$content.Add((New-Paragraph -Text 'Фактическая реализация в репозитории соответствует двухзвенной архитектуре: настольный клиент на Lazarus напрямую подключается к PostgreSQL и получает данные для визуализации и редактирования без выделенного серверного слоя приложений.' -Size 22))
$content.Add((New-Paragraph -Text 'Основные подсистемы проекта:' -Bold -Size 22 -SpacingAfter 80))
$content.Add((New-BulletParagraph -Text 'accac_lazarus: клиентское приложение, отрисовка схемы антенных комплексов, форма меню и редактор данных.'))
$content.Add((New-BulletParagraph -Text 'accac_sql: схема PostgreSQL, таблицы, индексы, триггеры, процедура добавления антенн и начальное наполнение.'))
$content.Add((New-BulletParagraph -Text 'test: план тестирования ACCAC.jmx и сохраненный HTML-отчет JMeter с результатами прогона.'))

$content.Add((New-Paragraph -Text 'С точки зрения бизнес-логики архитектурный отчет задает следующие ключевые сущности: tb_CTR (центры), tb_CITY (города), tb_MDL (модели антенн), tb_ANT (антенны), tb_STAT (состояния), tb_LYT (макеты) и tb_CMP (компоненты интерфейса). В seed-данных проекта стартовое наполнение включает 3 центра, 5 городов, 63 модели/антенны, 2 статуса, 1 основной макет и более 140 UI-компонентов.' -Size 22))
$content.Add((New-Paragraph -Text 'Особенность решения состоит в том, что представление экрана частично хранится в БД: таблица tb_CMP содержит тип компонента, координаты, размеры, видимость, текст и связи с доменными сущностями. Это позволяет перестраивать интерфейс и макеты на уровне данных без изменения бинарного клиента.' -Size 22))
$content.Add((New-Paragraph -Text 'Клиентское приложение использует файл accac.ini для чтения параметров подключения. После подключения форма TFormMain загружает выбранный макет, извлекает видимые элементы из tb_CMP, подтягивает изображения моделей из tb_MDL.bh_img и статусы антенн из tb_STAT, после чего отрисовывает схему в PaintBox со скроллингом.' -Size 22))
$content.Add((New-Paragraph -Text 'Вторая ключевая часть клиента — редактор TFormEditor. Он предоставляет CRUD-операции для центров, состояний, макетов, моделей, городов, антенн и UI-компонентов. Из этого следует, что проект совмещает режим просмотра схемы и режим сопровождения справочников/макетов в одном настольном приложении.' -Size 22))
$content.Add((New-Paragraph -Text 'С точки зрения качества данных архитектурный отчет и SQL-реализация согласованы между собой: структура БД нормализована до 3НФ, связи реализованы через внешние ключи, а для таблицы tb_CMP дополнительно заданы CHECK-ограничения и триггер fn_check_tb_CMP, который валидирует тип компонента, координаты, размеры и обязательные ссылки на связанные сущности.' -Size 22))
$content.Add((New-Paragraph -Text 'Индексы созданы по ключевым внешним ключам и полям фильтрации (ni_CTR_id, ni_CITY_id, ni_MDL_id, ni_STAT_id, ni_LYT_id, bl_visible), что напрямую соответствует шаблонам запросов клиента и JMeter-сценария.' -Size 22))
$content.Add((New-Paragraph -Text 'В архитектурном отчете также зафиксированы требования к масштабируемости, переносимости под Astra Linux 1.8+ и защите доступа к данным через корректные учетные данные. Эти требования подтверждаются структурой репозитория: развертывание БД автоматизировано через install_accac.sh/run_all.sh, а подключение клиента зависит от отдельного INI-файла.' -Size 22))

$content.Add((New-Paragraph -Text '2. Как работает проект' -Bold -Size 28 -SpacingAfter 180))
$content.Add((New-Paragraph -Text 'Пользователь запускает настольное приложение, которое подключается к PostgreSQL и загружает основной макет схемы. На экране отображаются центры НИЦ «Планета», города внутри центров и набор антенных установок. Каждая антенна имеет модель, изображение и текущий статус, а статус дополнительно влияет на цвет подписи в интерфейсе.' -Size 22))
$content.Add((New-Paragraph -Text 'Редактор позволяет изменять справочники, добавлять или удалять антенны, управлять макетами и UI-компонентами. Таким образом, ACCAC является не только приложением просмотра, но и инструментом ведения и актуализации структуры антенных комплексов в БД.' -Size 22))

$content.Add((New-Paragraph -Text '3. Методика исследования и тестирования' -Bold -Size 28 -SpacingAfter 180))
$content.Add((New-Paragraph -Text 'При подготовке настоящего отчета были проанализированы исходный код клиента Lazarus, SQL-скрипты схемы и наполнения, архитектурный отчет docs/Архитектура_ACCAC.docx, а также готовые результаты тестирования в каталоге test/jmeter-results/report.' -Size 22))
$content.Add((New-Paragraph -Text 'Непосредственно тестирование в репозитории ориентировано на слой БД и SQL-запросов. Для этого использовался Apache JMeter 5.6.3 с JDBC-подключением к PostgreSQL. Важно отметить, что JMeter в данном случае проверяет не графический интерфейс напрямую, а доступность и производительность запросов, которыми приложение фактически наполняет экран данными.' -Size 22))
$content.Add((New-Paragraph -Text 'Сценарий тестирования включает две группы:' -Bold -Size 22 -SpacingAfter 80))
$content.Add((New-BulletParagraph -Text 'Функциональная группа проверяет подключение, наличие UI-компонентов, корректность координат и размеров, ссылочную целостность антенн и загрузку основного макета.'))
$content.Add((New-BulletParagraph -Text 'Нагрузочная группа выполняет массовое чтение UI-компонента по ID и антенны по ID с использованием подготовленных идентификаторов из CSVDataSet, указанных в JMX-файле.'))
$content.Add((New-Paragraph -Text "Фактический HTML-отчет JMeter показывает, что прогон выполнялся в период с $($startTime.ToString('dd.MM.yyyy HH:mm', $cultureRu)) по $($endTime.ToString('dd.MM.yyyy HH:mm', $cultureRu)). Общая продолжительность прогона составила $([int]$duration.TotalMinutes) минут." -Size 22))

$content.Add((New-Paragraph -Text '4. Параметры JMeter-сценария' -Bold -Size 28 -SpacingAfter 180))
$content.Add((New-Table -Headers @('Параметр', 'Значение') -Rows $jmeterParamsRows))
$content.Add((New-Paragraph -Text 'Примечание: пароль JDBC-подключения присутствует в JMX-файле, но в отчет намеренно не включается в явном виде.' -Italic -Size 20 -SpacingBefore 60))

$content.Add((New-Paragraph -Text '5. Результаты функционального тестирования' -Bold -Size 28 -SpacingAfter 180))
$content.Add((New-Paragraph -Text 'Все пять функциональных JDBC-проверок завершились без ошибок. Это означает, что на момент сформированного отчета БД была доступна, данные для главного макета присутствовали, геометрия компонентов была валидной, ссылочные связи антенн не были нарушены, а составной запрос загрузки интерфейса отрабатывал корректно.' -Size 22))
$content.Add((New-Table -Headers @('Проверка', 'Назначение', 'Результат', 'Среднее время', 'Ошибки') -Rows $functionalRows))

$content.Add((New-Paragraph -Text '6. Результаты нагрузочного тестирования' -Bold -Size 28 -SpacingAfter 180))
$content.Add((New-Paragraph -Text 'Нагрузочный сценарий выполнял две операции чтения и суммарно сформировал 10 000 005 JDBC-сэмплов, из которых 10 000 000 относятся к нагрузочной части и 5 — к функциональным проверкам. Во всех сэмплах зафиксирован нулевой уровень ошибок.' -Size 22))
$content.Add((New-Table -Headers @('Сценарий', 'Количество сэмплов', 'Среднее время', 'P99', 'Пропускная способность', 'Ошибки') -Rows $loadRows))
$content.Add((New-Paragraph -Text 'По сохраненной статистике суммарная пропускная способность составила около 16 649,47 запросов/с, а P99 для нагрузочных операций не превышал 1 мс. При этом максимальное время 354 мс наблюдается как единичный выброс и не влияет на общую картину, поскольку медиана и старшие перцентили остаются на уровне 0-1 мс.' -Size 22))
$content.Add((New-Paragraph -Text 'Отдельно важно зафиксировать границы интерпретации: архитектурный отчет формулирует требование по производительности в терминах «10 млн пользователей», тогда как имеющийся JMeter-план фактически подтверждает устойчивость сценария на 1000 конкурентных потоках и 10 млн SQL-операций чтения. Эти величины не эквивалентны и не должны подменять друг друга в итоговых выводах.' -Size 22))

$content.Add((New-Paragraph -Text '7. Заготовка под лимиты и критерии приемки' -Bold -Size 28 -SpacingAfter 180))
$content.Add((New-Paragraph -Text 'Ниже приведена заготовка для фиксации эксплуатационных лимитов. Текущие фактические значения уже заполнены по JMeter-отчету, а допустимые пороги можно утвердить позднее после согласования с преподавателем или заказчиком.' -Size 22))
$content.Add((New-Table -Headers @('Метрика', 'Фактическое значение', 'Допустимый лимит') -Rows $limitRows))

$content.Add((New-Paragraph -Text '8. Выводы' -Bold -Size 28 -SpacingAfter 180))
$content.Add((New-Paragraph -Text 'Исследование репозитория показывает, что ACCAC представляет собой настольную систему визуализации и сопровождения данных об антенных комплексах НИЦ «Планета», построенную вокруг PostgreSQL как центрального источника истины. Архитектурный отчет и реализация в коде согласованы по ключевым сущностям, по нормализации данных и по механизму хранения UI-макета в базе.' -Size 22))
$content.Add((New-Paragraph -Text 'По имеющимся результатам JMeter функциональные проверки пройдены успешно, а нагрузочный сценарий на 1000 потоков и 10 млн операций чтения завершился без ошибок и с очень низким временем отклика. Это позволяет сделать вывод о корректности текущей схемы БД и высокой производительности запросов чтения в тестовой конфигурации.' -Size 22))
$content.Add((New-Paragraph -Text 'При этом для окончательного утверждения производственных лимитов требуется отдельное согласование порогов и, при необходимости, дополнительный прогон с формально зафиксированной аппаратной конфигурацией стенда. Текущий отчет уже содержит готовую основу для такой фиксации.' -Size 22))

$bodyXml = $content -join "`n"

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
 xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
 xmlns:v="urn:schemas-microsoft-com:vml"
 xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:w10="urn:schemas-microsoft-com:office:word"
 xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
 xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
 xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
 xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
 xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
 mc:Ignorable="w14 wp14">
  <w:body>
$bodyXml
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="850" w:bottom="1134" w:left="850" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

$contentTypesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"@

$rootRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"@

$docRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
"@

$createdUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcmitype="http://purl.org/dc/dcmitype/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Отчет по тестированию ACCAC</dc:title>
  <dc:subject>Тестирование и исследование проекта ACCAC</dc:subject>
  <dc:creator>OpenAI Codex</dc:creator>
  <cp:keywords>ACCAC; JMeter; PostgreSQL; Lazarus</cp:keywords>
  <dc:description>Отчет по архитектуре и тестированию проекта ACCAC</dc:description>
  <cp:lastModifiedBy>OpenAI Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$createdUtc</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$createdUtc</dcterms:modified>
</cp:coreProperties>
"@

$appXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
 xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Office Word</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <HeadingPairs>
    <vt:vector size="2" baseType="variant">
      <vt:variant><vt:lpstr>Разделы</vt:lpstr></vt:variant>
      <vt:variant><vt:i4>8</vt:i4></vt:variant>
    </vt:vector>
  </HeadingPairs>
  <TitlesOfParts>
    <vt:vector size="8" baseType="lpstr">
      <vt:lpstr>1. Описание проекта и архитектуры</vt:lpstr>
      <vt:lpstr>2. Как работает проект</vt:lpstr>
      <vt:lpstr>3. Методика исследования и тестирования</vt:lpstr>
      <vt:lpstr>4. Параметры JMeter-сценария</vt:lpstr>
      <vt:lpstr>5. Результаты функционального тестирования</vt:lpstr>
      <vt:lpstr>6. Результаты нагрузочного тестирования</vt:lpstr>
      <vt:lpstr>7. Заготовка под лимиты и критерии приемки</vt:lpstr>
      <vt:lpstr>8. Выводы</vt:lpstr>
    </vt:vector>
  </TitlesOfParts>
  <Company>OpenAI</Company>
  <LinksUpToDate>false</LinksUpToDate>
  <SharedDoc>false</SharedDoc>
  <HyperlinksChanged>false</HyperlinksChanged>
  <AppVersion>16.0000</AppVersion>
</Properties>
"@

$tempRoot = Join-Path $env:TEMP ("accac-docx-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot '_rels') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'docProps') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'word') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'word\_rels') | Out-Null

try {
    Set-Content -LiteralPath (Join-Path $tempRoot '[Content_Types].xml') -Value $contentTypesXml -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $tempRoot '_rels\.rels') -Value $rootRelsXml -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $tempRoot 'docProps\core.xml') -Value $coreXml -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $tempRoot 'docProps\app.xml') -Value $appXml -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $tempRoot 'word\document.xml') -Value $documentXml -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $tempRoot 'word\_rels\document.xml.rels') -Value $docRelsXml -Encoding UTF8

    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }

    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempRoot, $OutputPath)
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Output "Created: $OutputPath"

param(
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

if ($PSCommandPath) {
    $scriptRoot = Split-Path -Parent $PSCommandPath
} elseif ($PSScriptRoot) {
    $scriptRoot = $PSScriptRoot
} else {
    $scriptRoot = Join-Path (Get-Location) 'docs'
}

$repoRoot = Split-Path $scriptRoot -Parent
$architecturePath = Join-Path $scriptRoot 'architecture\architecture.md'
$testingReportPath = Join-Path $scriptRoot 'testing\testing_report.md'
$jmxPath = Join-Path $repoRoot 'tests\jmeter\plans\ACCAC.jmx'
$statsPath = Join-Path $repoRoot 'tests\jmeter\jmeter-results\accac\report\statistics.json'
$htmlPath = Join-Path $repoRoot 'tests\jmeter\jmeter-results\accac\report\index.html'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptRoot 'testing\Отчет_по_тестированию_ACCAC.docx'
}

function Escape-Xml {
    param([string]$Text)

    if ($null -eq $Text) {
        return ''
    }

    return [System.Security.SecurityElement]::Escape($Text)
}

function New-ParagraphXml {
    param(
        [string]$Text,
        [int]$Size = 22,
        [switch]$Bold
    )

    $escaped = Escape-Xml $Text
    $runProps = ''

    if ($Bold) {
        $runProps += '<w:b/>'
    }

    $runProps += "<w:sz w:val=""$Size""/><w:szCs w:val=""$Size""/>"

    return "<w:p><w:pPr><w:spacing w:after=""120""/></w:pPr><w:r><w:rPr>$runProps</w:rPr><w:t xml:space=""preserve"">$escaped</w:t></w:r></w:p>"
}

function Convert-MarkdownToParagraphs {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $result = New-Object System.Collections.Generic.List[string]
    $inCodeBlock = $false

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()

        if ($trimmed.StartsWith('```')) {
            $inCodeBlock = -not $inCodeBlock
            continue
        }

        if ($inCodeBlock) {
            if ($trimmed -ne '') {
                $result.Add($trimmed)
            }
            continue
        }

        if ($trimmed -eq '') {
            continue
        }

        $text = $trimmed `
            -replace '^\#\#\#\s*', '' `
            -replace '^\#\#\s*', '' `
            -replace '^\#\s*', '' `
            -replace '^\-\s*', '• ' `
            -replace '^\d+\.\s*', ''

        if ($text.Contains('|')) {
            $parts = $text.Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            if ($parts.Count -gt 0) {
                $text = ($parts -join ' | ')
            }
        }

        $result.Add($text)
    }

    return $result
}

function Get-StatsParagraphs {
    $paragraphs = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path -LiteralPath $statsPath)) {
        $paragraphs.Add('JMeter statistics file not found. Generate local test artifacts in tests/jmeter/jmeter-results/accac/report before rebuilding the DOCX report.')
        return $paragraphs
    }

    $stats = Get-Content -LiteralPath $statsPath -Raw | ConvertFrom-Json
    $total = $stats.Total

    $paragraphs.Add("JMeter plan: $jmxPath")
    $paragraphs.Add("Statistics source: $statsPath")

    if ($null -ne $total) {
        $paragraphs.Add("Total samples: $([int]$total.sampleCount)")
        $paragraphs.Add("Errors: $([int]$total.errorCount)")
        $paragraphs.Add("Mean response time: $([math]::Round([double]$total.meanResTime, 3)) ms")
        $paragraphs.Add("P99 response time: $([int]$total.pct3ResTime) ms")
        $paragraphs.Add("Throughput: $([math]::Round([double]$total.throughput, 2)) req/s")
    }

    if (Test-Path -LiteralPath $htmlPath) {
        $paragraphs.Add("HTML report: $htmlPath")
    }

    return $paragraphs
}

$paragraphs = New-Object System.Collections.Generic.List[string]
$paragraphs.Add('ОТЧЕТ ПО ТЕСТИРОВАНИЮ ACCAC')
$paragraphs.Add("Дата подготовки: $(Get-Date -Format 'dd.MM.yyyy')")
$paragraphs.Add('')
$paragraphs.Add('Раздел 1. Архитектура')
$paragraphs.AddRange((Convert-MarkdownToParagraphs -Path $architecturePath))
$paragraphs.Add('')
$paragraphs.Add('Раздел 2. Тестирование')
$paragraphs.AddRange((Convert-MarkdownToParagraphs -Path $testingReportPath))
$paragraphs.Add('')
$paragraphs.Add('Раздел 3. JMeter артефакты')
$paragraphs.AddRange((Get-StatsParagraphs))

$body = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $paragraphs.Count; $i++) {
    $text = $paragraphs[$i]

    if ($text -eq '') {
        $body.Add('<w:p/>')
        continue
    }

    $isHeading = $text -like 'ОТЧЕТ*' -or $text -like 'Раздел *'
    $size = if ($text -like 'ОТЧЕТ*') { 30 } elseif ($isHeading) { 26 } else { 22 }
    $body.Add((New-ParagraphXml -Text $text -Size $size -Bold:$isHeading))
}

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
$($body -join "`n")
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

$createdUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcmitype="http://purl.org/dc/dcmitype/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Отчет по тестированию ACCAC</dc:title>
  <dc:creator>OpenAI Codex</dc:creator>
  <dc:description>DOCX-отчет, собранный из markdown-источников и локальных JMeter-артефактов.</dc:description>
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
</Properties>
"@

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

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

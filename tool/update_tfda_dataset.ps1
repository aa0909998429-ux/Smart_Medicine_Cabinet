param(
    [string]$InputCsv,
    [string]$OutputPath = "assets/data/tfda_common_drugs.json",
    [datetime]$SnapshotDate = (Get-Date)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sourceUrl = "https://data.fda.gov.tw/data/opendata/export/36/csv"
$datasetPage = "https://data.gov.tw/dataset/9122"
$licenseName = "政府資料開放授權條款－第1版"
$licenseUrl = "https://data.gov.tw/license"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not $InputCsv) {
    $workDir = Join-Path (
        [System.IO.Path]::GetTempPath()
    ) "smart-med-cabinet-tfda-$([guid]::NewGuid())"
    $zipPath = Join-Path $workDir "tfda-drugs.zip"
    $expandedPath = Join-Path $workDir "expanded"
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null
    Invoke-WebRequest -Uri $sourceUrl -OutFile $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $expandedPath
    $InputCsv = (Get-ChildItem -LiteralPath $expandedPath -Filter "*.csv" |
        Select-Object -First 1).FullName
}

if (-not [System.IO.Path]::IsPathRooted($InputCsv)) {
    $InputCsv = Join-Path $projectRoot $InputCsv
}
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $projectRoot $OutputPath
}

$allowedCategories = @(
    "成藥",
    "乙類成藥",
    "醫師藥師藥劑生指示藥品"
)
$snapshotDay = $SnapshotDate.Date
$filtered = [System.Collections.Generic.List[object]]::new()

foreach ($row in (Import-Csv -LiteralPath $InputCsv)) {
    if (-not [string]::IsNullOrWhiteSpace($row."註銷狀態")) { continue }
    if ($allowedCategories -notcontains $row."藥品類別") { continue }
    if ([string]::IsNullOrWhiteSpace($row."有效日期")) { continue }

    try {
        $licenseExpiry = [datetime]::ParseExact(
            $row."有效日期",
            "yyyy/MM/dd",
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }
    catch {
        continue
    }
    if ($licenseExpiry -lt $snapshotDay) { continue }
    $filtered.Add($row)
}

$medicines = foreach ($group in ($filtered | Group-Object "許可證字號" | Sort-Object Name)) {
    $row = $group.Group | Select-Object -First 1
    $aliases = [System.Collections.Generic.List[string]]::new()
    if ($row."中文品名" -match "百保能" -or $row."英文品名" -match "PABRON") {
        foreach ($alias in @("大正百保能", "百保能", "パブロン", "Pabron")) {
            $aliases.Add($alias)
        }
    }

    [ordered]@{
        permit_number       = $row."許可證字號".Trim()
        chinese_name        = $row."中文品名".Trim()
        english_name        = $row."英文品名".Trim()
        indications         = $row."適應症".Trim()
        dosage              = $row."用法用量".Trim()
        ingredients         = $row."主成分略述".Trim()
        category            = $row."藥品類別".Trim()
        dosage_form         = $row."劑型".Trim()
        packaging           = (($group.Group."包裝" | Where-Object { $_ } | Sort-Object -Unique) -join "；")
        license_expiry_date = $row."有效日期".Trim()
        applicant_name      = $row."申請商名稱".Trim()
        barcodes            = (($group.Group."包裝與國際條碼" | Where-Object { $_ } | Sort-Object -Unique) -join "；")
        aliases             = @($aliases)
    }
}

$payload = [ordered]@{
    metadata = [ordered]@{
        title               = "衛生福利部食品藥物管理署－全部藥品許可證資料集（有效非處方／指示藥子集）"
        source_url          = $sourceUrl
        dataset_page        = $datasetPage
        license             = $licenseName
        license_url         = $licenseUrl
        snapshot_date       = $snapshotDay.ToString("yyyy-MM-dd")
        selection_rule      = "未註銷、許可證有效日期不早於快照日，且藥品類別為成藥、乙類成藥或醫師藥師藥劑生指示藥品"
        medicine_count      = $medicines.Count
        medical_disclaimer  = "請勿自行決定用藥；使用前請核對實體包裝並諮詢醫師或藥師。"
    }
    medicines = @($medicines)
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8NoBOM

Write-Output "Generated $($medicines.Count) medicines at $OutputPath"

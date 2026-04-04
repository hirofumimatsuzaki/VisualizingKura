$downloadDir = "C:\Users\Mining-Base\Downloads"
$sourceFile = Get-ChildItem $downloadDir -Filter "*.csv" |
  Where-Object { $_.Length -gt 30000 } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

$sourcePath = $sourceFile.FullName
$outputPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artists-data.js"

if (-not $sourceFile) {
  throw "CSV not found in $downloadDir"
}

$lines = Get-Content $sourcePath
$records = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[string]

function Normalize-Country {
  param([string]$Country)

  if ([string]::IsNullOrWhiteSpace($Country)) {
    return "Unknown"
  }

  $normalized = $Country.Trim()
  $normalized = $normalized -replace ", The 3dsense-Kura Artistic Residency Award", ""
  if ($normalized -eq "Great Britain") { return "United Kingdom" }
  return $normalized
}

foreach ($line in $lines) {
  if ([string]::IsNullOrWhiteSpace($line)) {
    continue
  }

  $trimmed = $line.Trim().Trim('"')
  if ($trimmed -match '^\d{4}$') {
    continue
  }

  if ($trimmed -notmatch '^(\d{4})/(\d{2}):\s*(.+)$') {
    $warnings.Add("Skipped malformed line: $trimmed")
    continue
  }

  $year = [int]$matches[1]
  $month = [int]$matches[2]
  $body = $matches[3].Trim()

  if ($body -match '^\d+$') {
    $warnings.Add("Skipped counter-like line: $trimmed")
    continue
  }

  $lastOpen = $body.LastIndexOf('(')
  $lastClose = $body.LastIndexOf(')')

  $name = $body
  $country = "Unknown"

  if ($lastOpen -gt 0 -and $lastClose -gt $lastOpen) {
    $name = $body.Substring(0, $lastOpen).Trim()
    $country = Normalize-Country($body.Substring($lastOpen + 1, $lastClose - $lastOpen - 1))
  } else {
    $warnings.Add("Missing country: $trimmed")
  }

  if ([string]::IsNullOrWhiteSpace($name)) {
    $warnings.Add("Skipped empty-name line: $trimmed")
    continue
  }

  $isoDate = "{0:D4}-{1:D2}-01" -f $year, $month

  $records.Add([pscustomobject]@{
    year = $year
    month = $month
    date = $isoDate
    label = ("{0:D4}/{1:D2}" -f $year, $month)
    artist = $name
    country = $country
  })
}

$sorted = $records | Sort-Object @{ Expression = "date"; Ascending = $true }, @{ Expression = "artist"; Ascending = $true }

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  totalArtists = $sorted.Count
  warnings = $warnings
  records = $sorted
}

$json = $payload | ConvertTo-Json -Depth 6
$js = "window.ARTIST_DATA = $json;"

$outDir = Split-Path $outputPath -Parent
if (-not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

[System.IO.File]::WriteAllText($outputPath, $js, [System.Text.UTF8Encoding]::new($false))
Write-Output "Wrote $($sorted.Count) records to $outputPath"

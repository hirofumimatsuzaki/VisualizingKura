param(
  [string]$DownloadDir = "C:\Users\Mining-Base\Downloads",
  [string]$ManualAdditionsPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\manual-artists.csv",
  [string]$CountryOverridesPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\country-overrides.csv",
  [string]$OutputPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artists-data.js"
)

$sourceFile = Get-ChildItem $DownloadDir -Filter "*.csv" |
  Where-Object { $_.Length -gt 30000 } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $sourceFile) {
  throw "CSV not found in $DownloadDir"
}

$sourcePath = $sourceFile.FullName
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-Utf8Lines {
  param([string]$Path)

  $content = $utf8NoBom.GetString([System.IO.File]::ReadAllBytes($Path))
  $content -split "`r?`n"
}

function Normalize-ArtistKey {
  param([string]$Artist)

  if ([string]::IsNullOrWhiteSpace($Artist)) {
    return ""
  }

  $formD = $Artist.Trim().Normalize([Text.NormalizationForm]::FormD)
  $builder = New-Object System.Text.StringBuilder

  foreach ($char in $formD.ToCharArray()) {
    $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
    if ($category -eq [Globalization.UnicodeCategory]::NonSpacingMark) {
      continue
    }

    if ([char]::IsLetterOrDigit($char)) {
      [void]$builder.Append([char]::ToLowerInvariant($char))
    }
  }

  $builder.ToString()
}

function Normalize-Country {
  param([string]$Country)

  if ([string]::IsNullOrWhiteSpace($Country)) {
    return "Unknown"
  }

  $normalized = $Country.Trim()
  $normalized = $normalized -replace ", The 3dsense-Kura Artistic Residency Award", ""
  if ($normalized -eq "Great Britain") { return "United Kingdom" }
  if ($normalized -eq "Scotland") { return "United Kingdom" }
  $normalized
}

function Build-RecordKey {
  param(
    [string]$Label,
    [string]$Artist
  )

  "$Label|$(Normalize-ArtistKey $Artist)"
}

function New-ArtistRecord {
  param(
    [int]$Year,
    [int]$Month,
    [string]$Artist,
    [string]$Country,
    [string]$DetailUrl = ""
  )

  $isoDate = "{0:D4}-{1:D2}-01" -f $Year, $Month
  [pscustomobject]@{
    year = $Year
    month = $Month
    date = $isoDate
    label = ("{0:D4}/{1:D2}" -f $Year, $Month)
    artist = $Artist.Trim()
    country = Normalize-Country $Country
    detailUrl = $DetailUrl.Trim()
  }
}

function Load-CountryOverrides {
  param([string]$Path)

  $overrides = @{}
  if (-not (Test-Path $Path)) {
    return $overrides
  }

  $lines = Read-Utf8Lines $Path
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }

    $trimmed = $line.Trim()
    if ($trimmed -match '^(label,artist,country|artist,country)$') {
      continue
    }

    $parts = $trimmed.Split(',', 3)
    if ($parts.Count -eq 2) {
      $artist = $parts[0].Trim()
      $country = Normalize-Country $parts[1]
      if ([string]::IsNullOrWhiteSpace($artist) -or [string]::IsNullOrWhiteSpace($country)) {
        continue
      }

      $overrides["*|$(Normalize-ArtistKey $artist)"] = $country
      continue
    }

    if ($parts.Count -eq 3) {
      $label = $parts[0].Trim()
      $artist = $parts[1].Trim()
      $country = Normalize-Country $parts[2]
      if ([string]::IsNullOrWhiteSpace($label) -or [string]::IsNullOrWhiteSpace($artist) -or [string]::IsNullOrWhiteSpace($country)) {
        continue
      }

      $overrides[(Build-RecordKey $label $artist)] = $country
    }
  }

  $overrides
}

function Load-ManualAdditions {
  param([string]$Path)

  $records = New-Object System.Collections.Generic.List[object]
  if (-not (Test-Path $Path)) {
    return $records
  }

  $lines = Read-Utf8Lines $Path
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }

    $trimmed = $line.Trim()
    if ($trimmed -eq "label,artist,country" -or $trimmed -eq "label,artist,country,detailUrl") {
      continue
    }

    $parts = $trimmed.Split(',', 4)
    if ($parts.Count -lt 3) {
      continue
    }

    $label = $parts[0].Trim()
    $artist = $parts[1].Trim()
    $country = $parts[2].Trim()
    $detailUrl = if ($parts.Count -ge 4) { $parts[3].Trim() } else { "" }
    if ($label -notmatch '^(\d{4})/(\d{2})$' -or [string]::IsNullOrWhiteSpace($artist)) {
      continue
    }

    $records.Add((New-ArtistRecord -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Artist $artist -Country $country -DetailUrl $detailUrl))
  }

  $records
}

$lines = Read-Utf8Lines $sourcePath
$countryOverrides = Load-CountryOverrides $CountryOverridesPath
$manualAdditions = @(Load-ManualAdditions $ManualAdditionsPath)
$manualAdditionCount = $manualAdditions.Count
$records = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[string]

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
  $artist = $body
  $country = "Unknown"

  if ($lastOpen -gt 0 -and $lastClose -gt $lastOpen) {
    $artist = $body.Substring(0, $lastOpen).Trim()
    $country = Normalize-Country($body.Substring($lastOpen + 1, $lastClose - $lastOpen - 1))
  } else {
    $warnings.Add("Missing country: $trimmed")
  }

  if ([string]::IsNullOrWhiteSpace($artist)) {
    $warnings.Add("Skipped empty-name line: $trimmed")
    continue
  }

  $records.Add((New-ArtistRecord -Year $year -Month $month -Artist $artist -Country $country))
}

$existingKeys = New-Object System.Collections.Generic.HashSet[string]
foreach ($record in $records) {
  [void]$existingKeys.Add((Build-RecordKey $record.label $record.artist))
}

foreach ($record in $manualAdditions) {
  $recordKey = Build-RecordKey $record.label $record.artist
  if ($existingKeys.Contains($recordKey)) {
    $warnings.Add("Skipped duplicate manual addition: $($record.label): $($record.artist)")
    continue
  }

  [void]$existingKeys.Add($recordKey)
  $records.Add($record)
}

$knownCountriesByArtist = @{}
foreach ($record in $records) {
  $specificKey = Build-RecordKey $record.label $record.artist
  $artistOnlyKey = "*|$(Normalize-ArtistKey $record.artist)"

  if ($record.country -eq "Unknown" -and $countryOverrides.ContainsKey($specificKey)) {
    $record.country = $countryOverrides[$specificKey]
    $warnings.Add("Resolved missing country from override: $($record.label): $($record.artist) -> $($record.country)")
  } elseif ($record.country -eq "Unknown" -and $countryOverrides.ContainsKey($artistOnlyKey)) {
    $record.country = $countryOverrides[$artistOnlyKey]
    $warnings.Add("Resolved missing country from override: $($record.label): $($record.artist) -> $($record.country)")
  }

  if ($record.country -eq "Unknown") {
    continue
  }

  $artistKey = Normalize-ArtistKey $record.artist
  if ([string]::IsNullOrWhiteSpace($artistKey)) {
    continue
  }

  if (-not $knownCountriesByArtist.ContainsKey($artistKey)) {
    $knownCountriesByArtist[$artistKey] = New-Object System.Collections.Generic.HashSet[string]
  }

  [void]$knownCountriesByArtist[$artistKey].Add($record.country)
}

$resolvedUnknownCount = 0
foreach ($record in $records) {
  if ($record.country -ne "Unknown") {
    continue
  }

  $artistKey = Normalize-ArtistKey $record.artist
  if ([string]::IsNullOrWhiteSpace($artistKey) -or -not $knownCountriesByArtist.ContainsKey($artistKey)) {
    continue
  }

  $candidateCountries = @($knownCountriesByArtist[$artistKey])
  if ($candidateCountries.Count -ne 1) {
    continue
  }

  $record.country = $candidateCountries[0]
  $resolvedUnknownCount += 1
  $warnings.Add("Resolved missing country from duplicate artist: $($record.label): $($record.artist) -> $($record.country)")
}

$unresolvedUnknowns = @($records | Where-Object { $_.country -eq "Unknown" } | ForEach-Object { "$($_.label): $($_.artist)" })
$sorted = $records | Sort-Object @{ Expression = "date"; Ascending = $true }, @{ Expression = "artist"; Ascending = $true }

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  totalArtists = $sorted.Count
  sourceCsv = $sourcePath
  manualAdditionsPath = $ManualAdditionsPath
  countryOverridesPath = $CountryOverridesPath
  manualAdditionCount = $manualAdditionCount
  resolvedMissingCountries = $resolvedUnknownCount
  unresolvedMissingCountries = $unresolvedUnknowns
  warnings = $warnings
  records = $sorted
}

$json = $payload | ConvertTo-Json -Depth 6
$js = "window.ARTIST_DATA = $json;"

$outDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

[System.IO.File]::WriteAllText($OutputPath, $js, $utf8NoBom)
Write-Output "Wrote $($sorted.Count) records to $OutputPath"

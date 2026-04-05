$downloadDir = "C:\Users\Mining-Base\Downloads"
$sourceFile = Get-ChildItem $downloadDir -Filter "*.csv" |
  Where-Object { $_.Length -gt 30000 } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

$sourcePath = $sourceFile.FullName
$outputPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artists-data.js"
$countryOverridePath = "C:\Users\Mining-Base\Downloads\無題のスプレッドシート - シート1 (1).csv"

if (-not $sourceFile) {
  throw "CSV not found in $downloadDir"
}

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

  return $builder.ToString()
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
  return $normalized
}

function Load-CountryOverrides {
  param([string]$Path)

  $overrides = @{}
  if (-not (Test-Path $Path)) {
    return $overrides
  }

  foreach ($line in (Read-Utf8Lines $Path)) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }

    $parts = $line.Split(',', 2)
    if ($parts.Count -ne 2) {
      continue
    }

    $artist = $parts[0].Trim()
    $country = Normalize-Country $parts[1]
    $artistKey = Normalize-ArtistKey $artist
    if ([string]::IsNullOrWhiteSpace($artistKey) -or [string]::IsNullOrWhiteSpace($country)) {
      continue
    }

    $overrides[$artistKey] = $country
  }

  return $overrides
}

$lines = Read-Utf8Lines $sourcePath
$countryOverrides = Load-CountryOverrides $countryOverridePath
foreach ($entry in @(
  @{ artist = "Debbie Donnelly"; country = "New Zealand" },
  @{ artist = "Allison Kovar"; country = "United States" },
  @{ artist = "Kostas Papakostas & Stephanie Pochet"; country = "United Kingdom" },
  @{ artist = "Kazutaka Fujii"; country = "Japan" },
  @{ artist = "Scott Harano"; country = "United States" },
  @{ artist = "Jenny Macgregor"; country = "United Kingdom" },
  @{ artist = "Kayla Milne"; country = "United Kingdom" },
  @{ artist = "Karen Jiang"; country = "United States" },
  @{ artist = "Chris Lightbody"; country = "United States" },
  @{ artist = "Gabrielle Rameriz"; country = "United States" },
  @{ artist = "Maya Hendricks"; country = "United States" },
  @{ artist = "Paula Schultz"; country = "United States" },
  @{ artist = "Andrina Manon"; country = "Australia" },
  @{ artist = "Marceau Verdiere"; country = "France" },
  @{ artist = ("Katarina " + [string][char]0x010C + "elebi" + [string][char]0x0107); country = "Serbia" }
)) {
  $countryOverrides[(Normalize-ArtistKey $entry.artist)] = Normalize-Country $entry.country
}

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

$knownCountriesByArtist = @{}
foreach ($record in $records) {
  $artistKey = Normalize-ArtistKey $record.artist
  if ($record.country -eq "Unknown" -and -not [string]::IsNullOrWhiteSpace($artistKey) -and $countryOverrides.ContainsKey($artistKey)) {
    $record.country = $countryOverrides[$artistKey]
    $warnings.Add("Resolved missing country from override: $($record.label): $($record.artist) -> $($record.country)")
  }

  if ($record.country -eq "Unknown") {
    continue
  }

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

$unresolvedUnknowns = $records | Where-Object { $_.country -eq "Unknown" } | ForEach-Object { "$($_.label): $($_.artist)" }
$sorted = $records | Sort-Object @{ Expression = "date"; Ascending = $true }, @{ Expression = "artist"; Ascending = $true }

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  totalArtists = $sorted.Count
  resolvedMissingCountries = $resolvedUnknownCount
  unresolvedMissingCountries = $unresolvedUnknowns
  warnings = $warnings
  records = $sorted
}

$json = $payload | ConvertTo-Json -Depth 6
$js = "window.ARTIST_DATA = $json;"

$outDir = Split-Path $outputPath -Parent
if (-not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

[System.IO.File]::WriteAllText($outputPath, $js, $utf8NoBom)
Write-Output "Wrote $($sorted.Count) records to $outputPath"

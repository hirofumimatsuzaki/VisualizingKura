param(
  [string]$SourcePath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artistlist-source.html",
  [string]$ArtistDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artists-data.js",
  [string]$OutputPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artist-profiles.js",
  [switch]$FetchImages,
  [int]$MinImageYear = 2024,
  [int]$ImageLimit = 180
)

function Read-Utf8Text {
  param([string]$Path)
  [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($Path))
}

function Decode-HtmlText {
  param([string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ""
  }

  $decoded = [System.Net.WebUtility]::HtmlDecode($Text)
  $decoded = [regex]::Replace($decoded, '<[^>]+>', ' ')
  $decoded = [regex]::Replace($decoded, '\s+', ' ')
  $decoded.Trim()
}

function Normalize-Country {
  param([string]$Country)

  $normalized = Decode-HtmlText $Country
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    return ""
  }

  $normalized = $normalized -replace ',\s*The 3dsense-Kura Artistic Residency Award.*$', ''
  if ($normalized -eq 'Great Britain') { return 'United Kingdom' }
  $normalized.Trim(' ', ',', ';')
}

function Normalize-KeyText {
  param([string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ""
  }

  $decoded = Decode-HtmlText $Text
  $formD = $decoded.Normalize([Text.NormalizationForm]::FormD)
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

function Get-AbsoluteUrl {
  param(
    [string]$Url,
    [string]$BaseUrl = 'https://studiokura.info/en/'
  )

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return ""
  }

  $trimmed = $Url.Trim()
  if ($trimmed -match '^https?://') {
    return $trimmed
  }

  if ($trimmed.StartsWith('/cake/residences/')) {
    return "https://online.studiokura.com$trimmed"
  }

  if ($trimmed.StartsWith('/')) {
    return "https://studiokura.info$trimmed"
  }

  try {
    ([System.Uri]::new([System.Uri]::new($BaseUrl), $trimmed)).AbsoluteUri
  } catch {
    ""
  }
}

function Test-ImageUrl {
  param([string]$Url)
  $Url -match '\.(jpg|jpeg|png|webp|gif)(\?|$)'
}

function Test-ValidDetailUrl {
  param([string]$Url)

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return $false
  }

  try {
    $uri = [System.Uri]::new($Url)
  } catch {
    return $false
  }

  $urlHost = $uri.Host.ToLowerInvariant()
  if ($urlHost -notlike '*studiokura.info' -and $urlHost -notlike '*artsitoya.com') {
    return $false
  }

  $path = $uri.AbsolutePath
  if ($path.StartsWith('/cake/residences/')) {
    return $false
  }
  if ($path.StartsWith('/wp-content/uploads/')) {
    return $false
  }

  return $true
}

function Get-ImageFromDetailPage {
  param([string]$Url)

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return ""
  }

  try {
    $html = & curl.exe -L --silent --show-error $Url
  } catch {
    return ""
  }

  if ([string]::IsNullOrWhiteSpace($html)) {
    return ""
  }

  $patterns = @(
    '<meta[^>]+property=["'']og:image["''][^>]+content=["'']([^"''>]+)["'']',
    '<img[^>]+class=["''][^"''>]*wp-post-image[^"''>]*["''][^>]+src=["'']([^"''>]+)["'']',
    '<img[^>]+class=["''][^"''>]*attachment-[^"''>]*["''][^>]+src=["'']([^"''>]+)["'']',
    '<img[^>]+src=["'']([^"''>]+)["'']'
  )

  foreach ($pattern in $patterns) {
    $match = [regex]::Match($html, $pattern, 'IgnoreCase')
    if (-not $match.Success) {
      continue
    }

    $candidate = Get-AbsoluteUrl $match.Groups[1].Value $Url
    if (-not (Test-ImageUrl $candidate)) {
      continue
    }

    if ($candidate -match 'logo|icon|banner|fablab|resartis|asialink|itoshimanow|fukuokanow') {
      continue
    }

    return $candidate
  }

  ""
}

function Get-SourceEntries {
  param([string]$Html)

  $entries = New-Object System.Collections.Generic.List[object]
  $liMatches = [regex]::Matches($Html, '<li\b[^>]*>(.*?)</li>', 'Singleline,IgnoreCase')

  foreach ($match in $liMatches) {
    $innerHtml = $match.Groups[1].Value
    $text = Decode-HtmlText $innerHtml
    if ($text -notmatch '^(\d{4}/\d{2}):\s*(.+)$') {
      continue
    }

    $label = $matches[1]
    $country = ""
    if ($text -match '\(([^()]+)\)\s*$') {
      $country = Normalize-Country $matches[1]
    }

    $artist = ""
    $detailUrl = ""
    $imageUrl = ""

    $linkMatch = [regex]::Match($innerHtml, '<a[^>]+href=["'']([^"'']+)["''][^>]*>(.*?)</a>', 'Singleline,IgnoreCase')
    if ($linkMatch.Success) {
      $artist = Decode-HtmlText $linkMatch.Groups[2].Value
      $absolute = Get-AbsoluteUrl $linkMatch.Groups[1].Value
      if (Test-ImageUrl $absolute) {
        $imageUrl = $absolute
      } elseif (Test-ValidDetailUrl $absolute) {
        $detailUrl = $absolute
      }
    } else {
      $artist = $text -replace '^\d{4}/\d{2}:\s*', ''
      if ($country) {
        $escapedCountry = [regex]::Escape($country)
        $artist = $artist -replace "\s*\($escapedCountry\)\s*$", ''
      }
      $artist = $artist.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($artist) -or $artist -match '^\d+$') {
      continue
    }

    $entries.Add([pscustomobject]@{
      label = $label
      artist = $artist
      country = $country
      detailUrl = $detailUrl
      imageUrl = $imageUrl
      artistKey = Normalize-KeyText $artist
      countryKey = Normalize-KeyText $country
    })
  }

  $entries
}

function Get-MatchScore {
  param($Record, $Candidate)

  $recordArtistKey = Normalize-KeyText $Record.artist
  $recordCountryKey = Normalize-KeyText $Record.country
  $score = 0

  if ($Candidate.countryKey -eq $recordCountryKey) {
    $score += 30
  }

  if ($Candidate.artistKey -eq $recordArtistKey) {
    $score += 100
  } elseif ($Candidate.artistKey.Contains($recordArtistKey) -or $recordArtistKey.Contains($Candidate.artistKey)) {
    $score += 75
  }

  if ($Candidate.label -eq $Record.label) {
    $score += 20
  }

  $score
}

function Find-BestSourceEntry {
  param(
    $Record,
    [hashtable]$EntriesByLabel,
    [hashtable]$EntriesByLabelCountry
  )

  $countryKey = Normalize-KeyText $Record.country
  $groupKey = "$($Record.label)|$countryKey"

  $candidates = @()
  if ($EntriesByLabelCountry.ContainsKey($groupKey)) {
    $candidates = $EntriesByLabelCountry[$groupKey]
  } elseif ($EntriesByLabel.ContainsKey($Record.label)) {
    $candidates = $EntriesByLabel[$Record.label]
  }

  if (-not $candidates -or $candidates.Count -eq 0) {
    return $null
  }

  $best = $null
  $bestScore = -1
  foreach ($candidate in $candidates) {
    $score = Get-MatchScore $Record $candidate
    if ($score -gt $bestScore) {
      $best = $candidate
      $bestScore = $score
    }
  }

  if ($bestScore -lt 50) {
    return $null
  }

  $best
}

if (-not (Test-Path $SourcePath)) {
  $sourceHtml = & curl.exe -L --silent --show-error 'https://online.studiokura.com/cake/residences/artistlist/en'
  if ([string]::IsNullOrWhiteSpace($sourceHtml)) {
    throw "Source HTML not found at $SourcePath and could not be downloaded."
  }
  [System.IO.File]::WriteAllText($SourcePath, $sourceHtml, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path $ArtistDataPath)) {
  throw "Artist data not found at $ArtistDataPath"
}

$listHtml = Read-Utf8Text $SourcePath
$artistDataJson = (Read-Utf8Text $ArtistDataPath) -replace '^window\.ARTIST_DATA\s*=\s*', '' -replace ';\s*$', ''
$artistData = $artistDataJson | ConvertFrom-Json
$sourceEntries = Get-SourceEntries $listHtml

$entriesByLabel = @{}
$entriesByLabelCountry = @{}
foreach ($entry in $sourceEntries) {
  if (-not $entriesByLabel.ContainsKey($entry.label)) {
    $entriesByLabel[$entry.label] = New-Object System.Collections.Generic.List[object]
  }
  $entriesByLabel[$entry.label].Add($entry)

  $groupKey = "$($entry.label)|$($entry.countryKey)"
  if (-not $entriesByLabelCountry.ContainsKey($groupKey)) {
    $entriesByLabelCountry[$groupKey] = New-Object System.Collections.Generic.List[object]
  }
  $entriesByLabelCountry[$groupKey].Add($entry)
}

$detailCache = @{}
$records = New-Object System.Collections.Generic.List[object]
$withDetails = 0
$withImages = 0
$unmatched = New-Object System.Collections.Generic.List[string]
$imageFetchCount = 0

foreach ($record in $artistData.records) {
  $match = Find-BestSourceEntry $record $entriesByLabel $entriesByLabelCountry

  $detailUrl = ""
  $imageUrl = ""
  if ($match) {
    $detailUrl = $match.detailUrl
    $imageUrl = $match.imageUrl

    $shouldFetchImage = $FetchImages -and $detailUrl -and -not $imageUrl -and $record.year -ge $MinImageYear
    if ($shouldFetchImage -and ($ImageLimit -le 0 -or $imageFetchCount -lt $ImageLimit)) {
      if (-not $detailCache.ContainsKey($detailUrl)) {
        $detailCache[$detailUrl] = Get-ImageFromDetailPage $detailUrl
        $imageFetchCount += 1
      }
      $imageUrl = $detailCache[$detailUrl]
    }
  } else {
    $unmatched.Add("$($record.label): $($record.artist)")
  }

  if ($detailUrl) { $withDetails += 1 }
  if ($imageUrl) { $withImages += 1 }

  $records.Add([pscustomobject]@{
    label = $record.label
    artist = $record.artist
    country = $record.country
    detailUrl = $detailUrl
    imageUrl = $imageUrl
  })
}

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  totalProfiles = $records.Count
  profilesWithDetailUrl = $withDetails
  profilesWithImageUrl = $withImages
  unmatched = $unmatched
  records = $records
}

$json = $payload | ConvertTo-Json -Depth 6
$js = "window.ARTIST_PROFILES = $json;"
[System.IO.File]::WriteAllText($OutputPath, $js, [System.Text.UTF8Encoding]::new($false))

Write-Output "Wrote $($records.Count) profile records to $OutputPath"
Write-Output "Profiles with detail URLs: $withDetails"
Write-Output "Profiles with image URLs: $withImages"
Write-Output "Unmatched records: $($unmatched.Count)"

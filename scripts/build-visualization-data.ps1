param(
  [string]$ArtistDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artists-data.js",
  [string]$ProfileDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artist-profiles.js",
  [string]$MetadataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artist-metadata.js",
  [string]$OutputPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\visualization-data.js"
)

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-Utf8Text {
  param([string]$Path)
  $utf8NoBom.GetString([System.IO.File]::ReadAllBytes($Path))
}

function Read-WindowPayload {
  param(
    [string]$Path,
    [string]$VariableName
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  $pattern = "^window\.$VariableName\s*=\s*"
  ((Read-Utf8Text $Path) -replace $pattern, "" -replace ";\s*$", "") | ConvertFrom-Json
}

function Normalize-KeyText {
  param([string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ""
  }

  $formD = $Text.Normalize([Text.NormalizationForm]::FormD)
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

function Build-ProfileKey {
  param(
    [string]$Label,
    [string]$Artist,
    [string]$Country
  )

  "$Label|$(Normalize-KeyText $Artist)|$(Normalize-KeyText $Country)"
}

function Build-MetadataKey {
  param(
    [string]$Label,
    [string]$Artist
  )

  "$Label|$(Normalize-KeyText $Artist)"
}

$artistData = Read-WindowPayload $ArtistDataPath "ARTIST_DATA"
if (-not $artistData -or -not $artistData.records) {
  throw "Artist data not found at $ArtistDataPath"
}

$profileData = Read-WindowPayload $ProfileDataPath "ARTIST_PROFILES"
$metadataData = Read-WindowPayload $MetadataPath "ARTIST_METADATA"

$profileLookup = @{}
if ($profileData -and $profileData.records) {
  foreach ($profileRecord in $profileData.records) {
    $exactKey = Build-ProfileKey $profileRecord.label $profileRecord.artist $profileRecord.country
    if (-not $profileLookup.ContainsKey($exactKey)) {
      $profileLookup[$exactKey] = $profileRecord.detailUrl
    }

    $fallbackKey = Build-ProfileKey $profileRecord.label $profileRecord.artist ""
    if (-not $profileLookup.ContainsKey($fallbackKey)) {
      $profileLookup[$fallbackKey] = $profileRecord.detailUrl
    }
  }
}

$metadataLookup = @{}
if ($metadataData -and $metadataData.records) {
  foreach ($entry in $metadataData.records.PSObject.Properties) {
    $metadataLookup[$entry.Name] = $entry.Value
  }
}

$records = New-Object System.Collections.Generic.List[object]
$profilesResolved = 0
$genresResolved = 0

foreach ($artistRecord in $artistData.records) {
  $detailUrl = $artistRecord.detailUrl
  if ([string]::IsNullOrWhiteSpace($detailUrl)) {
    $detailUrl =
      $profileLookup[(Build-ProfileKey $artistRecord.label $artistRecord.artist $artistRecord.country)]

    if ([string]::IsNullOrWhiteSpace($detailUrl)) {
      $detailUrl = $profileLookup[(Build-ProfileKey $artistRecord.label $artistRecord.artist "")]
    }
  }

  $metadata = $metadataLookup[(Build-MetadataKey $artistRecord.label $artistRecord.artist)]
  $genre = if ($metadata -and $metadata.genre) { [string]$metadata.genre } else { "Unspecified" }

  if (-not [string]::IsNullOrWhiteSpace($detailUrl)) {
    $profilesResolved += 1
  }
  if ($genre -ne "Unspecified") {
    $genresResolved += 1
  }

  $records.Add([pscustomobject]@{
    year = $artistRecord.year
    month = $artistRecord.month
    date = $artistRecord.date
    label = $artistRecord.label
    artist = $artistRecord.artist
    country = $artistRecord.country
    detailUrl = $detailUrl
    genre = $genre
  })
}

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  totalArtists = $records.Count
  profilesResolved = $profilesResolved
  genresResolved = $genresResolved
  source = [pscustomobject]@{
    artistDataPath = $ArtistDataPath
    profileDataPath = $ProfileDataPath
    metadataPath = $MetadataPath
  }
  records = $records
}

[System.IO.File]::WriteAllText($OutputPath, "window.VISUALIZATION_DATA = $($payload | ConvertTo-Json -Depth 6);", $utf8NoBom)
Write-Output "Wrote $($records.Count) visualization records to $OutputPath"

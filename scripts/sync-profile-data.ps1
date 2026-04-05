param(
  [string]$ArtistDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artists-data.js",
  [string]$ProfileDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artist-profiles.js",
  [string]$ImageDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artist-images.js",
  [string]$ManualAdditionsPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\manual-artists.csv"
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

function Read-Utf8Lines {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return @()
  }

  (Read-Utf8Text $Path) -split "`r?`n"
}

function Load-ManualDetailUrls {
  param([string]$Path)

  $lookup = @{}
  foreach ($line in (Read-Utf8Lines $Path)) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }

    $trimmed = $line.Trim()
    if ($trimmed -eq "label,artist,country" -or $trimmed -eq "label,artist,country,detailUrl") {
      continue
    }

    $parts = $trimmed.Split(',', 4)
    if ($parts.Count -lt 4) {
      continue
    }

    $label = $parts[0].Trim()
    $artist = $parts[1].Trim()
    $country = $parts[2].Trim()
    $detailUrl = $parts[3].Trim()
    if ([string]::IsNullOrWhiteSpace($label) -or [string]::IsNullOrWhiteSpace($artist) -or [string]::IsNullOrWhiteSpace($detailUrl)) {
      continue
    }

    $lookup[(Build-ProfileKey $label $artist $country)] = $detailUrl
    $lookup[(Build-ProfileKey $label $artist "")] = $detailUrl
  }

  $lookup
}

$artistData = Read-WindowPayload $ArtistDataPath "ARTIST_DATA"
$profileData = Read-WindowPayload $ProfileDataPath "ARTIST_PROFILES"
$imageData = Read-WindowPayload $ImageDataPath "ARTIST_IMAGES"
$manualDetailUrls = Load-ManualDetailUrls $ManualAdditionsPath

$remappedImages = [ordered]@{}
$profileRecords = New-Object System.Collections.Generic.List[object]
$profileLookup = @{}

foreach ($profileRecord in $profileData.records) {
  $key = Build-ProfileKey $profileRecord.label $profileRecord.artist $profileRecord.country
  if (-not $profileLookup.ContainsKey($key)) {
    $profileLookup[$key] = $profileRecord
  }

  $fallbackKey = Build-ProfileKey $profileRecord.label $profileRecord.artist ""
  if (-not $profileLookup.ContainsKey($fallbackKey)) {
    $profileLookup[$fallbackKey] = $profileRecord
  }
}

foreach ($artistRecord in $artistData.records) {
  $newKey = Build-ProfileKey $artistRecord.label $artistRecord.artist $artistRecord.country
  $profileRecord =
    $profileLookup[$newKey]

  if (-not $profileRecord) {
    $profileRecord = $profileLookup[(Build-ProfileKey $artistRecord.label $artistRecord.artist "")]
  }

  if ($profileRecord) {
    $oldKey = Build-ProfileKey $profileRecord.label $profileRecord.artist $profileRecord.country
    $imageUrl = $imageData.records.$oldKey
  } else {
    $imageUrl = $null
  }

  if ($imageUrl) {
    $remappedImages[$newKey] = $imageUrl
  }

  $profileRecords.Add([pscustomobject]@{
    label = $artistRecord.label
    artist = $artistRecord.artist
    country = $artistRecord.country
    detailUrl = if ($manualDetailUrls.ContainsKey($newKey)) { $manualDetailUrls[$newKey] } elseif ($profileRecord) { $profileRecord.detailUrl } else { "" }
  })
}

$generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

$profilePayload = [pscustomobject]@{
  generatedAt = $generatedAt
  totalProfiles = $profileRecords.Count
  profilesWithDetailUrl = ($profileRecords | Where-Object { -not [string]::IsNullOrWhiteSpace($_.detailUrl) }).Count
  profilesWithImageUrl = $remappedImages.Count
  unmatched = $profileData.unmatched
  records = $profileRecords
}

$imagePayload = [pscustomobject]@{
  generatedAt = $generatedAt
  totalImages = $remappedImages.Count
  records = $remappedImages
}

[System.IO.File]::WriteAllText($ProfileDataPath, "window.ARTIST_PROFILES = $($profilePayload | ConvertTo-Json -Depth 6);", $utf8NoBom)
[System.IO.File]::WriteAllText($ImageDataPath, "window.ARTIST_IMAGES = $($imagePayload | ConvertTo-Json -Depth 6);", $utf8NoBom)

Write-Output "Synchronized $($profileRecords.Count) profile records"
Write-Output "Remapped $($remappedImages.Count) image keys"

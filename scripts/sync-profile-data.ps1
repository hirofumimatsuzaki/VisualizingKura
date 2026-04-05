param(
  [string]$ArtistDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artists-data.js",
  [string]$ProfileDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artist-profiles.js",
  [string]$ImageDataPath = "C:\Users\Mining-Base\Documents\VisualizingKura\data\artist-images.js"
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

$artistData = Read-WindowPayload $ArtistDataPath "ARTIST_DATA"
$profileData = Read-WindowPayload $ProfileDataPath "ARTIST_PROFILES"
$imageData = Read-WindowPayload $ImageDataPath "ARTIST_IMAGES"

if ($artistData.records.Count -ne $profileData.records.Count) {
  throw "Artist/profile record count mismatch: $($artistData.records.Count) vs $($profileData.records.Count)"
}

$remappedImages = [ordered]@{}
$profileRecords = New-Object System.Collections.Generic.List[object]

for ($i = 0; $i -lt $profileData.records.Count; $i++) {
  $artistRecord = $artistData.records[$i]
  $profileRecord = $profileData.records[$i]

  if ($artistRecord.label -ne $profileRecord.label) {
    throw "Label mismatch at index ${i}: $($artistRecord.label) vs $($profileRecord.label)"
  }

  $oldKey = Build-ProfileKey $profileRecord.label $profileRecord.artist $profileRecord.country
  $newKey = Build-ProfileKey $artistRecord.label $artistRecord.artist $artistRecord.country
  $imageUrl = $imageData.records.$oldKey
  if ($imageUrl) {
    $remappedImages[$newKey] = $imageUrl
  }

  $profileRecords.Add([pscustomobject]@{
    label = $artistRecord.label
    artist = $artistRecord.artist
    country = $artistRecord.country
    detailUrl = $profileRecord.detailUrl
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

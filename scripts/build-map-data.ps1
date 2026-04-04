$sourceDir = "C:\Users\Mining-Base\Documents\VisualizingKura\data"
$targets = @(
  @{ Input = "land-110m.json"; Output = "world-land.js"; Variable = "WORLD_LAND_TOPOLOGY" },
  @{ Input = "countries-110m.json"; Output = "world-countries.js"; Variable = "WORLD_COUNTRIES_TOPOLOGY" }
)

foreach ($target in $targets) {
  $inputPath = Join-Path $sourceDir $target.Input
  $outputPath = Join-Path $sourceDir $target.Output

  if (-not (Test-Path $inputPath)) {
    throw "Missing source map file: $inputPath"
  }

  $json = Get-Content $inputPath -Raw
  $js = "window.$($target.Variable) = $json;"
  [System.IO.File]::WriteAllText($outputPath, $js, [System.Text.UTF8Encoding]::new($false))
  Write-Output "Wrote $outputPath"
}

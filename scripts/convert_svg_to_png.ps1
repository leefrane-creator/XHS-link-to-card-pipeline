param(
  [string]$InputDir = (Get-Location).Path,
  [string]$OutputDir = (Join-Path (Get-Location).Path "png_output"),
  [int]$Width = 1242,
  [int]$Height = 1660,
  [bool]$Recurse = $true
)

$ErrorActionPreference = "Stop"

function Resolve-EdgePath {
  $candidates = @()

  $cmd = Get-Command "msedge" -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
    $candidates += $cmd.Source
  }

  if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe")
  }

  if ($env:"ProgramFiles(x86)") {
    $candidates += (Join-Path $env:"ProgramFiles(x86)" "Microsoft\Edge\Application\msedge.exe")
  }

  foreach ($p in ($candidates | Select-Object -Unique)) {
    if ($p -and (Test-Path $p)) { return $p }
  }

  return $null
}

$edge = Resolve-EdgePath
if (-not $edge) {
  Write-Error "Microsoft Edge (msedge.exe) not found. Please install Edge or ensure msedge.exe exists under Program Files."
  exit 1
}

if (!(Test-Path $InputDir)) {
  Write-Error "InputDir not found: $InputDir"
  exit 1
}

if (!(Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$svgs = Get-ChildItem -Path $InputDir -Filter *.svg -File -Recurse:$Recurse
if (-not $svgs -or $svgs.Count -eq 0) {
  Write-Output "No SVG files found under: $InputDir"
  exit 0
}

Write-Output "Edge: $edge"
Write-Output "Input: $InputDir"
Write-Output "Output: $OutputDir"
Write-Output "Target: ${Width}x${Height}"
Write-Output ("Found SVGs: {0}" -f $svgs.Count)

foreach ($svg in $svgs) {
  $svgUrl = "file:///" + ($svg.FullName -replace '\\','/')
  $wrap = Join-Path $env:TEMP ($svg.BaseName + ".__xhs_wrap__.html")
  $wrapUrl = "file:///" + ($wrap -replace '\\','/')
  $outFile = Join-Path $OutputDir ($svg.BaseName + ".png")

  @"
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1, viewport-fit=cover">
    <style>
      html, body {
        margin: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: transparent;
      }
      img {
        position: fixed;
        inset: 0;
        width: 100vw;
        height: 100vh;
        display: block;
        object-fit: cover;          /* 关键：强制铺满，避免 contain 产生留白 */
        object-position: center;
      }
    </style>
  </head>
  <body>
    <img src="$svgUrl" alt="card" />
  </body>
</html>
"@ | Set-Content -LiteralPath $wrap -Encoding utf8

  try {
    & $edge `
      --headless `
      --disable-gpu `
      --hide-scrollbars `
      --no-first-run `
      --no-default-browser-check `
      --disable-extensions `
      --force-device-scale-factor=1 `
      --window-size=$Width,$Height `
      --virtual-time-budget=1500 `
      --screenshot=$outFile `
      $wrapUrl | Out-Null

    Write-Output "Converted: $outFile (${Width}x${Height})"
  } finally {
    if (Test-Path $wrap) { Remove-Item -Force $wrap -ErrorAction SilentlyContinue }
  }
}

Write-Output "Done."

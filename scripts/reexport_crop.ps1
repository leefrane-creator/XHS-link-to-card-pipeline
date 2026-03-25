param(
  [string]$InputDir,
  [string]$OutputDir,
  [int]$Width = 1242,
  [int]$Height = 1660,
  [int]$CaptureWidth = 1320,
  [int]$CaptureHeight = 1820,
  [switch]$Recurse = $true
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Resolve-EdgePath {
  $candidates = @()
  $cmd = Get-Command "msedge" -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) { $candidates += $cmd.Source }
  if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe") }
  if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe") }
  foreach ($p in ($candidates | Select-Object -Unique)) { if ($p -and (Test-Path $p)) { return $p } }
  return $null
}

if (!(Test-Path $InputDir)) { throw "InputDir not found: $InputDir" }
if (!(Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$edge = Resolve-EdgePath
if (-not $edge) { throw "Microsoft Edge not found" }

$svgs = Get-ChildItem -Path $InputDir -Filter *.svg -File -Recurse:$Recurse
if (-not $svgs) { Write-Output "No SVG found"; exit 0 }

foreach ($svg in $svgs) {
  $tmpPng = Join-Path $env:TEMP ($svg.BaseName + '.__capture__.png')
  $outPng = Join-Path $OutputDir ($svg.BaseName + '.png')
  $url = 'file:///' + ($svg.FullName -replace '\\','/')

  & $edge --headless --disable-gpu --hide-scrollbars --no-first-run --no-default-browser-check --disable-extensions --force-device-scale-factor=1 --window-size=$CaptureWidth,$CaptureHeight --virtual-time-budget=1500 --screenshot=$tmpPng $url | Out-Null

  $src = [System.Drawing.Bitmap]::FromFile($tmpPng)
  try {
    if ($src.Width -lt $Width -or $src.Height -lt $Height) {
      throw "Captured image too small: $($src.Width)x$($src.Height)"
    }
    $rect = New-Object System.Drawing.Rectangle 0,0,$Width,$Height
    $dst = $src.Clone($rect, $src.PixelFormat)
    try {
      $dst.Save($outPng, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
      $dst.Dispose()
    }
  }
  finally {
    $src.Dispose()
    if (Test-Path $tmpPng) { Remove-Item -LiteralPath $tmpPng -Force -ErrorAction SilentlyContinue }
  }

  Write-Output "Rebuilt: $outPng"
}

Write-Output "Done."

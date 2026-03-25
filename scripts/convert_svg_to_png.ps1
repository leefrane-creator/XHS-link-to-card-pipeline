param(
  [string]$InputDir = (Get-Location).Path,
  [string]$OutputDir = (Join-Path (Get-Location).Path "png_output"),
  [int]$Width = 1242,
  [int]$Height = 1660,
  [bool]$Recurse = $true,
  [switch]$NoAutoFix,
  [switch]$ValidationOnly
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function Resolve-EdgePath {
  $candidates = @()

  $cmd = Get-Command "msedge" -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
    $candidates += $cmd.Source
  }

  if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe")
  }

  if (${env:ProgramFiles(x86)}) {
    $candidates += (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe")
  }

  foreach ($p in ($candidates | Select-Object -Unique)) {
    if ($p -and (Test-Path $p)) { return $p }
  }

  return $null
}

function Get-ColorDistance {
  param([System.Drawing.Color]$A, [System.Drawing.Color]$B)
  $dr = [double]($A.R - $B.R)
  $dg = [double]($A.G - $B.G)
  $db = [double]($A.B - $B.B)
  return [Math]::Sqrt($dr*$dr + $dg*$dg + $db*$db)
}

function Get-ColumnStats {
  param([System.Drawing.Bitmap]$Bmp, [int]$X)
  $sum = 0.0
  $sumSq = 0.0
  $count = 0
  for ($y = 0; $y -lt $Bmp.Height; $y += 4) {
    $c = $Bmp.GetPixel($X, $y)
    $lum = 0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B
    $sum += $lum
    $sumSq += $lum * $lum
    $count++
  }
  if ($count -eq 0) { return @{Mean=0.0; StdDev=0.0} }
  $mean = $sum / $count
  $var = [Math]::Max(0.0, ($sumSq / $count) - ($mean * $mean))
  return @{Mean=$mean; StdDev=[Math]::Sqrt($var)}
}

function Get-RowStats {
  param([System.Drawing.Bitmap]$Bmp, [int]$Y)
  $sum = 0.0
  $sumSq = 0.0
  $count = 0
  for ($x = 0; $x -lt $Bmp.Width; $x += 4) {
    $c = $Bmp.GetPixel($x, $Y)
    $lum = 0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B
    $sum += $lum
    $sumSq += $lum * $lum
    $count++
  }
  if ($count -eq 0) { return @{Mean=0.0; StdDev=0.0} }
  $mean = $sum / $count
  $var = [Math]::Max(0.0, ($sumSq / $count) - ($mean * $mean))
  return @{Mean=$mean; StdDev=[Math]::Sqrt($var)}
}

function Get-ExtremeRightBand {
  param(
    [System.Drawing.Bitmap]$Bmp,
    [System.Drawing.Color]$EdgeColor
  )
  $band = 0
  for ($x = $Bmp.Width - 1; $x -ge 0; $x--) {
    $stats = Get-ColumnStats -Bmp $Bmp -X $x
    $isExtreme = (($stats.Mean -le 6.0) -or ($stats.Mean -ge 249.0))
    $isFlat = ($stats.StdDev -le 1.6)
    $distSum = 0.0
    $distCount = 0
    for ($y = 0; $y -lt $Bmp.Height; $y += 8) {
      $distSum += Get-ColorDistance -A ($Bmp.GetPixel($x, $y)) -B $EdgeColor
      $distCount++
    }
    $avgDist = if ($distCount -gt 0) { $distSum / $distCount } else { 0.0 }
    $isForeignFlat = ($isFlat -and $avgDist -ge 12.0)

    if (($isExtreme -and $isFlat) -or $isForeignFlat) {
      $band++
      continue
    }
    break
  }
  if ($band -lt 4) { return 0 }
  return $band
}

function Get-ExtremeBottomBand {
  param(
    [System.Drawing.Bitmap]$Bmp,
    [System.Drawing.Color]$EdgeColor
  )
  $band = 0
  for ($y = $Bmp.Height - 1; $y -ge 0; $y--) {
    $stats = Get-RowStats -Bmp $Bmp -Y $y
    $isExtreme = (($stats.Mean -le 6.0) -or ($stats.Mean -ge 249.0))
    $isFlat = ($stats.StdDev -le 1.6)
    $distSum = 0.0
    $distCount = 0
    for ($x = 0; $x -lt $Bmp.Width; $x += 8) {
      $distSum += Get-ColorDistance -A ($Bmp.GetPixel($x, $y)) -B $EdgeColor
      $distCount++
    }
    $avgDist = if ($distCount -gt 0) { $distSum / $distCount } else { 0.0 }
    $isForeignFlat = ($isFlat -and $avgDist -ge 12.0)

    if (($isExtreme -and $isFlat) -or $isForeignFlat) {
      $band++
      continue
    }
    break
  }
  if ($band -lt 4) { return 0 }
  return $band
}

function Fill-EdgeBands {
  param(
    [System.Drawing.Bitmap]$Bmp,
    [int]$RightBand,
    [int]$BottomBand
  )

  if ($RightBand -gt 0) {
    $startX = $Bmp.Width - $RightBand
    $srcX = [Math]::Max(0, $startX - 1)
    for ($x = $startX; $x -lt $Bmp.Width; $x++) {
      for ($y = 0; $y -lt $Bmp.Height; $y++) {
        $Bmp.SetPixel($x, $y, $Bmp.GetPixel($srcX, $y))
      }
    }
  }

  if ($BottomBand -gt 0) {
    $startY = $Bmp.Height - $BottomBand
    $srcY = [Math]::Max(0, $startY - 1)
    for ($y = $startY; $y -lt $Bmp.Height; $y++) {
      for ($x = 0; $x -lt $Bmp.Width; $x++) {
        $Bmp.SetPixel($x, $y, $Bmp.GetPixel($x, $srcY))
      }
    }
  }
}

function Validate-Image {
  param(
    [string]$Path,
    [int]$ExpectedWidth,
    [int]$ExpectedHeight,
    [switch]$AutoFix
  )

  $bmp = [System.Drawing.Bitmap]::FromFile($Path)
  try {
    $sizeOk = ($bmp.Width -eq $ExpectedWidth -and $bmp.Height -eq $ExpectedHeight)

    $tl = $bmp.GetPixel(0, 0)
    $tr = $bmp.GetPixel($bmp.Width - 1, 0)
    $bl = $bmp.GetPixel(0, $bmp.Height - 1)
    $br = $bmp.GetPixel($bmp.Width - 1, $bmp.Height - 1)

    $cornerMaxDistance = 0.0

    $rightBand = Get-ExtremeRightBand -Bmp $bmp -EdgeColor $tl
    $bottomBand = Get-ExtremeBottomBand -Bmp $bmp -EdgeColor $tl

    $fixed = $false
    if ($AutoFix -and ($rightBand -gt 0 -or $bottomBand -gt 0)) {
      $fixedBmp = New-Object System.Drawing.Bitmap $bmp
      Fill-EdgeBands -Bmp $fixedBmp -RightBand $rightBand -BottomBand $bottomBand

      $tmpPath = "$Path.__fixed__.png"
      $fixedBmp.Save($tmpPath, [System.Drawing.Imaging.ImageFormat]::Png)
      $fixed = $true

      # recompute corners after fix
      $tl = $fixedBmp.GetPixel(0, 0)
      $tr = $fixedBmp.GetPixel($fixedBmp.Width - 1, 0)
      $bl = $fixedBmp.GetPixel(0, $fixedBmp.Height - 1)
      $br = $fixedBmp.GetPixel($fixedBmp.Width - 1, $fixedBmp.Height - 1)
      $cornerMaxDistance = 0.0
      $rightBand = 0
      $bottomBand = 0

      $fixedBmp.Dispose()
      $bmp.Dispose()
      Move-Item -LiteralPath $tmpPath -Destination $Path -Force
      $bmp = [System.Drawing.Bitmap]::FromFile($Path)
    }

    # Gradient background may differ at corners; validate continuity against adjacent inner edge instead.
    $rightEdgeAvg = 0.0
    $rightEdgeCount = 0
    for ($y = 0; $y -lt $bmp.Height; $y += 8) {
      $rightEdgeAvg += Get-ColorDistance -A ($bmp.GetPixel($bmp.Width - 1, $y)) -B ($bmp.GetPixel($bmp.Width - 2, $y))
      $rightEdgeCount++
    }
    if ($rightEdgeCount -gt 0) { $rightEdgeAvg = $rightEdgeAvg / $rightEdgeCount }

    $bottomEdgeAvg = 0.0
    $bottomEdgeCount = 0
    for ($x = 0; $x -lt $bmp.Width; $x += 8) {
      $bottomEdgeAvg += Get-ColorDistance -A ($bmp.GetPixel($x, $bmp.Height - 1)) -B ($bmp.GetPixel($x, $bmp.Height - 2))
      $bottomEdgeCount++
    }
    if ($bottomEdgeCount -gt 0) { $bottomEdgeAvg = $bottomEdgeAvg / $bottomEdgeCount }

    $cornersOk = ($rightEdgeAvg -le 12.0 -and $bottomEdgeAvg -le 12.0)
    $bandsOk = ($rightBand -eq 0 -and $bottomBand -eq 0)

    return [PSCustomObject]@{
      Path = $Path
      SizeOk = $sizeOk
      CornersOk = $cornersOk
      BandsOk = $bandsOk
      CornerMaxDistance = [Math]::Round([Math]::Max($rightEdgeAvg, $bottomEdgeAvg), 2)
      RightBand = $rightBand
      BottomBand = $bottomBand
      Fixed = $fixed
      Width = $bmp.Width
      Height = $bmp.Height
    }
  }
  finally {
    $bmp.Dispose()
  }
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

$edge = $null
if (-not $ValidationOnly) {
  $edge = Resolve-EdgePath
  if (-not $edge) {
    Write-Error "Microsoft Edge (msedge.exe) not found. Please install Edge or ensure msedge.exe exists under Program Files."
    exit 1
  }
}

Write-Output "Input: $InputDir"
Write-Output "Output: $OutputDir"
Write-Output "Target: ${Width}x${Height}"
Write-Output ("Found SVGs: {0}" -f $svgs.Count)

$hasFailure = $false

foreach ($svg in $svgs) {
  $outFile = Join-Path $OutputDir ($svg.BaseName + ".png")

  if (-not $ValidationOnly) {
    $svgUrl = "file:///" + ($svg.FullName -replace '\\','/')
    $wrap = Join-Path $env:TEMP ($svg.BaseName + ".__xhs_wrap__.html")
    $wrapUrl = "file:///" + ($wrap -replace '\\','/')

    @"
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,height=device-height,initial-scale=1,viewport-fit=cover">
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
        left: 0;
        top: 0;
        width: calc(100% + 40px);
        height: calc(100% + 110px);
        display: block;
        object-fit: fill;
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
    }
    finally {
      if (Test-Path $wrap) { Remove-Item -Force $wrap -ErrorAction SilentlyContinue }
    }
  }

  if (!(Test-Path $outFile)) {
    Write-Warning "Missing PNG output: $outFile"
    $hasFailure = $true
    continue
  }

  $result = Validate-Image -Path $outFile -ExpectedWidth $Width -ExpectedHeight $Height -AutoFix:(-not $NoAutoFix)

  Write-Output ("Validated: {0} | size={1}x{2} sizeOk={3} cornersOk={4} bandsOk={5} cornerMaxDistance={6} rightBand={7} bottomBand={8} fixed={9}" -f $result.Path, $result.Width, $result.Height, $result.SizeOk, $result.CornersOk, $result.BandsOk, $result.CornerMaxDistance, $result.RightBand, $result.BottomBand, $result.Fixed)

  if (-not ($result.SizeOk -and $result.CornersOk -and $result.BandsOk)) {
    $hasFailure = $true
  }
}

if ($hasFailure) {
  Write-Error "Validation failed for one or more files."
  exit 2
}

Write-Output "Done. All outputs passed validation."

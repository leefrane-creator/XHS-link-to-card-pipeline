param(
  [string]$InputDir = (Join-Path (Get-Location).Path "output\svg"),
  [string]$OutputDir = (Join-Path (Get-Location).Path "output\png_poster"),
  [switch]$ValidationOnly
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$main = Join-Path $scriptDir "convert_svg_to_png.ps1"

if (!(Test-Path $main)) {
  Write-Error "Missing convert script: $main"
  exit 1
}

$cmd = @{
  InputDir = $InputDir
  OutputDir = $OutputDir
  Width = 1242
  Height = 1660
  Recurse = $true
}

if ($ValidationOnly) {
  $cmd["ValidationOnly"] = $true
}

& $main @cmd
exit $LASTEXITCODE

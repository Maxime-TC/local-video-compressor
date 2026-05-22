<#
.SYNOPSIS
  Bouwt een distributie-ZIP voor Local Video Compressor.
.DESCRIPTION
  Maakt dist\local-video-compressor-v<version>.zip met de bestanden die eindgebruikers nodig hebben.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Version = '0.4.0'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'
$packageRoot = Join-Path $env:TEMP "local-video-compressor-package-$Version"
$zipPath = Join-Path $dist "local-video-compressor-v$Version.zip"

if (Test-Path -LiteralPath $packageRoot) { Remove-Item -LiteralPath $packageRoot -Recurse -Force }
if (-not (Test-Path -LiteralPath $dist)) { New-Item -ItemType Directory -Path $dist -Force | Out-Null }
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

foreach ($item in @('scripts', 'assets', 'bin', 'third_party')) {
    Copy-Item -LiteralPath (Join-Path $root $item) -Destination (Join-Path $packageRoot $item) -Recurse -Force
}
foreach ($file in @('README.md', 'CHANGELOG.md', 'LICENSE', 'Install-ContextMenu.cmd', 'Uninstall-ContextMenu.cmd')) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $packageRoot $file) -Force
}

Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $packageRoot -Recurse -Force

Write-Host "Package created: $zipPath" -ForegroundColor Green

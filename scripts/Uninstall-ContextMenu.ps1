<#
.SYNOPSIS
  Verwijdert Local Video Compressor voor de huidige Windows-gebruiker.
.DESCRIPTION
  Verwijdert alleen de HKCU registry keys van deze tool en de installatiemap onder LocalAppData\Programs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\LocalVideoCompressor')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$extensions = @('.mp4', '.mov', '.mkv', '.avi', '.webm')
$keys = @(
    'LocalVideoCompressor',
    'LocalVideoCompressorBalanced',
    'LocalVideoCompressorSmall',
    'LocalVideoCompressorHighQuality'
)

try {
    foreach ($ext in $extensions) {
        foreach ($key in $keys) {
            $path = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\$key"
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
                Write-Host "Verwijderd: $path"
            }
        }
    }

    if (Test-Path -LiteralPath $InstallDir) {
        $currentRoot = Split-Path -Parent $PSScriptRoot
        $installFull = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
        $currentFull = [IO.Path]::GetFullPath($currentRoot).TrimEnd('\')

        if ($installFull.ToLowerInvariant() -eq $currentFull.ToLowerInvariant()) {
            Write-Host "Installatiemap wordt gebruikt door dit script en blijft staan: $InstallDir" -ForegroundColor Yellow
        } else {
            Remove-Item -LiteralPath $InstallDir -Recurse -Force
            Write-Host "Installatiemap verwijderd: $InstallDir"
        }
    }

    Write-Host ''
    Write-Host 'Local Video Compressor is verwijderd.' -ForegroundColor Green
    Write-Host 'Herstart Windows Verkenner als de menu-items nog zichtbaar zijn.' -ForegroundColor Yellow
}
catch {
    Write-Host "Uninstall mislukt: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

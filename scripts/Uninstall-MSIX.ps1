<#
.SYNOPSIS
  Verwijdert de Windows 11 MSIX shell extension en beta certificaten van Local Video Compressor.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PackageName = 'TaillieuConsultancy.LocalVideoCompressor.Beta',

    [Parameter(Mandatory = $false)]
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\LocalVideoCompressor')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "[local-video-compressor-uninstall] $Message" -ForegroundColor Cyan }

function Remove-CertificateByThumbprint([string]$StoreName, [string]$Thumbprint) {
    if (-not $Thumbprint) { return }
    $normalized = ($Thumbprint -replace '\s', '').ToUpperInvariant()
    $storePath = "Cert:\CurrentUser\$StoreName"
    Get-ChildItem -Path $storePath -ErrorAction SilentlyContinue |
        Where-Object { ($_.Thumbprint -replace '\s', '').ToUpperInvariant() -eq $normalized } |
        ForEach-Object {
            Write-Info "Certificaat verwijderen uit CurrentUser\\$StoreName: $($_.Thumbprint)"
            Remove-Item -LiteralPath $_.PSPath -Force -ErrorAction SilentlyContinue
        }
}

try {
    $statePath = Join-Path $InstallDir 'config\installed-msix.json'
    $thumbprint = $null
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try {
            $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
            $thumbprint = [string]$state.certificateThumbprint
        }
        catch { }
    }

    $packages = @(Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue)
    foreach ($pkg in $packages) {
        Write-Info "MSIX package verwijderen: $($pkg.PackageFullName)"
        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
    }

    if ($thumbprint) {
        foreach ($store in @('Root', 'TrustedPublisher', 'TrustedPeople')) {
            Remove-CertificateByThumbprint -StoreName $store -Thumbprint $thumbprint
        }
    }

    $appData = Join-Path $env:LOCALAPPDATA 'LocalVideoCompressor'
    if (Test-Path -LiteralPath $appData) {
        Write-Info "Settings/logs verwijderen: $appData"
        Remove-Item -LiteralPath $appData -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host 'Windows 11 MSIX shell extension is verwijderd.' -ForegroundColor Green
}
catch {
    Write-Host "MSIX uninstall mislukt: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

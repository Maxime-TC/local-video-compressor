<#
.SYNOPSIS
  Installeert de Windows 11 MSIX shell extension voor Local Video Compressor.
.DESCRIPTION
  Importeert het beta/test certificaat in de CurrentUser stores en installeert het MSIX package.
  Geen adminrechten vereist; bedoeld voor Maxime-controlled beta devices.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MsixPath,

    [Parameter(Mandatory = $true)]
    [string]$CertificatePath,

    [Parameter(Mandatory = $false)]
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\LocalVideoCompressor')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "[local-video-compressor-msix] $Message" -ForegroundColor Cyan }

function Add-CertificateToStore([string]$StoreName, [string]$Path) {
    Write-Info "Certificaat vertrouwen in CurrentUser\\$StoreName"
    $process = Start-Process -FilePath 'certutil.exe' -ArgumentList @('-user', '-addstore', $StoreName, $Path) -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "certutil -addstore $StoreName failed with exit code $($process.ExitCode)" }
}

try {
    $resolvedMsix = (Resolve-Path -LiteralPath $MsixPath).Path
    $resolvedCert = (Resolve-Path -LiteralPath $CertificatePath).Path
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($resolvedCert)

    Write-Info "MSIX: $resolvedMsix"
    Write-Info "Cert: $($cert.Subject) / $($cert.Thumbprint)"

    foreach ($store in @('Root', 'TrustedPublisher', 'TrustedPeople')) {
        Add-CertificateToStore -StoreName $store -Path $resolvedCert
    }

    Write-Info 'MSIX package installeren/updaten'
    Add-AppxPackage -Path $resolvedMsix -ForceUpdateFromAnyVersion -ForceApplicationShutdown

    $stateDir = Join-Path $InstallDir 'config'
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    $state = [ordered]@{
        packageName = 'TaillieuConsultancy.LocalVideoCompressor.Beta'
        certificateThumbprint = $cert.Thumbprint
        certificateSubject = $cert.Subject
        installedAt = (Get-Date).ToString('o')
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateDir 'installed-msix.json') -Encoding UTF8

    Write-Host 'Windows 11 MSIX shell extension is geïnstalleerd.' -ForegroundColor Green
}
catch {
    Write-Host "MSIX installatie mislukt: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

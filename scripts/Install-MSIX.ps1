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

function Add-CertificateToStore([string]$Scope, [string]$StoreName, [string]$Path) {
    Write-Info "Certificaat vertrouwen in $Scope\\$StoreName"
    $args = @('-f', '-addstore', $StoreName, $Path)
    if ($Scope -eq 'CurrentUser') { $args = @('-user') + $args }
    & certutil.exe @args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "certutil $Scope -addstore $StoreName failed with exit code $LASTEXITCODE" }
}

function Assert-AppxSigningCertificate([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate) {
    $basicConstraints = $Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' } | Select-Object -First 1
    if (-not $basicConstraints) {
        throw "Het MSIX signing certificaat is ongeldig: Basic Constraints ontbreekt. Maak een nieuw code-signing certificaat met BasicConstraints CA=false en bouw/sign de MSIX opnieuw. Thumbprint: $($Certificate.Thumbprint)"
    }
}

try {
    $resolvedMsix = (Resolve-Path -LiteralPath $MsixPath).Path
    $resolvedCert = (Resolve-Path -LiteralPath $CertificatePath).Path
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($resolvedCert)
    Assert-AppxSigningCertificate -Certificate $cert

    Write-Info "MSIX: $resolvedMsix"
    Write-Info "Cert: $($cert.Subject) / $($cert.Thumbprint)"

    # AppX deployment validates the package chain with the machine trust provider on
    # recent Windows builds. Use LocalMachine when elevated; otherwise fall back to
    # CurrentUser for non-elevated/manual installs.
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Windows 11 main context-menu installatie vereist administratorrechten om het MSIX beta-certificaat in de LocalMachine trust stores te plaatsen. Start de installer opnieuw en accepteer de UAC prompt.'
    }

    foreach ($store in @('Root', 'TrustedPublisher', 'TrustedPeople')) {
        Add-CertificateToStore -Scope 'LocalMachine' -StoreName $store -Path $resolvedCert
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

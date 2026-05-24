<#
.SYNOPSIS
  Creates a valid local code-signing certificate for Local Video Compressor beta MSIX packages.
.DESCRIPTION
  The Windows AppX/MSIX deployment trust provider rejects self-signed certificates
  that do not contain a Basic Constraints extension. Use this script before
  Package-BetaMsix.ps1 when no proper code-signing cert is available.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Subject = 'CN=Taillieu Consultancy',

    [Parameter(Mandatory = $false)]
    [string]$ExportPath = (Join-Path $PSScriptRoot 'dist\TaillieuConsultancy-LocalVideoCompressor-Beta.cer')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $Subject `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -KeyUsage DigitalSignature `
    -KeySpec Signature `
    -TextExtension @('2.5.29.19={text}CA=false', '2.5.29.37={text}1.3.6.1.5.5.7.3.3') `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -NotAfter (Get-Date).AddYears(2)

$exportDir = Split-Path -Parent $ExportPath
if (-not (Test-Path -LiteralPath $exportDir)) { New-Item -ItemType Directory -Path $exportDir -Force | Out-Null }
Export-Certificate -Cert $cert -FilePath $ExportPath -Force | Out-Null

Write-Host "Created code-signing certificate: $($cert.Thumbprint)" -ForegroundColor Green
Write-Host "Exported public cert: $ExportPath"
Write-Host ''
Write-Host 'Build/sign with:' -ForegroundColor Cyan
Write-Host ".\Package-BetaMsix.ps1 -CertificateThumbprint $($cert.Thumbprint) -SkipVerify"

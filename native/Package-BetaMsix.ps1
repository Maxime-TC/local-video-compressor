<#
.SYNOPSIS
  Builds, signs, and optionally installs the Windows 11 MSIX beta.
.DESCRIPTION
  Stages the packaged shell extension, native host, compressor scripts, assets, and ffmpeg into one MSIX.
  The package is signed with a certificate from the local certificate store. It does not create or trust certificates.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Version = '0.5.10',

    [Parameter(Mandatory = $false)]
    [string]$Configuration = 'Release',

    [Parameter(Mandatory = $false)]
    [string]$Platform = 'x64',

    [Parameter(Mandatory = $false)]
    [string]$CertificateThumbprint = '',

    [Parameter(Mandatory = $false)]
    [string]$CertificateSubject = 'CN=Taillieu Consultancy',

    [Parameter(Mandatory = $false)]
    [string]$PfxPath = '',

    [Parameter(Mandatory = $false)]
    [string]$PfxPassword = '',

    [Parameter(Mandatory = $false)]
    [string]$TimestampUrl = 'http://timestamp.digicert.com',

    [Parameter(Mandatory = $false)]
    [switch]$SkipVerify,

    [Parameter(Mandatory = $false)]
    [switch]$Install,

    [Parameter(Mandatory = $false)]
    [switch]$RestartExplorer
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$nativeRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $nativeRoot
$solution = Join-Path $nativeRoot 'LocalVideoCompressorBeta.sln'
$manifest = Join-Path $nativeRoot 'LocalVideoCompressorShellExtension\packaging\AppxManifest.xml'
$dist = Join-Path $nativeRoot 'dist'
$stage = Join-Path $nativeRoot 'package-loose'
$msix = Join-Path $dist "LocalVideoCompressor-Beta-$Version-signed.msix"

function Write-Step([string]$Message) { Write-Host "[lvc-package] $Message" -ForegroundColor Cyan }

function Find-VsWhere {
    $path = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    throw 'vswhere.exe not found. Install Visual Studio 2022 Build Tools with C++ workload.'
}

function Find-MSBuild {
    $vswhere = Find-VsWhere
    $installPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
    if (-not $installPath) { throw 'No Visual Studio installation with MSBuild found.' }
    $msbuild = Join-Path $installPath 'MSBuild\Current\Bin\MSBuild.exe'
    if (Test-Path -LiteralPath $msbuild -PathType Leaf) { return $msbuild }
    throw "MSBuild not found at $msbuild"
}

function Find-WindowsKitTool([string]$ToolName) {
    $root = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    $matches = Get-ChildItem -LiteralPath $root -Filter $ToolName -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\' } |
        Sort-Object FullName -Descending
    if ($matches) { return $matches[0].FullName }
    throw "$ToolName not found under $root. Install the Windows 10/11 SDK."
}

function Copy-RequiredDirectory([string]$RelativePath) {
    $src = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $src -PathType Container)) { throw "Required directory missing: $src" }
    Copy-Item -LiteralPath $src -Destination (Join-Path $stage $RelativePath) -Recurse -Force
}

function Copy-OptionalFile([string]$RelativePath) {
    $src = Join-Path $repoRoot $RelativePath
    if (Test-Path -LiteralPath $src -PathType Leaf) {
        $dest = Join-Path $stage $RelativePath
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
}

function Resolve-CertificateThumbprint {
    if ($CertificateThumbprint) { return ($CertificateThumbprint -replace '\s', '') }

    $stores = @('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My')
    foreach ($store in $stores) {
        $cert = Get-ChildItem $store -ErrorAction SilentlyContinue |
            Where-Object { $_.Subject -eq $CertificateSubject -and $_.HasPrivateKey } |
            Sort-Object NotAfter -Descending |
            Select-Object -First 1
        if ($cert) { return $cert.Thumbprint }
    }

    throw "No signing certificate with private key found for subject '$CertificateSubject'. Pass -CertificateThumbprint explicitly."
}

Write-Step "Building $Configuration|$Platform"
$msbuild = Find-MSBuild
& $msbuild $solution /m /p:Configuration=$Configuration /p:Platform=$Platform
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed with exit code $LASTEXITCODE" }

$dll = Join-Path $nativeRoot "build\$Configuration\$Platform\LocalVideoCompressorShellExtension.dll"
$hostExe = Join-Path $nativeRoot "build\$Configuration\$Platform\LocalVideoCompressorBetaHost.exe"
foreach ($required in @($dll, $hostExe, $manifest)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required build artifact missing: $required" }
}

Write-Step "Staging MSIX package"
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
if (-not (Test-Path -LiteralPath $dist)) { New-Item -ItemType Directory -Path $dist -Force | Out-Null }
if (Test-Path -LiteralPath $msix) { Remove-Item -LiteralPath $msix -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

Copy-Item -LiteralPath $manifest -Destination (Join-Path $stage 'AppxManifest.xml') -Force
Copy-Item -LiteralPath $dll -Destination (Join-Path $stage 'LocalVideoCompressorShellExtension.dll') -Force
Copy-Item -LiteralPath $hostExe -Destination (Join-Path $stage 'LocalVideoCompressorBetaHost.exe') -Force
Copy-Item -LiteralPath (Join-Path $nativeRoot 'LocalVideoCompressorShellExtension\packaging\Assets') -Destination (Join-Path $stage 'Assets') -Recurse -Force
Copy-Item -Path (Join-Path $repoRoot 'assets\*') -Destination (Join-Path $stage 'Assets') -Force

foreach ($dir in @('scripts', 'bin', 'third_party', 'config')) { Copy-RequiredDirectory $dir }
foreach ($file in @('README.md', 'CHANGELOG.md', 'LICENSE')) { Copy-OptionalFile $file }

Write-Step "Packing MSIX"
$makeappx = Find-WindowsKitTool 'makeappx.exe'
& $makeappx pack /d $stage /p $msix /o
if ($LASTEXITCODE -ne 0) { throw "makeappx failed with exit code $LASTEXITCODE" }

Write-Step "Signing MSIX"
$signtool = Find-WindowsKitTool 'signtool.exe'
if ($PfxPath) {
    if (-not (Test-Path -LiteralPath $PfxPath -PathType Leaf)) { throw "PFX not found: $PfxPath" }
    $signArgs = @('sign', '/fd', 'SHA256', '/f', $PfxPath)
    if ($PfxPassword) { $signArgs += @('/p', $PfxPassword) }
}
else {
    $thumbprint = Resolve-CertificateThumbprint
    $signArgs = @('sign', '/fd', 'SHA256', '/sha1', $thumbprint)
}
if ($TimestampUrl) { $signArgs += @('/tr', $TimestampUrl, '/td', 'SHA256') }
$signArgs += $msix
& $signtool @signArgs
if ($LASTEXITCODE -ne 0 -and $TimestampUrl) {
    Write-Host '[lvc-package] Timestamped signing failed; retrying without timestamp for local/test cert.' -ForegroundColor Yellow
    if ($PfxPath) {
        $retryArgs = @('sign', '/fd', 'SHA256', '/f', $PfxPath)
        if ($PfxPassword) { $retryArgs += @('/p', $PfxPassword) }
        $retryArgs += $msix
        & $signtool @retryArgs
    }
    else {
        & $signtool sign /fd SHA256 /sha1 $thumbprint $msix
    }
}
if ($LASTEXITCODE -ne 0) { throw "signtool failed with exit code $LASTEXITCODE" }

if ($SkipVerify) {
    Write-Step "Skipping signature verification"
}
else {
    Write-Step "Verifying signature"
    & $signtool verify /pa /v $msix
    if ($LASTEXITCODE -ne 0) { throw "signature verification failed with exit code $LASTEXITCODE" }
}

if ($Install -and $RestartExplorer) {
    Write-Step "Stopping Explorer before package update"
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 750
}

if ($Install) {
    Write-Step "Installing LocalAppData compressor backend"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\Install-ContextMenu.ps1')
    if ($LASTEXITCODE -ne 0) { throw "backend installer failed with exit code $LASTEXITCODE" }

    Write-Step "Installing MSIX"
    Add-AppxPackage -Path $msix -ForceUpdateFromAnyVersion
}

if ($RestartExplorer) {
    Write-Step "Starting Explorer"
    Start-Process explorer.exe
}

Write-Host "Created: $msix" -ForegroundColor Green

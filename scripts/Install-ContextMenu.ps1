<#
.SYNOPSIS
  Installeert Local Video Compressor voor de huidige Windows-gebruiker.
.DESCRIPTION
  Kopieert de applicatie naar LocalAppData\Programs en registreert Windows Verkenner context-menu items onder HKCU.
  Geen adminrechten, geen services, geen autostart, geen netwerktoegang.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\LocalVideoCompressor'),

    [Parameter(Mandatory = $false)]
    [switch]$SkipClassicContextMenu
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$AppVersion = '0.5.10-beta'
$extensions = @('.mp4', '.mov', '.mkv', '.avi', '.webm')
$sourceRoot = Split-Path -Parent $PSScriptRoot

$menuItems = @(
    @{ Key = 'Balanced';    Label = 'Balanced';     Preset = 'Balanced'    },
    @{ Key = 'Small';       Label = 'Small';        Preset = 'Small'       },
    @{ Key = 'HighQuality'; Label = 'High Quality'; Preset = 'HighQuality' }
)

function Write-Info($Message) { Write-Host "[local-video-compressor] $Message" -ForegroundColor Cyan }
function Set-DefaultValue([string]$RegistryPath, [string]$Value) {
    New-Item -Path $RegistryPath -Force | Out-Null
    Set-Item -Path $RegistryPath -Value $Value
}

function Assert-SourceLayout([string]$Root) {
    foreach ($required in @(
        'scripts\Compress-Video.ps1',
        'scripts\Uninstall-ContextMenu.ps1',
        'assets\local-video-compressor.ico',
        'bin\ffmpeg.exe',
        'README.md'
    )) {
        $path = Join-Path $Root $required
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Installatiebestand ontbreekt: $path"
        }
    }
}

function Copy-AppFiles([string]$Source, [string]$Destination) {
    $sourceFull = [IO.Path]::GetFullPath($Source).TrimEnd('\')
    $destFull = [IO.Path]::GetFullPath($Destination).TrimEnd('\')

    if ($sourceFull.ToLowerInvariant() -eq $destFull.ToLowerInvariant()) {
        Write-Info "App staat al in installatiemap: $Destination"
        return
    }

    if (Test-Path -LiteralPath $Destination) {
        Write-Info "Bestaande installatiemap vervangen: $Destination"
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    foreach ($item in @('scripts', 'assets', 'bin', 'third_party', 'config', 'native')) {
        $src = Join-Path $Source $item
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $Destination $item) -Recurse -Force
        }
    }

    foreach ($file in @('README.md', 'Install-ContextMenu.cmd', 'Uninstall-ContextMenu.cmd', 'LICENSE', 'CHANGELOG.md')) {
        $src = Join-Path $Source $file
        if (Test-Path -LiteralPath $src -PathType Leaf) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $Destination $file) -Force
        }
    }
}

function Register-ContextMenu([string]$Root) {
    $scriptPath = Join-Path $Root 'scripts\Compress-Video.ps1'
    $iconPath = Join-Path $Root 'assets\local-video-compressor.ico'

    foreach ($ext in $extensions) {
        # Remove old v1/v2/v3 flat entries if present.
        foreach ($oldKey in @('LocalVideoCompressorBalanced', 'LocalVideoCompressorSmall', 'LocalVideoCompressorHighQuality')) {
            $oldPath = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\$oldKey"
            if (Test-Path -LiteralPath $oldPath) { Remove-Item -LiteralPath $oldPath -Recurse -Force }
        }

        $parentKey = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\LocalVideoCompressor"
        $parentShellKey = Join-Path $parentKey 'shell'

        New-Item -Path $parentKey -Force | Out-Null
        Set-ItemProperty -Path $parentKey -Name 'MUIVerb' -Value 'Local Video Compressor'
        Set-ItemProperty -Path $parentKey -Name 'Icon' -Value $iconPath
        Set-ItemProperty -Path $parentKey -Name 'Position' -Value 'Top'
        Set-ItemProperty -Path $parentKey -Name 'SubCommands' -Value ''
        New-Item -Path $parentShellKey -Force | Out-Null

        foreach ($item in $menuItems) {
            $itemKey = Join-Path $parentShellKey $item.Key
            $commandKey = Join-Path $itemKey 'command'

            New-Item -Path $itemKey -Force | Out-Null
            Set-ItemProperty -Path $itemKey -Name 'MUIVerb' -Value $item.Label
            Set-ItemProperty -Path $itemKey -Name 'Icon' -Value $iconPath

            $command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Path "%1" -Preset {1}' -f $scriptPath, $item.Preset
            Set-DefaultValue -RegistryPath $commandKey -Value $command
        }
    }
}

try {
    Assert-SourceLayout $sourceRoot
    Write-Info "Installatie Local Video Compressor v$AppVersion"
    Write-Info "Bron: $sourceRoot"
    Write-Info "Doel: $InstallDir"

    Copy-AppFiles -Source $sourceRoot -Destination $InstallDir
    if ($SkipClassicContextMenu) {
        Write-Info 'Classic HKCU context-menu registratie overgeslagen; MSIX shell extension verzorgt het Windows 11 hoofdmenu.'
    }
    else {
        Register-ContextMenu -Root $InstallDir
    }

    Write-Host ''
    Write-Host 'Local Video Compressor is geïnstalleerd.' -ForegroundColor Green
    Write-Host "Installatiemap: $InstallDir"
    if (-not $SkipClassicContextMenu) { Write-Host ('Classic context-menu voor: ' + ($extensions -join ', ')) }
    Write-Host ''
    Write-Host 'Gebruik: rechtsklik video > Local Video Compressor > Balanced / Small / High Quality'
    Write-Host 'Herstart Windows Verkenner als je het menu niet meteen ziet.' -ForegroundColor Yellow
}
catch {
    Write-Host "Installatie mislukt: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

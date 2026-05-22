<#
.SYNOPSIS
  Local, privacy-friendly video compressor using ffmpeg.
.DESCRIPTION
  Compresses a selected video to an MP4 next to the original file. The original file is never changed.
  The script starts one ffmpeg child process, waits for it, then exits. No background service is left running.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Balanced', 'Small', 'HighQuality')]
    [string]$Preset = 'Balanced',

    [Parameter(Mandatory = $false)]
    [switch]$PauseOnExit
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$AppVersion = '0.5.9-beta'
$SupportedExtensions = @('.mp4', '.mov', '.mkv', '.avi', '.webm')
$TempOutputPath = $null
$FinalOutputPath = $null

function Write-Info($Message) { Write-Host "[local-video-compressor] $Message" -ForegroundColor Cyan }
function Write-Warn($Message) { Write-Host "[waarschuwing] $Message" -ForegroundColor Yellow }
function Write-Fail($Message) { Write-Host "[fout] $Message" -ForegroundColor Red }

function Resolve-AppRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-Ffmpeg {
    $appRoot = Resolve-AppRoot
    $localFfmpeg = Join-Path $appRoot 'bin\ffmpeg.exe'
    if (Test-Path -LiteralPath $localFfmpeg -PathType Leaf) { return $localFfmpeg }

    $cmd = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    throw "ffmpeg niet gevonden. Installeer opnieuw of zet ffmpeg.exe in '$appRoot\bin'."
}

function Get-SafeThreadCount {
    $logical = [Environment]::ProcessorCount
    if ($logical -le 2) { return 1 }
    return [Math]::Max(1, [Math]::Min(4, [Math]::Floor($logical / 2)))
}

function Get-AvailableEncoders([string]$Ffmpeg) {
    try {
        $output = & $Ffmpeg -hide_banner -encoders 2>&1 | Out-String
        return $output
    } catch {
        return ''
    }
}

function Select-HardwareEncoder([string]$Encoders) {
    # Conservative hardware preference. If it fails, the script removes partial output and falls back to CPU x264.
    if ($Encoders -match 'h264_nvenc') { return 'h264_nvenc' }
    if ($Encoders -match 'h264_qsv')   { return 'h264_qsv' }
    if ($Encoders -match 'h264_amf')   { return 'h264_amf' }
    return $null
}

function Assert-SupportedInput([string]$InputPath) {
    $ext = [IO.Path]::GetExtension($InputPath).ToLowerInvariant()
    if ($SupportedExtensions -notcontains $ext) {
        throw "Niet-ondersteunde extensie '$ext'. Ondersteund: $($SupportedExtensions -join ', ')"
    }
}

function New-OutputPath([string]$InputPath) {
    $directory = Split-Path -Parent $InputPath
    $baseName = [IO.Path]::GetFileNameWithoutExtension($InputPath)
    $preferred = Join-Path $directory ($baseName + '_compressed.mp4')
    if (-not (Test-Path -LiteralPath $preferred)) { return $preferred }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    return (Join-Path $directory ($baseName + "_compressed_$stamp.mp4"))
}

function New-TempOutputPath([string]$FinalPath) {
    $directory = Split-Path -Parent $FinalPath
    $name = [IO.Path]::GetFileNameWithoutExtension($FinalPath)
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    return (Join-Path $directory (".$name.tmp.$PID.$stamp.mp4"))
}

function Get-PresetSettings([string]$PresetName) {
    switch ($PresetName) {
        'Small' {
            # ffmpeg filter expressions use comma as a filter separator, so the comma inside min() must be escaped.
            return @{ Crf = '28'; Audio = '96k';  Scale = 'scale=-2:min(720\,ih)';  HwQuality = '29' }
        }
        'HighQuality' {
            return @{ Crf = '20'; Audio = '160k'; Scale = $null;                  HwQuality = '21' }
        }
        default {
            # Downscale only when taller than 1080p; keep smaller videos at original height.
            return @{ Crf = '23'; Audio = '128k'; Scale = 'scale=-2:min(1080\,ih)'; HwQuality = '24' }
        }
    }
}

function Quote-Arg([string]$Arg) {
    if ($null -eq $Arg) { return '""' }
    return '"' + ($Arg -replace '"', '\"') + '"'
}

function Invoke-FfmpegFriendly {
    param(
        [string]$Ffmpeg,
        [string[]]$Arguments,
        [string]$ModeName
    )

    Write-Info "Start compressie ($ModeName)."
    Write-Info "Procesprioriteit: BelowNormal. Dit houdt Windows bruikbaar tijdens het comprimeren."

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Ffmpeg
    $psi.UseShellExecute = $false
    # Use Arguments string instead of ProcessStartInfo.ArgumentList for Windows PowerShell 5.1 compatibility.
    $psi.Arguments = ($Arguments | ForEach-Object { Quote-Arg $_ }) -join ' '

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    try {
        [void]$process.Start()
        try { $process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal } catch { Write-Warn "Kon procesprioriteit niet aanpassen: $($_.Exception.Message)" }
        $process.WaitForExit()
        return $process.ExitCode
    }
    finally {
        if ($process) { $process.Dispose() }
    }
}

try {
    $inputPath = (Resolve-Path -LiteralPath $Path).Path
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { throw "Bestand bestaat niet: $Path" }
    Assert-SupportedInput $inputPath

    $ffmpeg = Resolve-Ffmpeg
    $threads = Get-SafeThreadCount
    $settings = Get-PresetSettings $Preset
    $FinalOutputPath = New-OutputPath $inputPath
    $TempOutputPath = New-TempOutputPath $FinalOutputPath

    Write-Info "Local Video Compressor v$AppVersion"
    Write-Info "Input:  $inputPath"
    Write-Info "Output: $FinalOutputPath"
    Write-Info "Preset: $Preset"
    Write-Info "ffmpeg: $ffmpeg"
    Write-Info "CPU thread-limiet bij fallback: $threads"

    # Keep the first video stream and optional audio streams. Subtitles/attachments are skipped for reliability.
    $common = @('-hide_banner', '-stats', '-y', '-i', $inputPath, '-map', '0:v:0', '-map', '0:a?')
    if ($settings.Scale) { $common += @('-vf', $settings.Scale) }

    $encoders = Get-AvailableEncoders $ffmpeg
    $hwEncoder = Select-HardwareEncoder $encoders
    $exitCode = 1

    if ($hwEncoder) {
        Write-Info "Hardware encoder gevonden: $hwEncoder. Eerst veilige hardware-compressie proberen."
        $hwArgs = @($common + @('-c:v', $hwEncoder, '-cq', $settings.HwQuality, '-b:v', '0', '-c:a', 'aac', '-b:a', $settings.Audio, '-movflags', '+faststart', $TempOutputPath))
        $exitCode = Invoke-FfmpegFriendly -Ffmpeg $ffmpeg -Arguments $hwArgs -ModeName $hwEncoder
        if ($exitCode -ne 0) {
            Write-Warn "Hardware-compressie faalde met exitcode $exitCode. Tijdelijke output wordt verwijderd; CPU fallback volgt."
            if (Test-Path -LiteralPath $TempOutputPath) { Remove-Item -LiteralPath $TempOutputPath -Force }
        }
    } else {
        Write-Info "Geen ondersteunde hardware encoder gevonden. CPU fallback wordt gebruikt."
    }

    if ($exitCode -ne 0) {
        $cpuArgs = @($common + @('-c:v', 'libx264', '-preset', 'veryfast', '-crf', $settings.Crf, '-threads', [string]$threads, '-c:a', 'aac', '-b:a', $settings.Audio, '-movflags', '+faststart', $TempOutputPath))
        $exitCode = Invoke-FfmpegFriendly -Ffmpeg $ffmpeg -Arguments $cpuArgs -ModeName 'CPU libx264'
    }

    if ($exitCode -ne 0) { throw "ffmpeg stopte met exitcode $exitCode." }
    if (-not (Test-Path -LiteralPath $TempOutputPath -PathType Leaf)) { throw "Geen outputbestand gevonden na compressie." }

    $tempItem = Get-Item -LiteralPath $TempOutputPath
    if ($tempItem.Length -le 0) { throw "Outputbestand is leeg; tijdelijke output wordt verwijderd." }

    Move-Item -LiteralPath $TempOutputPath -Destination $FinalOutputPath -Force
    $TempOutputPath = $null

    $inSize = (Get-Item -LiteralPath $inputPath).Length
    $outSize = (Get-Item -LiteralPath $FinalOutputPath).Length
    $ratio = if ($inSize -gt 0) { [Math]::Round((1 - ($outSize / $inSize)) * 100, 1) } else { 0 }

    Write-Host ''
    Write-Host 'Klaar.' -ForegroundColor Green
    Write-Host "Origineel:   $([Math]::Round($inSize / 1MB, 2)) MB"
    Write-Host "Compressed: $([Math]::Round($outSize / 1MB, 2)) MB"
    Write-Host "Besparing:   $ratio%"
    Write-Host "Bestand:     $FinalOutputPath"
}
catch {
    if ($TempOutputPath -and (Test-Path -LiteralPath $TempOutputPath)) {
        try { Remove-Item -LiteralPath $TempOutputPath -Force } catch { }
    }
    Write-Fail $_.Exception.Message
    exit 1
}
finally {
    if ($PauseOnExit) {
        Write-Host ''
        Read-Host 'Druk op Enter om dit venster te sluiten'
    }
}

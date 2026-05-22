# Local Video Compressor Shell Extension Beta

Experimental Windows 11 primary context-menu integration.

This is intentionally separate from stable `v0.4.0`. The stable installer remains the supported fallback.

## What this does

- Implements an `IExplorerCommand` COM DLL.
- Exposes one root command: **Local Video Compressor**.
- Exposes three subcommands: **Balanced**, **Small**, **High Quality**.
- Validates exactly one selected video file.
- Launches the packaged native host, which runs compression outside Explorer.
- Returns immediately to Explorer.

## What this must not do

- Do not run `ffmpeg` inside Explorer.
- Do not block Explorer on compression.
- Do not keep state in Explorer.
- Do not write persistent logs from the shell extension unless explicitly enabled in `%LOCALAPPDATA%\LocalVideoCompressor\settings.json`.
- Do not register with `regsvr32` as the final beta path.

## Build target

- Visual Studio 2022
- Windows SDK 10
- x64 Release
- C++17

Open:

```text
native\LocalVideoCompressorBeta.sln
```

Build:

```text
Release | x64
```

Expected outputs:

```text
native\build\Release\x64\LocalVideoCompressorShellExtension.dll
native\build\Release\x64\LocalVideoCompressorBetaHost.exe
```

## Packaging target

The draft manifest is here:

```text
packaging\AppxManifest.xml
```

The manifest uses:

- `windows.comServer` for the COM DLL
- `windows.fileExplorerContextMenus` wildcard registration; `GetState` hides unsupported files and enables `.mp4`, `.mov`, `.mkv`, `.avi`, `.webm`
- CLSID `8AC3CC15-339A-4202-9E1E-56F80717AC92`

The package must be signed. For test installs, use a local trusted test certificate. For real multi-device install, use a proper code-signing certificate.

## Install flow

1. Build/sign/install the beta package:

```powershell
.\native\Package-BetaMsix.ps1 -Install -RestartExplorer
```

2. Right-click a supported video file.
3. Confirm the command appears in the primary Windows 11 context menu.
4. Confirm compression starts without a random command terminal in normal mode.

## Risk note

Explorer loads this DLL. A bug here can destabilize Explorer, so we keep the DLL as small as possible and only use it as a launcher.

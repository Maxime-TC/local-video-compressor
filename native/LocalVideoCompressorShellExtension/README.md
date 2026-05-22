# Local Video Compressor Shell Extension Beta

Experimental Windows 11 primary context-menu integration.

This is intentionally separate from stable `v0.4.0`. The stable installer remains the supported fallback.

## What this does

- Implements an `IExplorerCommand` COM DLL.
- Exposes one root command: **Local Video Compressor**.
- Exposes three subcommands: **Balanced**, **Small**, **High Quality**.
- Validates exactly one selected video file.
- Spawns the stable installed PowerShell compressor script in a new console.
- Returns immediately to Explorer.

## What this must not do

- Do not run `ffmpeg` inside Explorer.
- Do not block Explorer on compression.
- Do not keep state in Explorer.
- Do not write persistent logs from the shell extension.
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
- `windows.fileExplorerContextMenus` for `.mp4`, `.mov`, `.mkv`, `.avi`, `.webm`
- CLSID `8AC3CC15-339A-4202-9E1E-56F80717AC92`

The package must be signed. For test installs, use a local trusted test certificate. For real multi-device install, use a proper code-signing certificate.

## Install flow we still need to validate on Windows

1. Install stable `v0.4.0` first so this path exists:

```text
%LOCALAPPDATA%\Programs\LocalVideoCompressor\scripts\Compress-Video.ps1
```

2. Build the native beta solution.
3. Package/sign the manifest + DLL + host EXE + assets.
4. Install the package.
5. Restart Explorer.
6. Right-click a supported video file.
7. Confirm the command appears in the primary Windows 11 context menu.

## Risk note

Explorer loads this DLL. A bug here can destabilize Explorer, so we keep the DLL as small as possible and only use it as a launcher.

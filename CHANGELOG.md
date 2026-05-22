# Changelog

## 0.4.0 - 2026-05-22

Production-ready MVP hardening:

- Installer now copies the app to `%LOCALAPPDATA%\Programs\LocalVideoCompressor` instead of registering the unpacked Downloads folder.
- Context-menu commands point to the installed app path.
- Added app icon for the context-menu.
- Compression now writes to a temporary output file first, then moves it to the final `_compressed.mp4` only after success.
- Partial/failed outputs are removed automatically.
- `ffmpeg` process object is disposed after exit.
- Added input extension validation.
- Added version output.
- README expanded with safety/resource/install notes.

## 0.3.0 - 2026-05-22

- Bundled `ffmpeg.exe`.
- Reworked context-menu into one cascading `Local Video Compressor` submenu.
- Added `Balanced`, `Small`, and `High Quality` presets.

## 0.2.0 - 2026-05-22

- Added `.cmd` launchers to avoid changing global PowerShell execution policy.

## 0.1.0 - 2026-05-22

- Initial script MVP.

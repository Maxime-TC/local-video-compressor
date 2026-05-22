# Windows 11 main context-menu beta

Stable `v0.4.0` stays finished and registry-based. This beta branch explores a native Windows 11 Explorer integration so **Local Video Compressor** can appear in the primary Windows 11 context menu instead of only under **Show more options**.

## Why the stable installer cannot do this

Windows 11 does not promote classic registry context-menu entries into the new primary context menu. The stable app registers safe per-user HKCU entries, which is why Windows normally shows it in the legacy menu.

For the primary Windows 11 context menu, Microsoft’s modern path is:

1. implement a COM Shell extension using `IExplorerCommand`;
2. register it through an MSIX/sparse package manifest with `windows.fileExplorerContextMenus`;
3. expose the COM class through package COM registration (`windows.comServer`);
4. sign/install the package;
5. restart Explorer after installation.

Reference docs:

- Microsoft: Integrate a packaged desktop app with File Explorer
- Microsoft: `desktop4:FileExplorerContextMenus`
- Microsoft: `desktop5:ItemType`
- Microsoft: `desktop4:Verb`

## Safety design

Explorer will load the beta extension, so the extension must stay tiny:

- no ffmpeg work inside Explorer;
- no long-running code inside Explorer;
- no PowerShell work inside Explorer; Explorer only launches the tiny packaged host EXE;
- no background service;
- no network;
- no persistent file logging unless explicitly enabled via `%LOCALAPPDATA%\LocalVideoCompressor\settings.json`;
- no global hooks;
- no manual `regsvr32` path for the beta target.

The native extension should only:

1. display `Local Video Compressor`;
2. show subcommands: `Balanced`, `Small`, `High Quality`;
3. validate that exactly one supported video file is selected;
4. launch the packaged native host, which runs the LocalAppData compressor backend outside Explorer;
5. return quickly to Explorer.

## Beta scaffold in this branch

Path:

```text
native/LocalVideoCompressorShellExtension/
```

Contents:

- C++ COM DLL scaffold implementing `IExplorerCommand` and `IEnumExplorerCommand`.
- Root command with subcommands for the three presets.
- Manifest draft for packaged COM + `windows.fileExplorerContextMenus`.
- Visual Studio project file targeting Windows SDK / C++17.
- `native/Package-BetaMsix.ps1` helper to build, sign, install, and optionally restart Explorer.

## Beta acceptance checklist

This beta should not replace stable until all are true on a Windows 11 test machine:

- [ ] Builds in Visual Studio 2022 x64 Release.
- [ ] Package manifest validates.
- [ ] Package installs without admin using a trusted test certificate or proper signing.
- [ ] Explorer restart loads the extension.
- [ ] Menu appears in the primary Windows 11 context menu for `.mp4`, `.mov`, `.mkv`, `.avi`, `.webm`.
- [ ] Commands launch compression using the packaged native host + LocalAppData compressor backend.
- [ ] Normal mode does not leave random command terminals open.
- [ ] Explorer remains stable after repeated open/close/right-click cycles.
- [ ] No persistent process remains after compression finishes.
- [ ] Uninstall removes package and context-menu entries.
- [ ] Stable v0.4.0 classic context-menu installer still works as fallback.

## Open questions

- Whether Windows 11 reliably renders `EnumSubCommands` as a submenu in the primary menu or whether we should register three top-level verbs instead.
- Whether this full MSIX layout is enough for all Maxime devices, or whether we should add an `.appinstaller` update flow.
- Whether we need a real code-signing certificate before this feels acceptable across all Maxime devices.

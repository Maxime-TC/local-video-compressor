# Local Video Compressor

Windows context-menu tool om screenrecordings en andere video's lokaal kleiner te maken met `ffmpeg`.

> Stable line: `v0.4.0` remains the registry-based fallback. This beta branch adds a packaged native Windows 11 shell extension under `native/` for primary context-menu integration.

Doel: rechtsklik in Windows Verkenner op een video → kies een compressiepreset → er verschijnt een nieuw `.mp4` bestand naast het origineel. Geen cloud, geen upload, geen achtergrondservice.

## Status

Production-ready MVP voor persoonlijk/teamgebruik:

- installeert per gebruiker onder `%LOCALAPPDATA%\Programs\LocalVideoCompressor`
- schrijft alleen HKCU registry keys, dus geen adminrechten nodig
- gebruikt gebundelde `ffmpeg.exe`
- draait alleen tijdens compressie; geen resident process, service, scheduled task of autostart
- schrijft eerst naar tijdelijke output en verplaatst pas na succesvolle compressie
- ruimt gedeeltelijke output op bij fouten
- valt terug van hardware encoding naar CPU encoding als de GPU encoder faalt
- Windows 11 beta draait standaard stil zonder willekeurige command windows; debug logging/console kan expliciet via settings

## Installatie

1. Download en unzip de release.
2. Dubbelklik:

```text
Install-ContextMenu.cmd
```

De installer kopieert de app naar:

```text
%LOCALAPPDATA%\Programs\LocalVideoCompressor
```

en registreert het context-menu voor:

- `.mp4`
- `.mov`
- `.mkv`
- `.avi`
- `.webm`

Als het menu niet meteen zichtbaar is: herstart Windows Verkenner of meld opnieuw aan.

## Gebruik

1. Rechtsklik in Windows Verkenner op een video.
2. Kies **Local Video Compressor**.
3. Kies één preset:
   - **Balanced** — goede standaardkeuze, max. 1080p.
   - **Small** — kleiner bestand, meer kwaliteitsverlies, max. 720p.
   - **High Quality** — betere kwaliteit, originele resolutie.
4. De Windows 11 beta start de compressie stil op de achtergrond. De klassieke registry-fallback opent geen permanent venster.
5. Output verschijnt naast het origineel als `naam_compressed.mp4`.

Als `naam_compressed.mp4` al bestaat, gebruikt de tool automatisch een timestamp.

## Presets

| Preset | Video | Resolutie | Audio | Doel |
|---|---:|---:|---:|---|
| Balanced | CRF 23 / HW CQ 24 | max. 1080p | 128k AAC | Standaard voor screenrecordings |
| Small | CRF 28 / HW CQ 29 | max. 720p | 96k AAC | Klein bestand |
| High Quality | CRF 20 / HW CQ 21 | origineel | 160k AAC | Betere kwaliteit |

## Privacy en veiligheid

- Alles draait lokaal.
- Geen netwerkverkeer door de app zelf.
- Geen externe API.
- Originele video wordt nooit gewijzigd.
- Geen adminrechten nodig.
- Geen achtergrondservice of autostart.
- Geen permanente logbestanden met bestandsnamen/paden, tenzij debug logging expliciet aangezet is.

## Debug settings

Standaard schrijft de app geen logs en opent ze geen command window. Voor debugging kun je deze file aanmaken:

```text
%LOCALAPPDATA%\LocalVideoCompressor\settings.json
```

Voorbeeld:

```json
{
  "debug": true,
  "writeLog": true,
  "showConsole": false,
  "pauseOnExit": false,
  "showSuccessMessage": false,
  "showErrorMessage": true,
  "shellExtensionLogging": false
}
```

- `writeLog`: schrijft compressielogs naar `%LOCALAPPDATA%\LocalVideoCompressor\logs`.
- `showConsole`: opent bewust een consolevenster voor live debugging.
- `pauseOnExit`: houdt dat consolevenster open na afloop; alleen nuttig samen met `showConsole`.
- `shellExtensionLogging`: logt Explorer shell-extension callbacks. Alleen gebruiken bij context-menu bugs.

## Resourcegedrag

- Het `ffmpeg` proces draait met `BelowNormal` priority waar Windows dat toelaat.
- CPU fallback gebruikt maximaal de helft van de logische cores, met een harde limiet van 4 threads.
- Hardware encoding wordt geprobeerd voor:
  - NVIDIA: `h264_nvenc`
  - Intel Quick Sync: `h264_qsv`
  - AMD: `h264_amf`
- Als hardware encoding faalt, wordt tijdelijke output verwijderd en volgt CPU fallback met `libx264`.

## Handmatig gebruiken zonder context-menu

Vanuit de installatiemap:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Compress-Video.ps1 -Path "C:\pad\naar\video.mp4" -Preset Balanced -PauseOnExit
```

Andere presets:

```powershell
-Preset Small
-Preset HighQuality
```

## Uninstall

Dubbelklik:

```text
Uninstall-ContextMenu.cmd
```

Dit verwijdert:

- registry keys onder `HKCU\Software\Classes\SystemFileAssociations\...\shell\LocalVideoCompressor`
- installatiemap `%LOCALAPPDATA%\Programs\LocalVideoCompressor`

## Windows 11 context-menu

De klassieke installer gebruikt veilige HKCU registry entries. Daardoor komt hij op Windows 11 meestal onder **Show more options** / **Meer opties weergeven** terecht.

De beta branch bevat nu ook een native/packaged shell extension (`IExplorerCommand`/MSIX/COM) onder `native/`, zodat **Local Video Compressor** in het primaire Windows 11 context-menu kan verschijnen. Build/install helper:

```powershell
.\native\Package-BetaMsix.ps1 -Install -RestartExplorer
```

Normale beta-modus opent geen willekeurige command terminal. Debug console/logging kan via de settings JSON hierboven.

## ffmpeg

Deze release bevat `bin\ffmpeg.exe`.

Meegeleverde build:

- ffmpeg essentials Windows build van Gyan.dev
- licentie/README: `third_party\ffmpeg\`

Het script zoekt eerst naar de gebundelde `bin\ffmpeg.exe`, daarna naar `ffmpeg` in PATH.

## Troubleshooting

### `ffmpeg niet gevonden`

Installeer opnieuw of controleer of dit bestand bestaat:

```text
%LOCALAPPDATA%\Programs\LocalVideoCompressor\bin\ffmpeg.exe
```

### Menu-item verschijnt niet

- Run `Install-ContextMenu.cmd` opnieuw.
- Herstart Windows Verkenner via Taakbeheer.
- Controleer of je op een ondersteunde extensie rechtsklikt.

### Foutmelding: `No such filter: 'ih)'`

Gebruik versie `0.4.0` of nieuwer. Dit was een bug in de scale-filter escaping van een vroege MVP-versie.

### Output is niet kleiner

Dat kan bij al sterk gecomprimeerde video's. Probeer **Small** voor een agressievere preset.

### Pc voelt traag

Video-encoding blijft zwaar. De tool probeert vriendelijk te zijn via BelowNormal priority en CPU-threadlimieten, maar sluit zware apps of gebruik **Balanced**/**Small** op een rustiger moment als nodig.

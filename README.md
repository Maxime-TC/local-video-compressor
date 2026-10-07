# Local Video Compressor

Windows context-menu tool om screenrecordings en andere video's lokaal kleiner te maken met `ffmpeg`.

> **Experimenteel / op eigen risico.** Dit project is grotendeels met AI-assistentie ("vibe coded") gebouwd en is niet onafhankelijk op veiligheid of betrouwbaarheid geaudit. Controleer de code en maak een back-up van belangrijke video's voordat je het gebruikt. Er is geen garantie of officiële ondersteuning; zie de [MIT-licentie](LICENSE). Bugs, verbeteringen en pull requests zijn welkom — zie [Bijdragen](#bijdragen). Meld kwetsbaarheden via [SECURITY.md](SECURITY.md), niet in een publiek issue.

De klassieke `v0.4.0`-lijn gebruikt registry-integratie. De `v0.5.x`-beta voegt een native Windows 11 shell extension toe onder `native/`.

Doel: rechtsklik in Windows Verkenner op een video → kies een compressiepreset → er verschijnt een nieuw `.mp4` bestand naast het origineel. Geen cloud, geen upload, geen achtergrondservice.

## Status

Experimentele MVP, vooral getest op eigen toestellen:

- de klassieke installatie draait per gebruiker onder `%LOCALAPPDATA%\Programs\LocalVideoCompressor` en gebruikt HKCU registry keys
- gebruikt gebundelde `ffmpeg.exe`
- draait alleen tijdens compressie; geen resident process, service, scheduled task of autostart
- schrijft eerst naar tijdelijke output en verplaatst pas na succesvolle compressie
- ruimt gedeeltelijke output op bij fouten
- valt terug van hardware encoding naar CPU encoding als de GPU encoder faalt
- Windows 11 beta draait standaard stil zonder willekeurige command windows; debug logging/console kan expliciet via settings

## Installatie

### Windows 11 beta — alleen voor testtoestellen

Download en start:

```text
LocalVideoCompressor-0.5.10-beta-Win11-Setup.exe
```

Deze installer wizard is experimenteel en **niet aanbevolen voor publieke installatie**. Hij:

- installeert de backend onder `%LOCALAPPDATA%\Programs\LocalVideoCompressor`
- installeert de MSIX shell extension voor het primaire Windows 11 context-menu
- installeert een meegeleverd zelfondertekend beta/testcertificaat in de Windows-certificaatopslag; hiervoor kan administrator-/UAC-toestemming nodig zijn
- kan Windows Verkenner automatisch herstarten
- voorziet een gewone uninstall wizard via Windows **Apps & features**

> Installeer dit beta-certificaat niet op een toestel dat je niet zelf beheert. Het vertrouwen van een zelfondertekend certificaat verandert de trust-instellingen van Windows. Voor brede distributie is een passend ondertekende release nodig.

### Classic fallback — voor wie de tool wil proberen

Download en unzip de release, of kies de classic fallback in de installer. Dubbelklik:

```text
Install-ContextMenu.cmd
```

De classic installer kopieert de app naar:

```text
%LOCALAPPDATA%\Programs\LocalVideoCompressor
```

en registreert het context-menu voor:

- `.mp4`
- `.mov`
- `.mkv`
- `.avi`
- `.webm`

Op Windows 11 verschijnt deze classic fallback meestal onder **Show more options**. Deze route heeft geen MSIX-testcertificaat nodig. Download alleen van de officiële GitHub Releases-pagina en controleer wat je installeert.

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
- De klassieke fallback heeft geen adminrechten nodig; de Windows 11 beta-installer kan UAC vereisen.
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

Voor de Win11 setup wizard: ga naar Windows **Settings → Apps → Installed apps → Local Video Compressor → Uninstall**. De uninstall wizard verwijdert de MSIX package, context-menu registratie, backend files en beta-certificaat voor deze app.

Voor de classic fallback kun je ook dubbelklikken:

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

## Bijdragen

Verbeteringen, bugreports en pull requests zijn welkom. Beschrijf bij een issue hoe je het probleem reproduceert; vermeld Windows-versie, installatieroute en relevante preset. Deel geen privévideo's, bestandspaden of logs met gevoelige gegevens. Voor codewijzigingen: leg kort uit wat verandert en hoe je het getest hebt. Zie ook [CONTRIBUTING.md](CONTRIBUTING.md).

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

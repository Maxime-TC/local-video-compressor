#define AppName "Local Video Compressor"
#define AppVersion "0.5.10-beta"
#define AppPublisher "Taillieu Consultancy"
#define AppExeName "LocalVideoCompressor"

[Setup]
AppId={{B8C47D83-827C-4A30-8398-78A52A38D0E1}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/Maxime-TC/local-video-compressor
AppSupportURL=https://github.com/Maxime-TC/local-video-compressor
AppUpdatesURL=https://github.com/Maxime-TC/local-video-compressor/releases
DefaultDirName={localappdata}\Programs\LocalVideoCompressor
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=LocalVideoCompressor-0.5.10-beta-Win11-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\assets\local-video-compressor.ico
UninstallDisplayIcon={app}\assets\local-video-compressor.ico
VersionInfoVersion=0.5.10.0
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion=0.5.10.0
VersionInfoProductTextVersion={#AppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "win11msix"; Description: "Windows 11 main context menu integration (recommended)"; GroupDescription: "Choose integrations:"; Flags: checkedonce
Name: "classic"; Description: "Classic context-menu fallback under 'Show more options'"; GroupDescription: "Choose integrations:"; Flags: unchecked
Name: "restartexplorer"; Description: "Restart Windows Explorer after installation"; GroupDescription: "After installation:"; Flags: checkedonce

[Files]
Source: "..\..\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\bin\*"; DestDir: "{app}\bin"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\third_party\*"; DestDir: "{app}\third_party"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\CHANGELOG.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\Install-ContextMenu.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\Uninstall-ContextMenu.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\native\dist\LocalVideoCompressor-Beta-0.5.10-signed.msix"; DestDir: "{app}\native"; Flags: ignoreversion; Check: IsWin11MsixSelected
Source: "..\..\native\dist\TaillieuConsultancy-LocalVideoCompressor-Beta.cer"; DestDir: "{app}\native"; Flags: ignoreversion; Check: IsWin11MsixSelected

[Icons]
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\Install-ContextMenu.ps1"" -InstallDir ""{app}"" -SkipClassicContextMenu"; StatusMsg: "Installing backend files..."; Flags: runhidden waituntilterminated; Check: IsWin11OnlySelected
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\Install-ContextMenu.ps1"" -InstallDir ""{app}"""; StatusMsg: "Installing backend and classic context menu..."; Flags: runhidden waituntilterminated; Check: IsClassicSelected
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\Install-MSIX.ps1"" -InstallDir ""{app}"" -MsixPath ""{app}\native\LocalVideoCompressor-Beta-0.5.10-signed.msix"" -CertificatePath ""{app}\native\TaillieuConsultancy-LocalVideoCompressor-Beta.cer"""; StatusMsg: "Installing Windows 11 shell extension..."; Flags: runhidden waituntilterminated; Check: IsWin11MsixSelected
Filename: "powershell.exe"; Parameters: "-NoProfile -Command ""Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 750; Start-Process explorer.exe"""; StatusMsg: "Restarting Windows Explorer..."; Flags: runhidden waituntilterminated; Check: IsRestartExplorerSelected

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\Uninstall-MSIX.ps1"" -InstallDir ""{app}"""; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\Uninstall-ContextMenu.ps1"" -InstallDir ""{app}"""; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\LocalVideoCompressor\logs"

[Code]
function InitializeSetup(): Boolean;
begin
  MsgBox('This beta is intended for Maxime-controlled devices only.' + #13#10#13#10 +
    'For the modern Windows 11 main context menu, keep the MSIX integration selected. The classic fallback appears under Show more options.',
    mbInformation, MB_OK);
  Result := True;
end;

function IsWin11MsixSelected(): Boolean;
begin
  Result := WizardIsTaskSelected('win11msix');
end;

function IsClassicSelected(): Boolean;
begin
  Result := WizardIsTaskSelected('classic');
end;

function IsWin11OnlySelected(): Boolean;
begin
  Result := WizardIsTaskSelected('win11msix') and not WizardIsTaskSelected('classic');
end;

function IsRestartExplorerSelected(): Boolean;
begin
  Result := WizardIsTaskSelected('restartexplorer');
end;

; Royal Combat (Chess Arena) — Windows installer script
; Builds RoyalCombat_Setup.exe: installs the game, creates Start Menu and
; Desktop shortcuts, and ships with a proper uninstaller.

#define AppName "Royal Combat"
#define AppExeName "RoyalCombat.exe"
#define AppVersion "1.0.0"
#define AppPublisher "Khan"

[Setup]
AppId={{7E3F2C91-9B4A-4E7D-8F5A-2C6D1B8E4A30}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\RoyalCombat
DefaultGroupName={#AppName}
UninstallDisplayName={#AppName} (Chess Arena)
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir={#SourcePath}
OutputBaseFilename=RoyalCombat_Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
SetupIconFile={#SourcePath}\..\desktop_app\windows\runner\resources\app_icon.ico
Uninstallable=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "{#SourcePath}\..\desktop_app\build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove leftover user caches if any
Type: filesandordirs; Name: "{app}\data"

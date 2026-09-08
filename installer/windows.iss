#define MyAppName "Farooq Chat Viewer"
#define MyAppVersion "2.0.3"
[Setup]
AppId={{A37CAB9E-4722-4772-B54D-1698B58D075A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Mohammad Farooq
DefaultDirName={localappdata}\Programs\Farooq Chat Viewer
DefaultGroupName=Farooq Chat Viewer
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir=..\..\..\outputs
OutputBaseFilename=FarooqChatViewer-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\farooq_chat_viewer.exe
SetupIconFile=..\windows\runner\resources\app_icon.ico
CloseApplications=yes
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
[Files]
Source: "..\build-final\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\Farooq Chat Viewer"; Filename: "{app}\farooq_chat_viewer.exe"
Name: "{autodesktop}\Farooq Chat Viewer"; Filename: "{app}\farooq_chat_viewer.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\farooq_chat_viewer.exe"; Description: "Open Farooq Chat Viewer"; Flags: nowait postinstall skipifsilent

; The Windows installer executable.
;
; Inno Setup rather than an MSI or an MSIX: Orpheus installs into a directory,
; registers nothing system-wide, has no service to configure, and asks for no
; capability the platform gates. That is the whole of what this script needs to
; express, and Inno expresses it in a file a person can read.
;
; The installer is produced unsigned. Code signing needs a certificate the
; project does not hold, and SmartScreen will warn on first run until it does.
; Said here rather than discovered by whoever downloads it.
;
; The [Code] section at the bottom is what makes an upgrade an upgrade rather
; than an overlay. Inno's own "same AppId in the same directory" handling covers
; the ordinary case but not the two that matter: a directory the owner picked by
; hand that already holds Orpheus, and an installation left behind somewhere
; else when they change the directory. Both are found and offered for removal,
; and the removal is targeted — see RemovePayload.

#define AppName "Orpheus"
#define AppPublisher "Artur Rios"
#define AppExeName "orpheus.exe"

; Passed in by tools/build-windows-installer.ps1, which reads it from
; pubspec.yaml. Defaulted so that opening this file in the Inno Setup IDE and
; pressing compile produces something rather than an error about an undefined
; variable.
#ifndef AppVersion
  #define AppVersion GetEnv('ORPHEUS_VERSION')
#endif
#if AppVersion == ""
  #define AppVersion "0.0.0"
#endif

; The GUID lives here rather than being spelled out twice. `{{#AppGuid}` below
; expands to `{{<guid>}`, which is Inno's escape for a literal brace, and
; `{#AppGuid}` inside [Code] expands to the bare `{<guid>}` the uninstall
; registry key is named after. A GUID that drifted between the two would make
; the code silently stop finding what the installer itself registered.
#define AppGuid "{2C7E5A93-4F81-4B6D-9E2A-7D3C8B1F60A5}"

[Setup]
AppId={{#AppGuid}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppSupportURL=https://github.com/artur-rios/orpheus
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=orpheus-setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; The application is usable at its enforced minimum window size on Windows 10
; x64 and later, which is also the floor the Flutter Windows embedder supports.
MinVersion=10.0

; The Restart Manager closes a running Orpheus before files are replaced.
; Without it, upgrading while the application is open fails on a locked
; orpheus.exe or a loaded engine DLL — and a half-replaced bundle is worse than
; a refused one. Nothing is restarted afterwards: the [Run] entry already offers
; to launch it.
CloseApplications=yes
RestartApplications=no

; DefaultDirName is {autopf}, so the owner may reasonably want either a
; per-machine install under Program Files or a per-user one. Letting them choose
; is also what makes the per-user uninstall key under HKCU worth searching for
; in [Code].
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[CustomMessages]
english.ReplaceHere=%1 is already installed in:%n%n%2%n%nIt will be removed before version %3 is installed. Your library folders, your catalog, your listening statistics and your settings are left where they are and are not touched.%n%nRemove it and continue?
brazilianportuguese.ReplaceHere=O %1 já está instalado em:%n%n%2%n%nEle será removido antes da instalação da versão %3. Suas pastas de música, seu catálogo, suas estatísticas e suas configurações permanecem onde estão e não são alterados.%n%nRemover e continuar?

english.RemoveElsewhere=%1 is also installed in another location:%n%n%2%n%nYou chose to install into a different directory, so that copy would be left behind.%n%nRemove it as well?
brazilianportuguese.RemoveElsewhere=O %1 também está instalado em outro local:%n%n%2%n%nVocê escolheu instalar em um diretório diferente, então aquela cópia ficaria para trás.%n%nRemover também?

english.UninstallFailed=The previous installation's uninstaller did not finish cleanly. Setup will remove the program files in that directory itself.
brazilianportuguese.UninstallFailed=O desinstalador da instalação anterior não terminou corretamente. A instalação removerá os arquivos do programa naquele diretório por conta própria.

[Files]
; The whole release bundle. The playback engine's DLLs are already beside the
; executable — media_kit_libs_audio puts them there at build time — which is why
; there is nothing to fetch, register or configure here.
Source: "..\..\build\windows\x64\runner\Release\*"; \
  DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\{#AppExeName}"; \
  Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent

; Nothing of the owner's is uninstalled. The catalog, the cover cache, the play
; history and the settings live in the application-support directory and are
; deliberately left in place — an uninstall is not a request to forget what they
; listened to, and reinstalling should find it all again.

[Code]
const
  UninstallKey =
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppGuid}_is1';

var
  RecordedLocation: String;

{ Where a previous install registered itself, if it did.

  All four views are searched rather than only the one this run would write to.
  A per-machine install registers under HKLM in the 64-bit view; a per-user one
  registers under HKCU; and PrivilegesRequiredOverridesAllowed means the owner
  can pick a different one this time than last time. Searching only the current
  view would miss exactly the case this code exists for. }
function FindRecordedLocation(): String;
var
  Views: array[0..3] of Integer;
  Index: Integer;
  Location: String;
begin
  Result := '';

  Views[0] := HKLM64;
  Views[1] := HKLM32;
  Views[2] := HKCU64;
  Views[3] := HKCU32;

  for Index := 0 to 3 do
  begin
    if RegQueryStringValue(Views[Index], UninstallKey, 'InstallLocation', Location) then
    begin
      Location := RemoveBackslashUnlessRoot(Trim(Location));
      if (Location <> '') and DirExists(Location) then
      begin
        Result := Location;
        Exit;
      end;
    end;
  end;
end;

{ An installation is "there" if what matters is there: the executable, or the
  uninstaller a previous Inno-built setup left beside it. A directory holding
  only leftovers still counts — clearing it is the point. }
function DirectoryHoldsInstall(const Directory: String): Boolean;
begin
  Result := (Directory <> '') and
            (FileExists(Directory + '\{#AppExeName}') or
             FileExists(Directory + '\unins000.exe'));
end;

{ Inno's uninstaller relaunches itself from a temporary copy and the first
  process returns immediately, so Exec's wait says nothing about whether the
  uninstall finished. What does say so is unins000.exe itself disappearing — it
  is deleted once the uninstall completes. Bounded at a minute so a stuck
  uninstaller leaves the wizard responsive rather than hung; the caller falls
  back to removing the files directly. }
function WaitForUninstaller(const UninstallerPath: String): Boolean;
var
  Waited: Integer;
begin
  Waited := 0;
  while FileExists(UninstallerPath) and (Waited < 120) do
  begin
    Sleep(500);
    Waited := Waited + 1;
  end;
  Result := not FileExists(UninstallerPath);
end;

{ Removes only the paths this payload writes. Deliberately not a DelTree of the
  directory: the owner chooses it by hand on the directory page, and one who
  points setup at a folder holding unrelated files must not lose them. }
procedure RemovePayload(const Directory: String);
begin
  if Directory = '' then
    Exit;

  DeleteFile(Directory + '\{#AppExeName}');

  { The Flutter runner, its plugins and the engine's libraries all land flat
    beside the executable, and their names carry versions that move. Matching
    them is what keeps a stale engine DLL from the previous release out of the
    new bundle — the leftover that surfaces later as an unrelated-looking
    "could not start playback". }
  DelTree(Directory + '\*.dll', False, True, False);
  DelTree(Directory + '\data', True, True, True);

  { Empty afterwards, or holding something that was not ours. Either way this
    only succeeds in the first case. }
  RemoveDir(Directory);
end;

{ Runs the uninstaller a previous setup registered, and reports whether it
  actually finished. }
function RunPreviousUninstaller(const Directory: String): Boolean;
var
  UninstallerPath: String;
  ResultCode: Integer;
begin
  UninstallerPath := Directory + '\unins000.exe';

  if not FileExists(UninstallerPath) then
  begin
    Result := False;
    Exit;
  end;

  if not Exec(UninstallerPath,
              '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART',
              '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := False;
    Exit;
  end;

  Result := WaitForUninstaller(UninstallerPath);
end;

{ Uninstaller first, then a targeted sweep of whatever it left. The sweep runs
  either way: a clean uninstall leaves nothing for it to find, and a failed one
  is exactly when it is needed. }
procedure RemoveInstallation(const Directory: String; const WarnOnFailure: Boolean);
begin
  if FileExists(Directory + '\unins000.exe') then
    if (not RunPreviousUninstaller(Directory)) and WarnOnFailure then
      MsgBox(CustomMessage('UninstallFailed'), mbInformation, MB_OK);

  RemovePayload(Directory);
end;

function InitializeSetup(): Boolean;
begin
  RecordedLocation := FindRecordedLocation();
  Result := True;
end;

{ Note on formatting throughout this section: no line may *begin* with `[`, even
  inside Pascal code and even indented. The compiler decides what is a section
  header before it decides what is code, and a wrapped line whose first non-blank
  character is an open bracket is read as a section tag — which is what "Invalid
  section tag" on a line in the middle of a function means. Every argument array
  below is therefore built on a line that starts with something else. }

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Chosen: String;
  Prompt: String;
begin
  Result := True;

  if CurPageID <> wpSelectDir then
    Exit;

  Chosen := RemoveBackslashUnlessRoot(WizardDirValue);

  { 1. An installation in the directory the owner actually chose. Refusing keeps
       them on the directory page rather than cancelling setup, so they can pick
       somewhere else. }
  if DirectoryHoldsInstall(Chosen) then
  begin
    Prompt := FmtMessage(CustomMessage('ReplaceHere'), ['{#AppName}', Chosen, '{#AppVersion}']);

    if MsgBox(Prompt, mbConfirmation, MB_YESNO) <> IDYES then
    begin
      Result := False;
      Exit;
    end;

    RemoveInstallation(Chosen, True);
  end;

  { 2. An installation somewhere else entirely — the owner changed the
       directory. Asked separately, and answering no is a real choice rather
       than a blocked one: two copies is a state they may want. }
  if (RecordedLocation <> '') and
     (CompareText(RecordedLocation, Chosen) <> 0) and
     DirectoryHoldsInstall(RecordedLocation) then
  begin
    Prompt := FmtMessage(CustomMessage('RemoveElsewhere'), ['{#AppName}', RecordedLocation]);

    if MsgBox(Prompt, mbConfirmation, MB_YESNO) = IDYES then
      RemoveInstallation(RecordedLocation, False);
  end;
end;

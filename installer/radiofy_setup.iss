; Radiofy Windows Installer Script
; Created with Inno Setup - https://jrsoftware.org/isinfo.php

#define MyAppName "Radiofy"
#define MyAppVersion "1.02.0"
#define MyAppPublisher "Radiofy"
#define MyAppURL "https://github.com/jonasbrum/radiofy"
#define MyAppExeName "radiofy.exe"
#define DonateURL "https://www.paypal.com/donate/?business=6PNHFW2AUEJLE&no_recurring=0&item_name=Keep+Radiofy+alive%21&currency_code=BRL"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{A8F7C9B2-4E3D-4A1B-9C5E-8F2D6A3B7E9C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\LICENSE
OutputDir=..\build\installer
OutputBaseFilename=RadiofySetup_{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
DisableProgramGroupPage=yes
;SignTool=signtool

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DonatePage: TOutputMsgWizardPage;

procedure InitializeWizard;
begin
  DonatePage := CreateOutputMsgPage(wpFinished,
    'Support Radiofy',
    'Help keep Radiofy alive and improving!',
    'Radiofy is free and open source. If you enjoy using it, please consider supporting the development with a donation.' + #13#10#13#10 +
    'Your support helps cover server costs and development time.' + #13#10#13#10 +
    'After closing this window, you can donate at:' + #13#10 +
    '{#DonateURL}');
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
  begin
    // Show donate message on finish page
    WizardForm.FinishedLabel.Caption :=
      WizardForm.FinishedLabel.Caption + #13#10#13#10 +
      'If you enjoy Radiofy, please consider supporting its development!' + #13#10 +
      'Click the button below to donate.';
  end;
end;

procedure DonateButtonOnClick(Sender: TObject);
var
  ErrorCode: Integer;
begin
  ShellExec('open', '{#DonateURL}', '', '', SW_SHOW, ewNoWait, ErrorCode);
end;

procedure CurPageCustomButtonClick(PageID: Integer; ButtonID: Integer);
begin
  // Handle custom button clicks if needed
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  // Additional setup steps if needed
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  S: String;
begin
  S := '';
  S := S + MemoDirInfo + NewLine;
  S := S + NewLine;
  S := S + MemoTasksInfo + NewLine;
  Result := S;
end;

function ShouldInstallRuntime(): Boolean;
begin
  // Check if Visual C++ Runtime is needed
  Result := False;
end;

procedure DeinitializeSetup();
var
  ResultCode: Integer;
  ButtonSelected: Integer;
begin
  if (WizardSilent = False) and (not WizardCancelled) then
  begin
    ButtonSelected := MsgBox(
      'Thank you for installing Radiofy!' + #13#10#13#10 +
      'Would you like to support the development with a donation?' + #13#10#13#10 +
      'Click Yes to open the donation page in your browser.',
      mbConfirmation, MB_YESNO);

    if ButtonSelected = IDYES then
    begin
      ShellExec('open', '{#DonateURL}', '', '', SW_SHOW, ewNoWait, ResultCode);
    end;
  end;
end;

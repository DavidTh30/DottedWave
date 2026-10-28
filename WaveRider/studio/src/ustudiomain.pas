{ WaveRider Studio - launcher window.
  Shares one TGameData and one audio engine with every editor, so all
  simulations always reflect the latest edits. }
unit uStudioMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs, LCLIntf,
  BGRABitmap, BGRABitmapTypes, uWaveTypes, uWaveEngine, uGameData, uGfx, uAudio, uMusic;

type

  { TStudioForm }

  TStudioForm = class(TForm)
  private
    FData: TGameData;
    FLogo: TPaintBox;
    FLogoBmp: TBGRABitmap;
    FEngine: TWaveEngine;
    FDots: TDotText;
    FTimer: TTimer;
    FTime: Single;
    FStatus: TLabel;
    FEditors: array[0..5] of TForm;
    FOpenTimer: TTimer;
    procedure OpenTimerTick(Sender: TObject);
    procedure LogoPaint(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure OpenEditor(Sender: TObject);
    procedure PlayClick(Sender: TObject);
    procedure SaveAllClick(Sender: TObject);
    procedure ReloadClick(Sender: TObject);
    procedure FolderClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    PendingOpen: Integer;     { set from the command line, opened after the launcher shows }
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Open(AIndex: Integer);
    property Data: TGameData read FData;
  end;

var
  StudioForm: TStudioForm;

implementation

uses
  uEdScreens, uEdSound, uEdMusic, uEdLevels, uEdObjects, uEdLight;

const
  ED_NAMES: array[0..5] of string = ('Menu & Screen FX', 'Sound FX', 'Music', 'Levels', 'Objects & Effects', 'Light FX');
  ED_DESC: array[0..5] of string = (
    'Dotted iridescent pearl titles, menus, backgrounds and HUD of every game screen - live simulation',
    'Two-layer heavy bass synth (character + sub), waveform, bass meter, templates, WAV export',
    'Step sequencer, 8 instruments, arrangement, combo / fever / bonus reactivity simulator, WAV export',
    'Difficulty, mesh style, pixel-art mode, pace, spawn mixes and bonuses - live autopilot simulation',
    'Collectibles, hazards and bonuses: motion, look, pixel sprites, pickup effects - live simulation',
    'Prism, Newton''s prisms, diffraction grating, diamond: spectral ray-traced light - Light lab / beam simulation');

{ TStudioForm }

constructor TStudioForm.Create(TheOwner: TComponent);
var
  i: Integer;
  b: TButton;
  row, bottom: TPanel;
  lbl: TLabel;
begin
  inherited CreateNew(TheOwner);
  Caption := 'WaveRider Studio';
  Width := 720;
  Height := 840;
  Position := poScreenCenter;
  Color := RGBToColor(18, 18, 24);
  Font.Color := clWhite;

  FData := TGameData.Create(FindDataDir);
  if not FileExists(FData.LevelsFile) then
    try FData.SaveAll; except end;
  FData.LoadAll;

  Audio := TAudioEngine.Create;
  Audio.SetBank(FData.Sfx);
  Audio.SetSong(FData.Song);
  Audio.Start;

  FEngine := TWaveEngine.Create;
  FDots := TDotText.Create;
  FLogoBmp := TBGRABitmap.Create(2, 2);

  FLogo := TPaintBox.Create(Self);
  FLogo.Parent := Self;
  FLogo.Align := alTop;
  FLogo.Height := 230;
  FLogo.OnPaint := @LogoPaint;

  for i := 0 to 5 do
  begin
    row := TPanel.Create(Self);
    row.Parent := Self;
    row.Align := alTop;
    row.Top := 1000 + i * 100;
    row.Height := 70;
    row.BevelOuter := bvNone;
    row.BorderSpacing.Around := 5;
    row.Color := RGBToColor(28, 28, 38);
    b := TButton.Create(Self);
    b.Parent := row;
    b.Align := alLeft;
    b.Width := 220;
    b.Caption := Format('%d   %s', [i + 1, StringReplace(ED_NAMES[i], '&', '&&', [rfReplaceAll])]);
    b.Font.Size := 11;
    b.Font.Style := [fsBold];
    b.Tag := i;
    b.OnClick := @OpenEditor;
    lbl := TLabel.Create(Self);
    lbl.Parent := row;
    lbl.Align := alClient;
    lbl.WordWrap := True;
    lbl.Layout := tlCenter;
    lbl.BorderSpacing.Left := 12;
    lbl.BorderSpacing.Right := 8;
    lbl.Font.Color := RGBToColor(200, 200, 215);
    lbl.Caption := ED_DESC[i];
  end;

  bottom := TPanel.Create(Self);
  bottom.Parent := Self;
  bottom.Align := alBottom;
  bottom.Height := 44;
  bottom.BevelOuter := bvNone;
  bottom.BorderSpacing.Around := 6;
  bottom.Color := Color;
  b := TButton.Create(Self); b.Parent := bottom; b.Caption := 'PLAY WAVE RIDER'; b.Width := 170;
  b.Align := alLeft; b.Font.Style := [fsBold]; b.OnClick := @PlayClick;
  b := TButton.Create(Self); b.Parent := bottom; b.Caption := 'Save all'; b.Width := 100; b.Left := 1000;
  b.Align := alLeft; b.BorderSpacing.Left := 6; b.OnClick := @SaveAllClick;
  b := TButton.Create(Self); b.Parent := bottom; b.Caption := 'Reload all'; b.Width := 100; b.Left := 2000;
  b.Align := alLeft; b.BorderSpacing.Left := 6; b.OnClick := @ReloadClick;
  b := TButton.Create(Self); b.Parent := bottom; b.Caption := 'Data folder'; b.Width := 100; b.Left := 3000;
  b.Align := alLeft; b.BorderSpacing.Left := 6; b.OnClick := @FolderClick;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := alBottom;
  FStatus.BorderSpacing.Around := 6;
  FStatus.Font.Color := RGBToColor(150, 150, 170);
  FStatus.Caption := Format('Data: %s     Audio: %s     Objects %d   Levels %d   Sounds %d   Song "%s" %.0f s',
    [FData.DataDir, BoolToStr(Audio.DeviceOk, 'on', 'no device'), Length(FData.Objects), Length(FData.Levels),
     Length(FData.Sfx), FData.Song.Name, SongLengthSeconds(FData.Song)]);

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 33;
  FTimer.OnTimer := @Tick;
  OnCloseQuery := @FormCloseQuery;
  PendingOpen := -1;
  FOpenTimer := TTimer.Create(Self);
  FOpenTimer.Interval := 300;
  FOpenTimer.OnTimer := @OpenTimerTick;
end;

procedure TStudioForm.OpenTimerTick(Sender: TObject);
begin
  FOpenTimer.Enabled := False;
  if PendingOpen >= 0 then
  begin
    Open(PendingOpen);
    PendingOpen := -1;
  end;
end;

destructor TStudioForm.Destroy;
begin
  FTimer.Enabled := False;
  if Audio <> nil then Audio.Stop;
  FreeAndNil(Audio);
  FEngine.Free;
  FDots.Free;
  FLogoBmp.Free;
  FData.Free;
  inherited Destroy;
end;

procedure TStudioForm.Tick(Sender: TObject);
begin
  FTime := FTime + FTimer.Interval / 1000;
  FLogo.Invalidate;
end;

procedure TStudioForm.LogoPaint(Sender: TObject);
var
  cfg: TWaveConfig;
  fx: TScreenFx;
  k: Single;
begin
  if (FLogoBmp.Width <> FLogo.Width) or (FLogoBmp.Height <> FLogo.Height) then
    FLogoBmp.SetSize(Max(2, FLogo.Width), Max(2, FLogo.Height));
  cfg := PresetConfig(5);
  cfg.Values[wpIriAmount] := 0.35;
  cfg.Values[wpVignette] := 0.6;
  FEngine.ScrollY := FTime * 60;
  FEngine.Render(FLogoBmp, cfg, FTime * 0.12, FTime);
  DimRect(FLogoBmp, 0.35);
  fx := FData.Screens[scMain];
  k := FLogoBmp.Height / 420;
  FDots.Draw(FLogoBmp, 'WAVE RIDER', FLogoBmp.Width / 2, FLogoBmp.Height * 0.16, 120, fx, k, FTime);
  FDots.Draw(FLogoBmp, 'STUDIO', FLogoBmp.Width / 2, FLogoBmp.Height * 0.58, 70, fx, k, FTime + 0.5);
  FLogoBmp.Draw(FLogo.Canvas, 0, 0, True);
end;

procedure TStudioForm.Open(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex > 5) then Exit;
  if (FEditors[AIndex] = nil) or not FEditors[AIndex].HandleAllocated or not FEditors[AIndex].Visible then
  begin
    if FEditors[AIndex] <> nil then FreeAndNil(FEditors[AIndex]);
    case AIndex of
      0: FEditors[AIndex] := TScreenEditor.Create(Application, FData);
      1: FEditors[AIndex] := TSoundEditor.Create(Application, FData);
      2: FEditors[AIndex] := TMusicEditor.Create(Application, FData);
      3: FEditors[AIndex] := TLevelEditor.Create(Application, FData);
      4: FEditors[AIndex] := TObjectEditor.Create(Application, FData);
      5: FEditors[AIndex] := TLightEditor.Create(Application, FData);
    end;
  end;
  FEditors[AIndex].Show;
  FEditors[AIndex].BringToFront;
end;

procedure TStudioForm.OpenEditor(Sender: TObject);
begin
  Open(TButton(Sender).Tag);
end;

procedure TStudioForm.PlayClick(Sender: TObject);
var
  exe: string;
begin
  exe := ExtractFilePath(Application.ExeName) + 'WaveRider.exe';
  if not FileExists(exe) then
  begin
    MessageDlg('WaveRider.exe not found next to the Studio:' + LineEnding + exe, mtError, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Save all editors before starting the game?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    SaveAllClick(nil);
  OpenDocument(exe);
end;

procedure TStudioForm.SaveAllClick(Sender: TObject);
begin
  Audio.Lock;
  try
    FData.Song := Audio.SongPtr^;
  finally
    Audio.Unlock;
  end;
  FData.SaveAll;
  FStatus.Caption := 'All data saved to ' + FData.DataDir + '  ' + FormatDateTime('hh:nn:ss', Now);
end;

procedure TStudioForm.ReloadClick(Sender: TObject);
var
  i: Integer;
begin
  if MessageDlg('Close all editors and reload everything from disk?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  for i := 0 to 5 do
    if FEditors[i] <> nil then FreeAndNil(FEditors[i]);
  FData.LoadAll;
  Audio.SetBank(FData.Sfx);
  Audio.SetSong(FData.Song);
  FStatus.Caption := 'Reloaded from ' + FData.DataDir;
end;

procedure TStudioForm.FolderClick(Sender: TObject);
begin
  OpenDocument(FData.DataDir);
end;

procedure TStudioForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  i: Integer;
begin
  for i := 0 to 5 do
    if (FEditors[i] <> nil) and FEditors[i].Visible then
    begin
      FEditors[i].Close;
      if FEditors[i].Visible then
      begin
        CanClose := False;
        Exit;
      end;
    end;
end;

end.

{ Music editor: arrangement (sections), 32-step pattern grid for 8 tracks,
  instrument synth parameters, transport and a game reactivity simulator
  (combo intensity, fever, pause muffle, slow-mo, bonus sweep). Edits go
  straight to the song the audio engine is playing. }
unit uEdMusic;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls, Spin, Dialogs, LCLType,
  uParams, uSynth, uMusic, uAudio, uGameData, uParamPanel;

type

  { TMusicEditor }

  TMusicEditor = class(TForm)
  private
    FData: TGameData;
    FTop, FTop2, FLeft, FCenter, FPatBar: TPanel;
    FSections: TListBox;
    FSecPanel, FInstPanel: TParamPanel;
    FGrid: TPaintBox;
    FPatCombo: TComboBox;
    FBtnPlay: TButton;
    FChkLoop, FChkFever, FChkMuffle, FChkSlow: TCheckBox;
    FBpm: TFloatSpinEdit;
    FSwing: TFloatSpinEdit;
    FIntensity: TTrackBar;
    FLblInt, FLblPos, FStatus: TLabel;
    FExportSecs: TSpinEdit;
    FTimer: TTimer;
    FTrack: Integer;
    FPat: Integer;
    FSelStep: Integer;
    FLastNote: array[0..MAX_TRACKS - 1] of Integer;
    FSweep: Single;
    FDirty: Boolean;
    FUpdating: Boolean;
    function S: PSong;
    procedure Lock(Sender: TObject);
    procedure Unlock(Sender: TObject);
    function Btn(AParent: TPanel; const ACaption: string; AOnClick: TNotifyEvent; AAlign: TAlign = alLeft): TButton;
    procedure RefreshSections;
    procedure RefreshPatterns;
    procedure SelectSection(I: Integer);
    procedure SelectTrack(T: Integer);
    procedure MarkDirty;
    procedure GridPaint(Sender: TObject);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GridWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    function CellAt(X, Y: Integer; out T, St: Integer): Boolean;
    procedure EditCell(T, St, DNote, DLen, DVel: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Tick(Sender: TObject);
    procedure SectionsClick(Sender: TObject);
    procedure SecChanged(Sender: TObject; const AKey: string);
    procedure InstChanged(Sender: TObject; const AKey: string);
    procedure PatComboChange(Sender: TObject);
    procedure PlayClick(Sender: TObject);
    procedure LoopChange(Sender: TObject);
    procedure BpmChange(Sender: TObject);
    procedure BonusClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure RevertClick(Sender: TObject);
    procedure DefaultClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure SecAdd(Sender: TObject);
    procedure SecDup(Sender: TObject);
    procedure SecDel(Sender: TObject);
    procedure SecUp(Sender: TObject);
    procedure SecDown(Sender: TObject);
    procedure PatNew(Sender: TObject);
    procedure PatDup(Sender: TObject);
    procedure PatRename(Sender: TObject);
    procedure PatClear(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure PreviewLocked(T, ANote: Integer);
  public
    constructor Create(AOwner: TComponent; AData: TGameData); reintroduce;
  end;

implementation

const
  HEADER_W = 120;
  ROW_H = 34;
  HEAD_H = 22;

{ TMusicEditor }

constructor TMusicEditor.Create(AOwner: TComponent; AData: TGameData);
var
  split: TSplitter;
  lp, sb: TPanel;
  t, i, st: Integer;
  b: TButton;
  lbl: TLabel;
begin
  inherited CreateNew(AOwner);
  FData := AData;
  Caption := 'WaveRider Studio - Music';
  Width := Min(1600, Screen.WorkAreaWidth - 30);
  Height := Min(980, Screen.WorkAreaHeight - 30);
  Position := poScreenCenter;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
  OnCloseQuery := @FormCloseQuery;

  { the editor works on the song the engine plays }
  Audio.SetSong(FData.Song);
  Audio.Music.LoopSection := -1;

  { ---- transport ---- }
  FTop := TPanel.Create(Self);
  FTop.Parent := Self; FTop.Align := alTop; FTop.Height := 34; FTop.BevelOuter := bvNone;
  FTop.BorderSpacing.Around := 2;
  FBtnPlay := Btn(FTop, '  PLAY  ', @PlayClick);
  FBtnPlay.Font.Style := [fsBold];
  FChkLoop := TCheckBox.Create(Self);
  FChkLoop.Parent := FTop; FChkLoop.Caption := 'Loop section'; FChkLoop.Left := FTop.ControlCount * 1000;
  FChkLoop.Align := alLeft; FChkLoop.BorderSpacing.Left := 8; FChkLoop.OnChange := @LoopChange;
  lbl := TLabel.Create(Self); lbl.Parent := FTop; lbl.Caption := '  BPM'; lbl.Layout := tlCenter;
  lbl.Left := FTop.ControlCount * 1000; lbl.Align := alLeft;
  FBpm := TFloatSpinEdit.Create(Self); FBpm.Parent := FTop; FBpm.MinValue := 40; FBpm.MaxValue := 240;
  FBpm.DecimalPlaces := 1; FBpm.Width := 70; FBpm.Left := FTop.ControlCount * 1000; FBpm.Align := alLeft;
  FBpm.OnChange := @BpmChange;
  lbl := TLabel.Create(Self); lbl.Parent := FTop; lbl.Caption := '  Swing'; lbl.Layout := tlCenter;
  lbl.Left := FTop.ControlCount * 1000; lbl.Align := alLeft;
  FSwing := TFloatSpinEdit.Create(Self); FSwing.Parent := FTop; FSwing.MinValue := 0; FSwing.MaxValue := 0.5;
  FSwing.DecimalPlaces := 2; FSwing.Increment := 0.02; FSwing.Width := 64; FSwing.Left := FTop.ControlCount * 1000;
  FSwing.Align := alLeft; FSwing.OnChange := @BpmChange;
  Btn(FTop, 'Save', @SaveClick).Font.Style := [fsBold];
  Btn(FTop, 'Revert', @RevertClick);
  Btn(FTop, 'Default song', @DefaultClick);
  Btn(FTop, 'Export WAV', @ExportClick);
  FExportSecs := TSpinEdit.Create(Self); FExportSecs.Parent := FTop; FExportSecs.MinValue := 5;
  FExportSecs.MaxValue := 900; FExportSecs.Value := Round(SongLengthSeconds(FData.Song));
  FExportSecs.Width := 64; FExportSecs.Left := FTop.ControlCount * 1000; FExportSecs.Align := alLeft;
  lbl := TLabel.Create(Self); lbl.Parent := FTop; lbl.Caption := ' s'; lbl.Layout := tlCenter;
  lbl.Left := FTop.ControlCount * 1000; lbl.Align := alLeft;
  FLblPos := TLabel.Create(Self); FLblPos.Parent := FTop; FLblPos.Align := alClient; FLblPos.Layout := tlCenter;
  FLblPos.Alignment := taRightJustify; FLblPos.Font.Style := [fsBold]; FLblPos.BorderSpacing.Right := 8;

  { ---- game reactivity simulator ---- }
  FTop2 := TPanel.Create(Self);
  FTop2.Parent := Self; FTop2.Align := alTop; FTop2.Top := 100; FTop2.Height := 32; FTop2.BevelOuter := bvNone;
  FTop2.BorderSpacing.Around := 2;
  lbl := TLabel.Create(Self); lbl.Parent := FTop2; lbl.Caption := 'GAME SIMULATION   Combo: ';
  lbl.Layout := tlCenter; lbl.Font.Style := [fsBold]; lbl.Align := alLeft;
  FIntensity := TTrackBar.Create(Self); FIntensity.Parent := FTop2; FIntensity.Min := 1; FIntensity.Max := 9;
  FIntensity.Position := 1; FIntensity.Width := 220; FIntensity.Left := FTop2.ControlCount * 1000;
  FIntensity.Align := alLeft; FIntensity.TickStyle := tsAuto;
  FLblInt := TLabel.Create(Self); FLblInt.Parent := FTop2; FLblInt.Caption := 'x1'; FLblInt.Layout := tlCenter;
  FLblInt.Width := 40; FLblInt.AutoSize := False; FLblInt.Left := FTop2.ControlCount * 1000; FLblInt.Align := alLeft;
  FChkFever := TCheckBox.Create(Self); FChkFever.Parent := FTop2; FChkFever.Caption := 'Fever';
  FChkFever.Left := FTop2.ControlCount * 1000; FChkFever.Align := alLeft; FChkFever.BorderSpacing.Left := 8;
  FChkMuffle := TCheckBox.Create(Self); FChkMuffle.Parent := FTop2; FChkMuffle.Caption := 'Paused (muffle)';
  FChkMuffle.Left := FTop2.ControlCount * 1000; FChkMuffle.Align := alLeft; FChkMuffle.BorderSpacing.Left := 8;
  FChkSlow := TCheckBox.Create(Self); FChkSlow.Parent := FTop2; FChkSlow.Caption := 'Slow-mo';
  FChkSlow.Left := FTop2.ControlCount * 1000; FChkSlow.Align := alLeft; FChkSlow.BorderSpacing.Left := 8;
  b := Btn(FTop2, 'BONUS HIT!', @BonusClick);
  b.Hint := 'Filter sweep + echo throw, like picking up a bonus';
  FStatus := TLabel.Create(Self); FStatus.Parent := FTop2; FStatus.Align := alClient; FStatus.Layout := tlCenter;
  FStatus.Alignment := taRightJustify; FStatus.BorderSpacing.Right := 8; FStatus.Caption := FData.SongFile;

  { ---- left: arrangement ---- }
  FLeft := TPanel.Create(Self);
  FLeft.Parent := Self; FLeft.Align := alLeft; FLeft.Width := 300; FLeft.BevelOuter := bvNone;
  lp := TPanel.Create(Self); lp.Parent := FLeft; lp.Align := alTop; lp.Height := 24; lp.BevelOuter := bvNone;
  lp.Caption := 'ARRANGEMENT (sections)'; lp.Font.Style := [fsBold];
  sb := TPanel.Create(Self); sb.Parent := FLeft; sb.Align := alTop; sb.Top := 200; sb.Height := 28;
  sb.BevelOuter := bvNone;
  Btn(sb, '+', @SecAdd); Btn(sb, 'Dup', @SecDup); Btn(sb, '-', @SecDel); Btn(sb, 'Up', @SecUp); Btn(sb, 'Dn', @SecDown);
  FSections := TListBox.Create(Self); FSections.Parent := FLeft; FSections.Align := alTop; FSections.Top := 300;
  FSections.Height := 300; FSections.OnClick := @SectionsClick;
  FSecPanel := TParamPanel.Create(Self); FSecPanel.Parent := FLeft; FSecPanel.Align := alClient;
  FSecPanel.LabelWidth := 120;
  FSecPanel.OnBeforeWrite := @Lock; FSecPanel.OnAfterWrite := @Unlock; FSecPanel.OnChange := @SecChanged;

  split := TSplitter.Create(Self); split.Parent := Self; split.Left := 400; split.Align := alLeft;

  { ---- right: instrument ---- }
  FInstPanel := TParamPanel.Create(Self);
  FInstPanel.Parent := Self; FInstPanel.Align := alRight; FInstPanel.Width := 430;
  FInstPanel.OnBeforeWrite := @Lock; FInstPanel.OnAfterWrite := @Unlock; FInstPanel.OnChange := @InstChanged;
  split := TSplitter.Create(Self); split.Parent := Self; split.Align := alRight;

  { ---- center: pattern ---- }
  FCenter := TPanel.Create(Self);
  FCenter.Parent := Self; FCenter.Align := alClient; FCenter.BevelOuter := bvNone;
  FPatBar := TPanel.Create(Self); FPatBar.Parent := FCenter; FPatBar.Align := alTop; FPatBar.Height := 30;
  FPatBar.BevelOuter := bvNone;
  lbl := TLabel.Create(Self); lbl.Parent := FPatBar; lbl.Caption := ' PATTERN '; lbl.Font.Style := [fsBold];
  lbl.Layout := tlCenter; lbl.Align := alLeft;
  FPatCombo := TComboBox.Create(Self); FPatCombo.Parent := FPatBar; FPatCombo.Style := csDropDownList;
  FPatCombo.Width := 180; FPatCombo.Left := FPatBar.ControlCount * 1000; FPatCombo.Align := alLeft;
  FPatCombo.OnChange := @PatComboChange;
  Btn(FPatBar, 'New', @PatNew); Btn(FPatBar, 'Duplicate', @PatDup); Btn(FPatBar, 'Rename', @PatRename);
  Btn(FPatBar, 'Clear', @PatClear); Btn(FPatBar, 'Preview note', @PreviewClick);
  lbl := TLabel.Create(Self); lbl.Parent := FCenter; lbl.Align := alBottom; lbl.WordWrap := True;
  lbl.BorderSpacing.Around := 4; lbl.Font.Color := clGray;
  lbl.Caption := 'Click = add / select   Right click = delete   Wheel = note (Shift = octave, Ctrl = length, Alt = velocity)   ' +
    'Keys: arrows move / note, PgUp PgDn octave, + - length, 1-9 velocity, Del delete, Ins add   ' +
    'Track header: click = edit instrument, M = mute, S = solo';
  FGrid := TPaintBox.Create(Self); FGrid.Parent := FCenter; FGrid.Align := alClient;
  FGrid.OnPaint := @GridPaint; FGrid.OnMouseDown := @GridMouseDown; FGrid.OnMouseWheel := @GridWheel;

  for t := 0 to MAX_TRACKS - 1 do
  begin
    FLastNote[t] := 45;
    for i := 0 to High(FData.Song.Patterns) do
      for st := 0 to PAT_STEPS - 1 do
        if FData.Song.Patterns[i].Cells[t, st].Note > 0 then
        begin
          FLastNote[t] := FData.Song.Patterns[i].Cells[t, st].Note;
          Break;
        end;
  end;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 33;
  FTimer.OnTimer := @Tick;

  FUpdating := True;
  FBpm.Value := S^.Bpm;
  FSwing.Value := S^.Swing;
  FUpdating := False;
  FSelStep := -1;
  RefreshSections;
  RefreshPatterns;
  SelectSection(0);
  SelectTrack(0);
end;

function TMusicEditor.S: PSong;
begin
  Result := Audio.SongPtr;
end;

procedure TMusicEditor.Lock(Sender: TObject);
begin
  Audio.Lock;
end;

procedure TMusicEditor.Unlock(Sender: TObject);
begin
  Audio.Unlock;
end;

function TMusicEditor.Btn(AParent: TPanel; const ACaption: string; AOnClick: TNotifyEvent; AAlign: TAlign): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.AutoSize := True;
  Result.Left := AParent.ControlCount * 1000;
  Result.Align := AAlign;
  Result.BorderSpacing.Left := 3;
  Result.OnClick := AOnClick;
end;

procedure TMusicEditor.MarkDirty;
begin
  FDirty := True;
  if Pos('*', Caption) = 0 then Caption := Caption + ' *';
end;

procedure TMusicEditor.RefreshSections;
var
  i, keep: Integer;
  p: string;
begin
  keep := FSections.ItemIndex;
  FSections.Items.BeginUpdate;
  try
    FSections.Items.Clear;
    for i := 0 to High(S^.Sections) do
    begin
      if (S^.Sections[i].Pattern >= 0) and (S^.Sections[i].Pattern <= High(S^.Patterns)) then
        p := S^.Patterns[S^.Sections[i].Pattern].Name
      else
        p := '?';
      FSections.Items.Add(Format('%2d  %s  [%s x%d]  E%.2f', [i + 1, S^.Sections[i].Name, p,
        S^.Sections[i].Repeats, S^.Sections[i].Energy]));
    end;
  finally
    FSections.Items.EndUpdate;
  end;
  if (keep >= 0) and (keep < FSections.Count) then FSections.ItemIndex := keep;
  FExportSecs.Value := Round(SongLengthSeconds(S^));
end;

procedure TMusicEditor.RefreshPatterns;
var
  i: Integer;
begin
  FPatCombo.Items.BeginUpdate;
  try
    FPatCombo.Items.Clear;
    for i := 0 to High(S^.Patterns) do
      FPatCombo.Items.Add(Format('%d  %s', [i, S^.Patterns[i].Name]));
  finally
    FPatCombo.Items.EndUpdate;
  end;
  FPat := EnsureRange(FPat, 0, Max(0, High(S^.Patterns)));
  FPatCombo.ItemIndex := FPat;
end;

procedure TMusicEditor.SelectSection(I: Integer);
var
  b: TPBuilder;
begin
  if Length(S^.Sections) = 0 then Exit;
  I := EnsureRange(I, 0, High(S^.Sections));
  FSections.ItemIndex := I;
  b.Clear;
  DescribeSection(b, S^.Sections[I]);
  FSecPanel.Build(b.List);
  FPat := EnsureRange(S^.Sections[I].Pattern, 0, Max(0, High(S^.Patterns)));
  FPatCombo.ItemIndex := FPat;
  if FChkLoop.Checked then
  begin
    Audio.Lock;
    try
      Audio.Music.LoopSection := I;
      Audio.Music.SeekSection(I);
    finally
      Audio.Unlock;
    end;
  end;
  FGrid.Invalidate;
end;

procedure TMusicEditor.SelectTrack(T: Integer);
var
  b: TPBuilder;
begin
  FTrack := EnsureRange(T, 0, MAX_TRACKS - 1);
  b.Clear;
  DescribeInstrument(b, S^.Tracks[FTrack]);
  FInstPanel.Build(b.List);
  FGrid.Invalidate;
end;

function TMusicEditor.CellAt(X, Y: Integer; out T, St: Integer): Boolean;
var
  cw: Single;
begin
  cw := (FGrid.Width - HEADER_W) / PAT_STEPS;
  T := (Y - HEAD_H) div ROW_H;
  if X < HEADER_W then St := -1 else St := Trunc((X - HEADER_W) / cw);
  Result := (T >= 0) and (T < MAX_TRACKS) and (Y >= HEAD_H);
end;

procedure TMusicEditor.GridPaint(Sender: TObject);
var
  c: TCanvas;
  t, st, x, y, w: Integer;
  cw: Single;
  cell: TStepCell;
  playing: Boolean;
  col: TColor;
  r: TRect;
  s1: string;
begin
  c := FGrid.Canvas;
  c.Brush.Color := RGBToColor(14, 14, 20);
  c.FillRect(0, 0, FGrid.Width, FGrid.Height);
  if Length(S^.Patterns) = 0 then Exit;
  cw := (FGrid.Width - HEADER_W) / PAT_STEPS;
  playing := Audio.Music.Playing and (Audio.Music.Section >= 0) and (Audio.Music.Section <= High(S^.Sections))
    and (S^.Sections[Audio.Music.Section].Pattern = FPat);
  c.Font.Size := 8;
  { step header }
  for st := 0 to PAT_STEPS - 1 do
  begin
    x := HEADER_W + Round(st * cw);
    if st mod 4 = 0 then c.Font.Color := clSilver else c.Font.Color := RGBToColor(80, 80, 90);
    c.Brush.Style := bsClear;
    c.TextOut(x + 3, 4, IntToStr(st + 1));
    c.Brush.Style := bsSolid;
  end;
  for t := 0 to MAX_TRACKS - 1 do
  begin
    y := HEAD_H + t * ROW_H;
    { header }
    if t = FTrack then c.Brush.Color := RGBToColor(60, 60, 90) else c.Brush.Color := RGBToColor(32, 32, 42);
    c.FillRect(0, y, HEADER_W - 2, y + ROW_H - 2);
    c.Font.Color := clWhite;
    c.Font.Style := [fsBold];
    c.Brush.Style := bsClear;
    c.TextOut(6, y + 3, S^.Tracks[t].Name);
    c.Font.Style := [];
    c.Font.Color := clGray;
    c.TextOut(6, y + 17, Format('L%.2f', [S^.Tracks[t].IntensityMin]));
    c.Brush.Style := bsSolid;
    { M / S boxes }
    if S^.Tracks[t].Mute then c.Brush.Color := RGBToColor(200, 60, 60) else c.Brush.Color := RGBToColor(50, 50, 60);
    c.FillRect(HEADER_W - 44, y + 16, HEADER_W - 26, y + ROW_H - 4);
    if S^.Tracks[t].Solo then c.Brush.Color := RGBToColor(220, 200, 60) else c.Brush.Color := RGBToColor(50, 50, 60);
    c.FillRect(HEADER_W - 22, y + 16, HEADER_W - 4, y + ROW_H - 4);
    c.Font.Color := clWhite;
    c.Brush.Style := bsClear;
    c.TextOut(HEADER_W - 39, y + 17, 'M');
    c.TextOut(HEADER_W - 17, y + 17, 'S');
    c.Brush.Style := bsSolid;
    { cells }
    for st := 0 to PAT_STEPS - 1 do
    begin
      x := HEADER_W + Round(st * cw);
      w := Round((st + 1) * cw) - Round(st * cw) - 1;
      if st mod 4 = 0 then col := RGBToColor(30, 30, 40) else col := RGBToColor(24, 24, 32);
      if playing and (st = Audio.Music.Step) then col := RGBToColor(60, 60, 30);
      c.Brush.Color := col;
      c.FillRect(x, y, x + w, y + ROW_H - 2);
      cell := S^.Patterns[FPat].Cells[t, st];
      if cell.Note > 0 then
      begin
        r := Rect(x + 1, y + 2, Min(HEADER_W + Round((st + cell.Len) * cw) - 2, FGrid.Width - 2), y + ROW_H - 4);
        c.Brush.Color := RGBToColor(60 + cell.Vel * 20, 120 + cell.Vel * 10, 200);
        if (t = FTrack) and (st = FSelStep) then c.Brush.Color := RGBToColor(255, 220, 120);
        c.FillRect(r);
        c.Font.Color := clBlack;
        c.Brush.Style := bsClear;
        s1 := NoteName(cell.Note);
        c.TextOut(x + 3, y + 9, s1);
        c.Brush.Style := bsSolid;
      end
      else if (t = FTrack) and (st = FSelStep) then
      begin
        c.Pen.Color := RGBToColor(255, 220, 120);
        c.Brush.Style := bsClear;
        c.Rectangle(x, y, x + w, y + ROW_H - 2);
        c.Brush.Style := bsSolid;
      end;
    end;
  end;
end;

procedure TMusicEditor.EditCell(T, St, DNote, DLen, DVel: Integer);
var
  cell: TStepCell;
begin
  if (Length(S^.Patterns) = 0) or (St < 0) or (St >= PAT_STEPS) then Exit;
  Audio.Lock;
  try
    cell := S^.Patterns[FPat].Cells[T, St];
    if cell.Note = 0 then Exit;
    cell.Note := EnsureRange(cell.Note + DNote, 12, 120);
    cell.Len := EnsureRange(cell.Len + DLen, 1, PAT_STEPS);
    cell.Vel := EnsureRange(cell.Vel + DVel, 1, 9);
    S^.Patterns[FPat].Cells[T, St] := cell;
    FLastNote[T] := cell.Note;
  finally
    Audio.Unlock;
  end;
  if DNote <> 0 then PreviewLocked(T, cell.Note);
  MarkDirty;
  FGrid.Invalidate;
end;

procedure TMusicEditor.GridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  t, st: Integer;
  cell: TStepCell;
begin
  ActiveControl := nil;   { paint box cannot focus: keys reach the form (KeyPreview) }
  if not CellAt(X, Y, t, st) then Exit;
  if st < 0 then
  begin
    { header: M / S boxes or select track }
    Audio.Lock;
    try
      if (X >= HEADER_W - 44) and (X < HEADER_W - 24) and (Y - HEAD_H - t * ROW_H >= 16) then
        S^.Tracks[t].Mute := not S^.Tracks[t].Mute
      else if (X >= HEADER_W - 22) and (Y - HEAD_H - t * ROW_H >= 16) then
        S^.Tracks[t].Solo := not S^.Tracks[t].Solo;
    finally
      Audio.Unlock;
    end;
    SelectTrack(t);
    Exit;
  end;
  if Length(S^.Patterns) = 0 then Exit;
  if t <> FTrack then SelectTrack(t);
  FSelStep := st;
  cell := S^.Patterns[FPat].Cells[t, st];
  if Button = mbRight then
  begin
    Audio.Lock;
    try
      S^.Patterns[FPat].Cells[t, st] := Default(TStepCell);
    finally
      Audio.Unlock;
    end;
    MarkDirty;
  end
  else if cell.Note = 0 then
  begin
    Audio.Lock;
    try
      S^.Patterns[FPat].Cells[t, st].Note := FLastNote[t];
      S^.Patterns[FPat].Cells[t, st].Vel := 7;
      S^.Patterns[FPat].Cells[t, st].Len := 1;
    finally
      Audio.Unlock;
    end;
    PreviewLocked(t, FLastNote[t]);
    MarkDirty;
  end
  else
    PreviewLocked(t, cell.Note);
  FGrid.Invalidate;
end;

procedure TMusicEditor.GridWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var
  t, st, d: Integer;
begin
  Handled := True;
  if not CellAt(MousePos.X, MousePos.Y, t, st) then Exit;
  d := Sign(WheelDelta);
  FSelStep := st;
  if t <> FTrack then SelectTrack(t);
  if ssCtrl in Shift then EditCell(t, st, 0, d, 0)
  else if ssAlt in Shift then EditCell(t, st, 0, 0, d)
  else if ssShift in Shift then EditCell(t, st, d * 12, 0, 0)
  else EditCell(t, st, d, 0, 0);
end;

procedure TMusicEditor.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (ActiveControl is TCustomEdit) or (ActiveControl is TCustomComboBox) then Exit;
  if (Key = VK_SPACE) then begin PlayClick(nil); Key := 0; Exit; end;
  if FSelStep < 0 then Exit;
  case Key of
    VK_LEFT: FSelStep := Max(0, FSelStep - 1);
    VK_RIGHT: FSelStep := Min(PAT_STEPS - 1, FSelStep + 1);
    VK_UP: if ssShift in Shift then SelectTrack(FTrack - 1) else EditCell(FTrack, FSelStep, 1, 0, 0);
    VK_DOWN: if ssShift in Shift then SelectTrack(FTrack + 1) else EditCell(FTrack, FSelStep, -1, 0, 0);
    VK_PRIOR: EditCell(FTrack, FSelStep, 12, 0, 0);
    VK_NEXT: EditCell(FTrack, FSelStep, -12, 0, 0);
    VK_ADD, VK_OEM_PLUS: EditCell(FTrack, FSelStep, 0, 1, 0);
    VK_SUBTRACT, VK_OEM_MINUS: EditCell(FTrack, FSelStep, 0, -1, 0);
    VK_1..VK_9:
      begin
        Audio.Lock;
        try
          if S^.Patterns[FPat].Cells[FTrack, FSelStep].Note > 0 then
            S^.Patterns[FPat].Cells[FTrack, FSelStep].Vel := Key - VK_0;
        finally
          Audio.Unlock;
        end;
        MarkDirty;
      end;
    VK_DELETE:
      begin
        Audio.Lock;
        try S^.Patterns[FPat].Cells[FTrack, FSelStep] := Default(TStepCell); finally Audio.Unlock; end;
        MarkDirty;
      end;
    VK_INSERT, VK_RETURN:
      begin
        Audio.Lock;
        try
          S^.Patterns[FPat].Cells[FTrack, FSelStep].Note := FLastNote[FTrack];
          S^.Patterns[FPat].Cells[FTrack, FSelStep].Vel := 7;
          S^.Patterns[FPat].Cells[FTrack, FSelStep].Len := 1;
        finally
          Audio.Unlock;
        end;
        PreviewLocked(FTrack, FLastNote[FTrack]);
        MarkDirty;
      end;
  else
    Exit;
  end;
  Key := 0;
  FGrid.Invalidate;
end;

procedure TMusicEditor.Tick(Sender: TObject);
var
  m: TSongPlayer;
begin
  m := Audio.Music;
  m.Intensity := (FIntensity.Position - 1) / 8;
  FLblInt.Caption := 'x' + IntToStr(FIntensity.Position);
  if FChkFever.Checked then m.Fever := Min(1, m.Fever + 0.1) else m.Fever := Max(0, m.Fever - 0.1);
  if FChkMuffle.Checked then m.Muffle := Min(1, m.Muffle + 0.1) else m.Muffle := Max(0, m.Muffle - 0.1);
  if FChkSlow.Checked then m.TimeScale := Max(0.82, m.TimeScale - 0.02) else m.TimeScale := Min(1, m.TimeScale + 0.02);
  FSweep := Max(0, FSweep - 0.03);
  m.Sweep := FSweep;
  if m.Playing then
  begin
    FLblPos.Caption := m.PositionText + Format('   peak %.2f', [Audio.Peak]);
    FGrid.Invalidate;
    if (not FChkLoop.Checked) and (m.Section <> FSections.ItemIndex) and (m.Section < FSections.Count) then
      FSections.ItemIndex := m.Section;
  end
  else
    FLblPos.Caption := 'stopped';
end;

procedure TMusicEditor.SectionsClick(Sender: TObject);
begin
  SelectSection(FSections.ItemIndex);
  if Audio.Music.Playing and not FChkLoop.Checked then
  begin
    Audio.Lock;
    try Audio.Music.SeekSection(FSections.ItemIndex); finally Audio.Unlock; end;
  end;
end;

procedure TMusicEditor.SecChanged(Sender: TObject; const AKey: string);
var
  i: Integer;
begin
  MarkDirty;
  i := FSections.ItemIndex;
  RefreshSections;
  FSections.ItemIndex := i;
  if AKey = 'pattern' then
  begin
    FPat := EnsureRange(S^.Sections[i].Pattern, 0, Max(0, High(S^.Patterns)));
    FPatCombo.ItemIndex := FPat;
    FGrid.Invalidate;
  end;
end;

procedure TMusicEditor.InstChanged(Sender: TObject; const AKey: string);
begin
  MarkDirty;
  FGrid.Invalidate;
end;

procedure TMusicEditor.PatComboChange(Sender: TObject);
begin
  FPat := Max(0, FPatCombo.ItemIndex);
  FGrid.Invalidate;
end;

procedure TMusicEditor.PlayClick(Sender: TObject);
begin
  Audio.Lock;
  try
    Audio.Music.Playing := not Audio.Music.Playing;
    if Audio.Music.Playing then
      Audio.Music.SeekSection(Max(0, FSections.ItemIndex));
  finally
    Audio.Unlock;
  end;
  if Audio.Music.Playing then FBtnPlay.Caption := '  STOP  ' else FBtnPlay.Caption := '  PLAY  ';
end;

procedure TMusicEditor.LoopChange(Sender: TObject);
begin
  Audio.Lock;
  try
    if FChkLoop.Checked then Audio.Music.LoopSection := Max(0, FSections.ItemIndex)
    else Audio.Music.LoopSection := -1;
  finally
    Audio.Unlock;
  end;
end;

procedure TMusicEditor.BpmChange(Sender: TObject);
begin
  if FUpdating then Exit;
  Audio.Lock;
  try
    S^.Bpm := FBpm.Value;
    S^.Swing := FSwing.Value;
  finally
    Audio.Unlock;
  end;
  RefreshSections;
  MarkDirty;
end;

procedure TMusicEditor.BonusClick(Sender: TObject);
begin
  FSweep := 1;
  Audio.PlaySfx('pulse');
end;

procedure TMusicEditor.SaveClick(Sender: TObject);
begin
  Audio.Lock;
  try
    FData.Song := S^;
  finally
    Audio.Unlock;
  end;
  try
    FData.SaveSong;
    FDirty := False;
    Caption := StringReplace(Caption, ' *', '', []);
    FStatus.Caption := 'Saved ' + FormatDateTime('hh:nn:ss', Now) + ' -> ' + FData.SongFile;
  except
    on E: Exception do MessageDlg('Save failed: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TMusicEditor.RevertClick(Sender: TObject);
begin
  if MessageDlg('Reload the song from disk?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FData.Song := DefaultSong;
  FData.LoadSong;
  Audio.SetSong(FData.Song);
  FUpdating := True; FBpm.Value := S^.Bpm; FSwing.Value := S^.Swing; FUpdating := False;
  RefreshSections; RefreshPatterns; SelectSection(0); SelectTrack(FTrack);
  FDirty := False;
  Caption := StringReplace(Caption, ' *', '', []);
end;

procedure TMusicEditor.DefaultClick(Sender: TObject);
begin
  if MessageDlg('Replace the song with the built-in default song?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Audio.SetSong(DefaultSong);
  FUpdating := True; FBpm.Value := S^.Bpm; FSwing.Value := S^.Swing; FUpdating := False;
  RefreshSections; RefreshPatterns; SelectSection(0); SelectTrack(FTrack);
  MarkDirty;
end;

procedure TMusicEditor.ExportClick(Sender: TObject);
var
  dlg: TSaveDialog;
  eng: TAudioEngine;
  fs: TFileStream;
  frames, done, chunk, i: Integer;
  buf: TSampleBuf;
  s16: SmallInt;
  song: TSong;

  procedure W4(V: LongWord); begin fs.WriteBuffer(V, 4); end;
  procedure W2(V: Word); begin fs.WriteBuffer(V, 2); end;
  procedure Tag(const T: string); begin fs.WriteBuffer(T[1], 4); end;

begin
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter := 'WAV audio|*.wav';
    dlg.DefaultExt := 'wav';
    dlg.FileName := S^.Name + '.wav';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if not dlg.Execute then Exit;
    Audio.Lock;
    try song := S^; finally Audio.Unlock; end;
    frames := FExportSecs.Value * SAMPLE_RATE;
    eng := TAudioEngine.Create;
    fs := TFileStream.Create(dlg.FileName, fmCreate);
    Screen.Cursor := crHourGlass;
    try
      eng.SetSong(song);
      eng.Music.Playing := True;
      eng.Music.SeekSection(0);
      eng.Music.Intensity := (FIntensity.Position - 1) / 8;
      eng.MusicVolume := 1;
      Tag('RIFF'); W4(36 + frames * 4); Tag('WAVE');
      Tag('fmt '); W4(16); W2(1); W2(2); W4(SAMPLE_RATE); W4(SAMPLE_RATE * 4); W2(4); W2(16);
      Tag('data'); W4(frames * 4);
      done := 0;
      while done < frames do
      begin
        chunk := Min(SAMPLE_RATE, frames - done);
        buf := eng.RenderOffline(chunk);
        for i := 0 to High(buf) do
        begin
          s16 := Round(EnsureRange(buf[i], -1, 1) * 32767);
          fs.WriteBuffer(s16, 2);
        end;
        Inc(done, chunk);
        FStatus.Caption := Format('Exporting %d%%', [done * 100 div frames]);
        Application.ProcessMessages;
      end;
      FStatus.Caption := 'Exported ' + ExtractFileName(dlg.FileName);
    finally
      Screen.Cursor := crDefault;
      fs.Free;
      eng.Free;
    end;
  finally
    dlg.Free;
  end;
end;

procedure TMusicEditor.SecAdd(Sender: TObject);
var
  n: Integer;
begin
  Audio.Lock;
  try
    n := Length(S^.Sections);
    SetLength(S^.Sections, n + 1);
    S^.Sections[n] := Default(TSection);
    S^.Sections[n].Name := 'Section ' + IntToStr(n + 1);
    S^.Sections[n].Pattern := FPat;
    S^.Sections[n].Repeats := 4;
    S^.Sections[n].Progression := '0 -4 3 -2';
    S^.Sections[n].Energy := 0.5;
  finally
    Audio.Unlock;
  end;
  RefreshSections;
  SelectSection(n);
  MarkDirty;
end;

procedure TMusicEditor.SecDup(Sender: TObject);
var
  i, j: Integer;
begin
  i := FSections.ItemIndex;
  if i < 0 then Exit;
  Audio.Lock;
  try
    SetLength(S^.Sections, Length(S^.Sections) + 1);
    for j := High(S^.Sections) downto i + 2 do S^.Sections[j] := S^.Sections[j - 1];
    S^.Sections[i + 1] := S^.Sections[i];
  finally
    Audio.Unlock;
  end;
  RefreshSections;
  SelectSection(i + 1);
  MarkDirty;
end;

procedure TMusicEditor.SecDel(Sender: TObject);
var
  i, j: Integer;
begin
  i := FSections.ItemIndex;
  if (i < 0) or (Length(S^.Sections) <= 1) then Exit;
  Audio.Lock;
  try
    for j := i to High(S^.Sections) - 1 do S^.Sections[j] := S^.Sections[j + 1];
    SetLength(S^.Sections, Length(S^.Sections) - 1);
    Audio.Music.SeekSection(0);
  finally
    Audio.Unlock;
  end;
  RefreshSections;
  SelectSection(Min(i, High(S^.Sections)));
  MarkDirty;
end;

procedure TMusicEditor.SecUp(Sender: TObject);
var
  i: Integer;
  t: TSection;
begin
  i := FSections.ItemIndex;
  if i <= 0 then Exit;
  Audio.Lock;
  try
    t := S^.Sections[i]; S^.Sections[i] := S^.Sections[i - 1]; S^.Sections[i - 1] := t;
  finally
    Audio.Unlock;
  end;
  RefreshSections;
  SelectSection(i - 1);
  MarkDirty;
end;

procedure TMusicEditor.SecDown(Sender: TObject);
var
  i: Integer;
  t: TSection;
begin
  i := FSections.ItemIndex;
  if (i < 0) or (i >= High(S^.Sections)) then Exit;
  Audio.Lock;
  try
    t := S^.Sections[i]; S^.Sections[i] := S^.Sections[i + 1]; S^.Sections[i + 1] := t;
  finally
    Audio.Unlock;
  end;
  RefreshSections;
  SelectSection(i + 1);
  MarkDirty;
end;

procedure TMusicEditor.PatNew(Sender: TObject);
var
  n: Integer;
begin
  Audio.Lock;
  try
    n := Length(S^.Patterns);
    SetLength(S^.Patterns, n + 1);
    S^.Patterns[n] := Default(TPattern);
    S^.Patterns[n].Name := 'Pattern ' + IntToStr(n);
  finally
    Audio.Unlock;
  end;
  FPat := n;
  RefreshPatterns;
  FGrid.Invalidate;
  MarkDirty;
end;

procedure TMusicEditor.PatDup(Sender: TObject);
var
  n: Integer;
begin
  if Length(S^.Patterns) = 0 then Exit;
  Audio.Lock;
  try
    n := Length(S^.Patterns);
    SetLength(S^.Patterns, n + 1);
    S^.Patterns[n] := S^.Patterns[FPat];
    S^.Patterns[n].Name := S^.Patterns[FPat].Name + ' copy';
  finally
    Audio.Unlock;
  end;
  FPat := n;
  RefreshPatterns;
  FGrid.Invalidate;
  MarkDirty;
end;

procedure TMusicEditor.PatRename(Sender: TObject);
var
  s1: string;
begin
  if Length(S^.Patterns) = 0 then Exit;
  s1 := S^.Patterns[FPat].Name;
  if not InputQuery('Rename pattern', 'Name', s1) then Exit;
  Audio.Lock;
  try S^.Patterns[FPat].Name := s1; finally Audio.Unlock; end;
  RefreshPatterns;
  RefreshSections;
  MarkDirty;
end;

procedure TMusicEditor.PatClear(Sender: TObject);
var
  st: Integer;
begin
  if Length(S^.Patterns) = 0 then Exit;
  if MessageDlg('Clear track "' + S^.Tracks[FTrack].Name + '" in this pattern?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Audio.Lock;
  try
    for st := 0 to PAT_STEPS - 1 do S^.Patterns[FPat].Cells[FTrack, st] := Default(TStepCell);
  finally
    Audio.Unlock;
  end;
  FGrid.Invalidate;
  MarkDirty;
end;

procedure TMusicEditor.PreviewLocked(T, ANote: Integer);
begin
  Audio.Lock;
  try
    Audio.Music.PreviewNote(T, ANote);
  finally
    Audio.Unlock;
  end;
end;

procedure TMusicEditor.PreviewClick(Sender: TObject);
begin
  PreviewLocked(FTrack, FLastNote[FTrack]);
end;

procedure TMusicEditor.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FDirty then
    case MessageDlg('Save the song before closing?', mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrYes: SaveClick(nil);
      mrCancel: begin CanClose := False; Exit; end;
    end;
  Audio.Lock;
  try
    Audio.Music.Playing := False;
    Audio.Music.LoopSection := -1;
    Audio.Music.Intensity := 0; Audio.Music.Fever := 0; Audio.Music.Muffle := 0;
    Audio.Music.TimeScale := 1; Audio.Music.Sweep := 0;
  finally
    Audio.Unlock;
  end;
end;

end.

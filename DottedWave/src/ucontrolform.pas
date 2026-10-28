{ Dotted Wave Mesh - separate control window: every parameter + export tools }
unit uControlForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ComCtrls, Spin, LCLType, LCLIntf, Clipbrd,
  BGRABitmap, BGRABitmapTypes, uWaveTypes, uWaveEngine;

type

  TParamRow = record
    Track: TTrackBar;
    Spin: TFloatSpinEdit;
  end;

  { TControlForm }

  TControlForm = class(TForm)
  private
    FUpdating: Boolean;
    FCancel: Boolean;
    FRows: array[TWaveParam] of TParamRow;
    FScroll: TScrollBox;
    FPreset: TComboBox;
    FChkPause, FChkVSync, FChkFps, FChkTop: TCheckBox;
    FBgBtn, FDotBtn: TColorButton;
    FSizePreset: TComboBox;
    FExpW, FExpH, FFrames, FFps: TSpinEdit;
    FProgress: TProgressBar;
    FStatus: TLabel;
    FBtnCancel: TButton;
    FTimer: TTimer;
    function AddGroup(const ACaption: string): TGroupBox;
    function AddButton(AParent: TWinControl; const ACaption: string; AOnClick: TNotifyEvent): TButton;
    function AddRowPanel(AParent: TWinControl; AHeight: Integer): TPanel;
    procedure BuildUI;
    procedure BuildParamRow(AParent: TWinControl; P: TWaveParam);
    procedure TrackChange(Sender: TObject);
    procedure SpinChange(Sender: TObject);
    procedure ColorChanged(Sender: TObject);
    procedure FlagChanged(Sender: TObject);
    procedure PresetChange(Sender: TObject);
    procedure SizePresetChange(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure ExportPngClick(Sender: TObject);
    procedure ExportSeqClick(Sender: TObject);
    procedure SaveIniClick(Sender: TObject);
    procedure LoadIniClick(Sender: TObject);
    procedure ExportJsonClick(Sender: TObject);
    procedure ExportPasClick(Sender: TObject);
    procedure CopyJsonClick(Sender: TObject);
    procedure ExportPackClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure SetStatus(const S: string);
    function RenderFrame(AW, AH: Integer; APhase: Double): TBGRABitmap;
    function PickDir(const ATitle: string; out ADir: string): Boolean;
    procedure WriteText(const AFileName, AText: string);
  public
    constructor Create(TheOwner: TComponent); override;
    procedure SyncFromConfig;
  end;

var
  ControlForm: TControlForm = nil;

implementation

uses
  uMainForm;

const
  ROW_H = 26;
  SizePresets: array[0..6] of record Name: string; W, H: Integer; end = (
    (Name: 'Original 736 x 1431';          W: 736;  H: 1431),
    (Name: 'Original x2  1472 x 2862';     W: 1472; H: 2862),
    (Name: 'Phone 1080 x 2340';            W: 1080; H: 2340),
    (Name: 'Phone 1290 x 2796';            W: 1290; H: 2796),
    (Name: 'Full HD 1920 x 1080';          W: 1920; H: 1080),
    (Name: '4K UHD 3840 x 2160';           W: 3840; H: 2160),
    (Name: 'Square 2048 x 2048';           W: 2048; H: 2048));

function ToBGRA(c: TColor): TBGRAPixel;
begin
  c := ColorToRGB(c);
  Result := BGRA(Red(c), Green(c), Blue(c), 255);
end;

function ToTColor(const p: TBGRAPixel): TColor;
begin
  Result := RGBToColor(p.red, p.green, p.blue);
end;

{ TControlForm }

constructor TControlForm.Create(TheOwner: TComponent);
begin
  inherited CreateNew(TheOwner);
  Caption := APP_NAME + ' - Controls & Export';
  BorderStyle := bsSizeToolWin;
  Width := 400;
  Height := Min(860, Screen.WorkAreaHeight - 40);
  if Assigned(MainForm) then
  begin
    Left := Min(MainForm.Left + MainForm.Width + 8, Screen.WorkAreaWidth - Width);
    Top := Max(0, MainForm.Top);
  end;
  KeyPreview := True;
  BuildUI;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 500;
  FTimer.OnTimer := @TimerTick;
  SyncFromConfig;
end;

function TControlForm.AddRowPanel(AParent: TWinControl; AHeight: Integer): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.Parent := AParent;
  Result.BevelOuter := bvNone;
  Result.Height := AHeight;
  Result.Top := AParent.ControlCount * 1000;   { keep insertion order with alTop }
  Result.Align := alTop;
  Result.BorderSpacing.Around := 2;
end;

function TControlForm.AddGroup(const ACaption: string): TGroupBox;
begin
  Result := TGroupBox.Create(Self);
  Result.Parent := FScroll;
  Result.Caption := ACaption;
  Result.Top := FScroll.ControlCount * 1000;
  Result.Align := alTop;
  Result.AutoSize := True;
  Result.BorderSpacing.Around := 4;
  Result.ChildSizing.TopBottomSpacing := 2;
end;

function TControlForm.AddButton(AParent: TWinControl; const ACaption: string; AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.Left := AParent.ControlCount * 1000;   { keep insertion order with alLeft }
  Result.OnClick := AOnClick;
  Result.AutoSize := False;
  Result.Height := ROW_H;
end;

procedure TControlForm.BuildParamRow(AParent: TWinControl; P: TWaveParam);
var
  row: TPanel;
  lbl: TLabel;
  d: TWaveParamDef;
begin
  d := ParamDefs[P];
  row := AddRowPanel(AParent, ROW_H);

  lbl := TLabel.Create(Self);
  lbl.Parent := row;
  lbl.Align := alLeft;
  lbl.AutoSize := False;
  lbl.Width := 112;
  lbl.Layout := tlCenter;
  lbl.Caption := d.Caption;
  lbl.Hint := d.Hint + LineEnding + Format('[%s] min %s  max %s  default %s',
    [d.Key, FloatToInv(d.MinV, d.Decimals), FloatToInv(d.MaxV, d.Decimals), FloatToInv(d.DefV, d.Decimals)]);
  lbl.ShowHint := True;

  FRows[P].Spin := TFloatSpinEdit.Create(Self);
  with FRows[P].Spin do
  begin
    Parent := row;
    Align := alRight;
    Width := 78;
    DecimalPlaces := d.Decimals;
    MinValue := d.MinV;
    MaxValue := d.MaxV;
    Increment := Power(10, -d.Decimals);
    Tag := Ord(P);
    Hint := lbl.Hint;
    ShowHint := True;
    OnChange := @SpinChange;
  end;

  FRows[P].Track := TTrackBar.Create(Self);
  with FRows[P].Track do
  begin
    Parent := row;
    Align := alClient;
    Min := 0;
    Max := 1000;
    TickStyle := tsNone;
    PageSize := 50;
    Tag := Ord(P);
    Hint := lbl.Hint;
    ShowHint := True;
    OnChange := @TrackChange;
  end;
end;

procedure TControlForm.BuildUI;
var
  pTop, pBottom: TPanel;
  g: TWaveParamGroup;
  p: TWaveParam;
  gb: TGroupBox;
  row: TPanel;
  lbl: TLabel;
  i: Integer;

  function MakeCheck(AParent: TWinControl; const ACaption: string): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.Left := AParent.ControlCount * 1000;
    Result.Align := alLeft;
    Result.BorderSpacing.Right := 10;
    Result.OnChange := @FlagChanged;
  end;

  function MakeSpin(AParent: TWinControl; AMin, AMax, AVal: Integer): TSpinEdit;
  begin
    Result := TSpinEdit.Create(Self);
    Result.Parent := AParent;
    Result.MinValue := AMin;
    Result.MaxValue := AMax;
    Result.Value := AVal;
    Result.Width := 70;
    Result.Left := AParent.ControlCount * 1000;
    Result.Align := alLeft;
    Result.BorderSpacing.Right := 6;
  end;

  function MakeLabel(AParent: TWinControl; const ACaption: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.Left := AParent.ControlCount * 1000;
    Result.Align := alLeft;
    Result.Layout := tlCenter;
    Result.BorderSpacing.Right := 4;
  end;

begin
  { --- top bar: preset + flags --- }
  pTop := TPanel.Create(Self);
  pTop.Parent := Self;
  pTop.Align := alTop;
  pTop.BevelOuter := bvNone;
  pTop.AutoSize := True;

  row := AddRowPanel(pTop, ROW_H);
  MakeLabel(row, 'Preset');
  FPreset := TComboBox.Create(Self);
  FPreset.Parent := row;
  FPreset.Style := csDropDownList;
  for i := Low(PresetNames) to High(PresetNames) do
    FPreset.Items.Add(PresetNames[i]);
  FPreset.ItemIndex := 0;
  FPreset.Align := alClient;
  FPreset.OnChange := @PresetChange;
  with AddButton(row, 'Reset', @ResetClick) do
  begin
    Align := alRight;
    Width := 60;
    BorderSpacing.Left := 4;
  end;

  row := AddRowPanel(pTop, ROW_H);
  FChkPause := MakeCheck(row, 'Pause');
  FChkVSync := MakeCheck(row, 'VSync');
  FChkFps := MakeCheck(row, 'FPS');
  FChkTop := MakeCheck(row, 'On top');

  { --- bottom: export --- }
  pBottom := TPanel.Create(Self);
  pBottom.Parent := Self;
  pBottom.Align := alBottom;
  pBottom.BevelOuter := bvNone;
  pBottom.AutoSize := True;

  gb := TGroupBox.Create(Self);
  gb.Parent := pBottom;
  gb.Top := 0;
  gb.Caption := 'Export';
  gb.Align := alTop;
  gb.AutoSize := True;
  gb.BorderSpacing.Around := 4;

  row := AddRowPanel(gb, ROW_H);
  MakeLabel(row, 'Size');
  FSizePreset := TComboBox.Create(Self);
  FSizePreset.Parent := row;
  FSizePreset.Style := csDropDownList;
  for i := Low(SizePresets) to High(SizePresets) do
    FSizePreset.Items.Add(SizePresets[i].Name);
  FSizePreset.ItemIndex := 0;
  FSizePreset.Align := alClient;
  FSizePreset.OnChange := @SizePresetChange;

  row := AddRowPanel(gb, ROW_H);
  MakeLabel(row, 'W');
  FExpW := MakeSpin(row, 16, 8192, REF_WIDTH);
  MakeLabel(row, 'H');
  FExpH := MakeSpin(row, 16, 8192, REF_HEIGHT);
  with AddButton(row, 'Export PNG', @ExportPngClick) do
    Align := alClient;

  row := AddRowPanel(gb, ROW_H);
  MakeLabel(row, 'Frames');
  FFrames := MakeSpin(row, 1, 10000, 120);
  MakeLabel(row, 'FPS');
  FFps := MakeSpin(row, 1, 240, 30);
  FFps.Width := 50;
  with AddButton(row, 'PNG Sequence', @ExportSeqClick) do
    Align := alClient;

  row := AddRowPanel(gb, ROW_H);
  with AddButton(row, 'Save .ini', @SaveIniClick) do begin Align := alLeft; Width := 88; end;
  with AddButton(row, 'Load .ini', @LoadIniClick) do begin Align := alLeft; Width := 88; BorderSpacing.Left := 2; end;
  with AddButton(row, 'JSON spec', @ExportJsonClick) do begin Align := alLeft; Width := 88; BorderSpacing.Left := 2; end;
  with AddButton(row, 'Pascal .inc', @ExportPasClick) do begin Align := alClient; BorderSpacing.Left := 2; end;

  row := AddRowPanel(gb, ROW_H);
  with AddButton(row, 'Copy JSON', @CopyJsonClick) do begin Align := alLeft; Width := 88; end;
  with AddButton(row, 'Export Dev Pack (PNG + INI + JSON + INC + MD)', @ExportPackClick) do
  begin
    Align := alClient;
    BorderSpacing.Left := 2;
    Font.Style := [fsBold];
  end;

  row := AddRowPanel(gb, 20);
  FBtnCancel := AddButton(row, 'Cancel', @CancelClick);
  FBtnCancel.Align := alRight;
  FBtnCancel.Width := 60;
  FBtnCancel.Enabled := False;
  FProgress := TProgressBar.Create(Self);
  FProgress.Parent := row;
  FProgress.Align := alClient;
  FProgress.BorderSpacing.Right := 4;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := pBottom;
  FStatus.Top := 5000;
  FStatus.Align := alTop;
  FStatus.BorderSpacing.Around := 4;
  FStatus.Caption := 'F1/Tab: toggle  Space: pause  F11: fullscreen  Ctrl+S: quick PNG';

  { --- middle: parameter groups --- }
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FScroll.HorzScrollBar.Visible := False;
  FScroll.VertScrollBar.Tracking := True;

  for g := Low(TWaveParamGroup) to High(TWaveParamGroup) do
  begin
    gb := AddGroup(GroupNames[g]);
    if g = pgColor then
    begin
      row := AddRowPanel(gb, ROW_H);
      lbl := MakeLabel(row, 'Background');
      lbl.AutoSize := False; lbl.Width := 112;
      FBgBtn := TColorButton.Create(Self);
      FBgBtn.Parent := row;
      FBgBtn.Left := row.ControlCount * 1000;
      FBgBtn.Align := alLeft;
      FBgBtn.Width := 70;
      FBgBtn.OnColorChanged := @ColorChanged;
      lbl := MakeLabel(row, '  Dots');
      FDotBtn := TColorButton.Create(Self);
      FDotBtn.Parent := row;
      FDotBtn.Left := row.ControlCount * 1000;
      FDotBtn.Align := alLeft;
      FDotBtn.Width := 70;
      FDotBtn.OnColorChanged := @ColorChanged;
    end;
    for p := Low(TWaveParam) to High(TWaveParam) do
      if ParamDefs[p].Group = g then
        BuildParamRow(gb, p);
  end;
end;

procedure TControlForm.SyncFromConfig;
var
  p: TWaveParam;
  d: TWaveParamDef;
  v: Single;
begin
  if not Assigned(MainForm) then Exit;
  FUpdating := True;
  try
    for p := Low(TWaveParam) to High(TWaveParam) do
    begin
      d := ParamDefs[p];
      v := MainForm.Config.Values[p];
      FRows[p].Spin.Value := v;
      FRows[p].Track.Position := Round((v - d.MinV) / (d.MaxV - d.MinV) * 1000);
    end;
    FBgBtn.ButtonColor := ToTColor(MainForm.Config.BgColor);
    FDotBtn.ButtonColor := ToTColor(MainForm.Config.DotColor);
    FChkPause.Checked := MainForm.Config.Paused;
    FChkVSync.Checked := MainForm.Config.VSync;
    FChkFps.Checked := MainForm.Config.ShowFPS;
  finally
    FUpdating := False;
  end;
end;

procedure TControlForm.TrackChange(Sender: TObject);
var
  p: TWaveParam;
  d: TWaveParamDef;
  v: Single;
begin
  if FUpdating then Exit;
  p := TWaveParam(TTrackBar(Sender).Tag);
  d := ParamDefs[p];
  v := ClampParam(p, d.MinV + TTrackBar(Sender).Position / 1000 * (d.MaxV - d.MinV));
  v := RoundTo(v, -d.Decimals);
  MainForm.Config.Values[p] := v;
  FUpdating := True;
  try
    FRows[p].Spin.Value := v;
  finally
    FUpdating := False;
  end;
end;

procedure TControlForm.SpinChange(Sender: TObject);
var
  p: TWaveParam;
  d: TWaveParamDef;
  v: Single;
begin
  if FUpdating then Exit;
  p := TWaveParam(TFloatSpinEdit(Sender).Tag);
  d := ParamDefs[p];
  v := ClampParam(p, TFloatSpinEdit(Sender).Value);
  MainForm.Config.Values[p] := v;
  FUpdating := True;
  try
    FRows[p].Track.Position := Round((v - d.MinV) / (d.MaxV - d.MinV) * 1000);
  finally
    FUpdating := False;
  end;
end;

procedure TControlForm.ColorChanged(Sender: TObject);
begin
  if FUpdating then Exit;
  MainForm.Config.BgColor := ToBGRA(FBgBtn.ButtonColor);
  MainForm.Config.DotColor := ToBGRA(FDotBtn.ButtonColor);
end;

procedure TControlForm.FlagChanged(Sender: TObject);
begin
  if Sender = FChkTop then
  begin
    if FChkTop.Checked then FormStyle := fsStayOnTop else FormStyle := fsNormal;
    Exit;
  end;
  if FUpdating then Exit;
  MainForm.Config.Paused := FChkPause.Checked;
  MainForm.Config.VSync := FChkVSync.Checked;
  MainForm.Config.ShowFPS := FChkFps.Checked;
end;

procedure TControlForm.PresetChange(Sender: TObject);
var
  keep: TWaveConfig;
begin
  if FPreset.ItemIndex < 0 then Exit;
  keep := MainForm.Config;
  MainForm.Config := PresetConfig(FPreset.ItemIndex);
  MainForm.Config.VSync := keep.VSync;
  MainForm.Config.ShowFPS := keep.ShowFPS;
  MainForm.Config.Paused := keep.Paused;
  SyncFromConfig;
  SetStatus('Preset: ' + FPreset.Text);
end;

procedure TControlForm.ResetClick(Sender: TObject);
begin
  FPreset.ItemIndex := 0;
  PresetChange(nil);
  MainForm.Phase := 0;
end;

procedure TControlForm.SizePresetChange(Sender: TObject);
begin
  if FSizePreset.ItemIndex < 0 then Exit;
  FExpW.Value := SizePresets[FSizePreset.ItemIndex].W;
  FExpH.Value := SizePresets[FSizePreset.ItemIndex].H;
end;

procedure TControlForm.SetStatus(const S: string);
begin
  FStatus.Caption := S;
end;

procedure TControlForm.TimerTick(Sender: TObject);
begin
  if Visible and not FBtnCancel.Enabled then
    Caption := Format('%s - Controls  [%.0f fps, %d dots, %.1f ms]',
      [APP_NAME, MainForm.Fps, MainForm.Engine.DotCount, MainForm.Engine.RenderMs]);
end;

function TControlForm.RenderFrame(AW, AH: Integer; APhase: Double): TBGRABitmap;
var
  eng: TWaveEngine;
begin
  Result := TBGRABitmap.Create(AW, AH);
  eng := TWaveEngine.Create;   { separate instance: never shares buffers with the live view }
  try
    eng.Render(Result, MainForm.Config, APhase, 0);
  finally
    eng.Free;
  end;
end;

function TControlForm.PickDir(const ATitle: string; out ADir: string): Boolean;
var
  dlg: TSelectDirectoryDialog;
begin
  dlg := TSelectDirectoryDialog.Create(Self);
  try
    dlg.Title := ATitle;
    dlg.Options := dlg.Options + [ofCreatePrompt];
    Result := dlg.Execute;
    if Result then ADir := IncludeTrailingPathDelimiter(dlg.FileName);
  finally
    dlg.Free;
  end;
end;

procedure TControlForm.WriteText(const AFileName, AText: string);
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Text := AText;
    sl.WriteBOM := False;
    sl.SaveToFile(AFileName);
  finally
    sl.Free;
  end;
end;

procedure TControlForm.ExportPngClick(Sender: TObject);
var
  dlg: TSaveDialog;
  bmp: TBGRABitmap;
begin
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter := 'PNG image|*.png';
    dlg.DefaultExt := 'png';
    dlg.FileName := Format('dottedwave_%dx%d.png', [FExpW.Value, FExpH.Value]);
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if not dlg.Execute then Exit;
    Screen.Cursor := crHourGlass;
    try
      bmp := RenderFrame(FExpW.Value, FExpH.Value, MainForm.Phase);
      try
        bmp.SaveToFile(dlg.FileName);
      finally
        bmp.Free;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
    SetStatus('Saved ' + ExtractFileName(dlg.FileName));
  finally
    dlg.Free;
  end;
end;

procedure TControlForm.ExportSeqClick(Sender: TObject);
var
  dir: string;
  i, n, fps: Integer;
  ph0: Double;
  bmp: TBGRABitmap;
begin
  if not PickDir('Folder for PNG sequence', dir) then Exit;
  n := FFrames.Value;
  fps := FFps.Value;
  ph0 := MainForm.Phase;
  FCancel := False;
  FBtnCancel.Enabled := True;
  FProgress.Max := n;
  try
    for i := 0 to n - 1 do
    begin
      bmp := RenderFrame(FExpW.Value, FExpH.Value, ph0 + i / fps * MainForm.Config.Values[wpSpeed]);
      try
        bmp.SaveToFile(dir + Format('frame_%.5d.png', [i]));
      finally
        bmp.Free;
      end;
      FProgress.Position := i + 1;
      SetStatus(Format('Frame %d / %d', [i + 1, n]));
      Application.ProcessMessages;
      if FCancel then Break;
    end;
    WriteText(dir + 'sequence.json', Format(
      '{ "frames": %d, "fps": %d, "width": %d, "height": %d, "pattern": "frame_%%05d.png",' + LineEnding +
      '  "ffmpeg": "ffmpeg -framerate %d -i frame_%%05d.png -c:v libx264 -pix_fmt yuv420p -crf 16 dottedwave.mp4" }',
      [FProgress.Position, fps, FExpW.Value, FExpH.Value, fps]));
    WriteText(dir + 'config.json', ConfigToJSON(MainForm.Config));
    if FCancel then SetStatus('Cancelled at frame ' + IntToStr(FProgress.Position))
    else SetStatus('Sequence done: ' + dir);
  finally
    FBtnCancel.Enabled := False;
  end;
end;

procedure TControlForm.CancelClick(Sender: TObject);
begin
  FCancel := True;
end;

procedure TControlForm.SaveIniClick(Sender: TObject);
var
  dlg: TSaveDialog;
begin
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter := 'Config|*.ini';
    dlg.DefaultExt := 'ini';
    dlg.FileName := 'dottedwave_preset.ini';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if dlg.Execute then
    begin
      SaveConfigIni(MainForm.Config, dlg.FileName);
      SetStatus('Saved ' + ExtractFileName(dlg.FileName));
    end;
  finally
    dlg.Free;
  end;
end;

procedure TControlForm.LoadIniClick(Sender: TObject);
var
  dlg: TOpenDialog;
begin
  dlg := TOpenDialog.Create(Self);
  try
    dlg.Filter := 'Config|*.ini';
    if dlg.Execute then
    begin
      MainForm.Config := LoadConfigIni(dlg.FileName, MainForm.Config);
      SyncFromConfig;
      SetStatus('Loaded ' + ExtractFileName(dlg.FileName));
    end;
  finally
    dlg.Free;
  end;
end;

procedure TControlForm.ExportJsonClick(Sender: TObject);
var
  dlg: TSaveDialog;
begin
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter := 'JSON|*.json';
    dlg.DefaultExt := 'json';
    dlg.FileName := 'dottedwave_spec.json';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if dlg.Execute then
    begin
      WriteText(dlg.FileName, ConfigToJSON(MainForm.Config));
      SetStatus('Saved ' + ExtractFileName(dlg.FileName));
    end;
  finally
    dlg.Free;
  end;
end;

procedure TControlForm.ExportPasClick(Sender: TObject);
var
  dlg: TSaveDialog;
begin
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter := 'Pascal include|*.inc';
    dlg.DefaultExt := 'inc';
    dlg.FileName := 'dottedwave_preset.inc';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if dlg.Execute then
    begin
      WriteText(dlg.FileName, ConfigToPascal(MainForm.Config));
      SetStatus('Saved ' + ExtractFileName(dlg.FileName));
    end;
  finally
    dlg.Free;
  end;
end;

procedure TControlForm.CopyJsonClick(Sender: TObject);
begin
  Clipboard.AsText := ConfigToJSON(MainForm.Config);
  SetStatus('JSON spec copied to clipboard');
end;

procedure TControlForm.ExportPackClick(Sender: TObject);
var
  dir, md: string;
  bmp: TBGRABitmap;
  p: TWaveParam;
  g: TWaveParamGroup;
begin
  if not PickDir('Folder for Dev Pack', dir) then Exit;
  dir := dir + 'DottedWave_DevPack_' + FormatDateTime('yyyymmdd_hhnnss', Now) + PathDelim;
  ForceDirectories(dir);
  Screen.Cursor := crHourGlass;
  try
    bmp := RenderFrame(REF_WIDTH, REF_HEIGHT, MainForm.Phase);
    try bmp.SaveToFile(dir + 'preview_736x1431.png'); finally bmp.Free; end;
    bmp := RenderFrame(REF_WIDTH * 2, REF_HEIGHT * 2, MainForm.Phase);
    try bmp.SaveToFile(dir + 'preview_1472x2862@2x.png'); finally bmp.Free; end;
    bmp := RenderFrame(1920, 1080, MainForm.Phase);
    try bmp.SaveToFile(dir + 'preview_1920x1080.png'); finally bmp.Free; end;

    SaveConfigIni(MainForm.Config, dir + 'config.ini');
    WriteText(dir + 'spec.json', ConfigToJSON(MainForm.Config));
    WriteText(dir + 'preset.inc', ConfigToPascal(MainForm.Config));

    md := '# ' + APP_NAME + ' - Dev Pack' + LineEnding + LineEnding +
      'Generated: ' + FormatDateTime('yyyy-mm-dd hh:nn', Now) + LineEnding + LineEnding +
      '| File | Purpose |' + LineEnding + '|---|---|' + LineEnding +
      '| preview_*.png | Rendered previews (same phase) |' + LineEnding +
      '| config.ini | Load in app: Controls > Load .ini |' + LineEnding +
      '| spec.json | Full UI spec: values, ranges, defaults, descriptions |' + LineEnding +
      '| preset.inc | `{$I preset.inc}` then `ApplyWavePreset(Config)` |' + LineEnding + LineEnding +
      '## Colors' + LineEnding + LineEnding +
      '- Background: `' + ColorToHex(MainForm.Config.BgColor) + '`' + LineEnding +
      '- Dots: `' + ColorToHex(MainForm.Config.DotColor) + '`' + LineEnding + LineEnding +
      '## Parameters (reference canvas ' + IntToStr(REF_WIDTH) + 'x' + IntToStr(REF_HEIGHT) + ')' + LineEnding;
    for g := Low(TWaveParamGroup) to High(TWaveParamGroup) do
    begin
      md := md + LineEnding + '### ' + GroupNames[g] + LineEnding + LineEnding +
        '| Key | Value | Default | Range | Description |' + LineEnding + '|---|---|---|---|---|' + LineEnding;
      for p := Low(TWaveParam) to High(TWaveParam) do
        if ParamDefs[p].Group = g then
          md := md + Format('| `%s` | %s | %s | %s - %s | %s |',
            [ParamDefs[p].Key,
             FloatToInv(MainForm.Config.Values[p], ParamDefs[p].Decimals),
             FloatToInv(ParamDefs[p].DefV, ParamDefs[p].Decimals),
             FloatToInv(ParamDefs[p].MinV, ParamDefs[p].Decimals),
             FloatToInv(ParamDefs[p].MaxV, ParamDefs[p].Decimals),
             ParamDefs[p].Hint]) + LineEnding;
    end;
    WriteText(dir + 'README.md', md);
  finally
    Screen.Cursor := crDefault;
  end;
  SetStatus('Dev Pack: ' + dir);
  OpenDocument(dir);
end;

end.

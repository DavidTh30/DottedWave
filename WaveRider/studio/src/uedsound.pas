{ Sound effect editor: two-layer synth (A = character, B = bass / sub layer)
  with waveform view, loudness + bass meter, templates, randomize / mutate,
  pitch test buttons and WAV export. }
unit uEdSound;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs, LCLType,
  uParams, uSynth, uGameData, uAudio, uEdBase;

type

  { TSoundEditor }

  TSoundEditor = class(TListEditor)
  private
    FBar, FBar2: TPanel;
    FWave: TPaintBox;
    FInfo: TLabel;
    FAuto: TCheckBox;
    FTemplate: TComboBox;
    FPending: Boolean;
    FTimer: TTimer;
    FSamples: TSampleBuf;
    FPlayStart: QWord;
    FPlaying: Boolean;
    procedure WavePaint(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure PlayClick(Sender: TObject);
    procedure PitchClick(Sender: TObject);
    procedure ApplyTemplateClick(Sender: TObject);
    procedure RandomizeClick(Sender: TObject);
    procedure MutateClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Rebuild(APlay: Boolean);
    procedure SyncAudioBank;
    function Btn(AParent: TPanel; const ACaption: string; AOnClick: TNotifyEvent): TButton;
  protected
    function ItemCount: Integer; override;
    function ItemName(I: Integer): string; override;
    procedure DescribeItem(I: Integer; var B: TPBuilder); override;
    procedure AddItem; override;
    procedure DupItem(I: Integer); override;
    procedure DelItem(I: Integer); override;
    procedure SwapItems(A, B: Integer); override;
    procedure SaveData; override;
    procedure RevertData; override;
    procedure DefaultsData; override;
    procedure ItemSelected(I: Integer); override;
    procedure ParamChanged(const AKey: string); override;
  public
    constructor Create(AOwner: TComponent; AData: TGameData); reintroduce;
  end;

implementation

const
  TEMPLATES = 'Kick 808|Sub drop|Heavy hit|Wobble bass|Laser|Pickup|8-bit coin|Power up|Explosion|Riser|Glitch blip';

{ TSoundEditor }

constructor TSoundEditor.Create(AOwner: TComponent; AData: TGameData);
var
  sl: TStringList;
  b: TButton;
begin
  inherited CreateEditor(AOwner, AData, 'Sound FX', True);
  OnKeyDown := @FormKeyDown;

  FBar := TPanel.Create(Self);
  FBar.Parent := FRight;
  FBar.Align := alTop;
  FBar.Height := 34;
  FBar.BevelOuter := bvNone;
  b := Btn(FBar, '  PLAY  (Space)  ', @PlayClick);
  b.Font.Style := [fsBold];
  FAuto := TCheckBox.Create(Self);
  FAuto.Parent := FBar;
  FAuto.Caption := 'Auto-play on change';
  FAuto.Checked := True;
  FAuto.Left := FBar.ControlCount * 1000;
  FAuto.Align := alLeft;
  FAuto.BorderSpacing.Left := 8;
  Btn(FBar, 'Randomize', @RandomizeClick);
  Btn(FBar, 'Mutate', @MutateClick);
  Btn(FBar, 'Export WAV', @ExportClick);

  FBar2 := TPanel.Create(Self);
  FBar2.Parent := FRight;
  FBar2.Align := alTop;
  FBar2.Top := 100;
  FBar2.Height := 32;
  FBar2.BevelOuter := bvNone;
  FTemplate := TComboBox.Create(Self);
  FTemplate.Parent := FBar2;
  FTemplate.Style := csDropDownList;
  sl := TStringList.Create;
  try
    sl.Delimiter := '|'; sl.StrictDelimiter := True; sl.DelimitedText := TEMPLATES;
    FTemplate.Items.Assign(sl);
  finally
    sl.Free;
  end;
  FTemplate.ItemIndex := 0;
  FTemplate.Width := 150;
  FTemplate.Align := alLeft;
  Btn(FBar2, 'Apply template', @ApplyTemplateClick);
  Btn(FBar2, 'x0.5', @PitchClick).Tag := 50;
  Btn(FBar2, 'x0.75', @PitchClick).Tag := 75;
  Btn(FBar2, 'x1.25', @PitchClick).Tag := 125;
  Btn(FBar2, 'x1.5', @PitchClick).Tag := 150;
  Btn(FBar2, 'x2', @PitchClick).Tag := 200;

  FInfo := TLabel.Create(Self);
  FInfo.Parent := FRight;
  FInfo.Align := alBottom;
  FInfo.Height := 48;
  FInfo.AutoSize := False;
  FInfo.WordWrap := True;
  FInfo.BorderSpacing.Around := 6;
  FInfo.Font.Size := 10;

  FWave := TPaintBox.Create(Self);
  FWave.Parent := FRight;
  FWave.Align := alClient;
  FWave.OnPaint := @WavePaint;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 60;
  FTimer.OnTimer := @TimerTick;

  SyncAudioBank;
  RefreshList;
  SelectItem(0);
end;

function TSoundEditor.Btn(AParent: TPanel; const ACaption: string; AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.AutoSize := True;
  Result.Left := AParent.ControlCount * 1000;
  Result.Align := alLeft;
  Result.BorderSpacing.Left := 4;
  Result.OnClick := AOnClick;
end;

procedure TSoundEditor.SyncAudioBank;
begin
  if Audio <> nil then Audio.SetBank(FData.Sfx);
end;

function TSoundEditor.ItemCount: Integer;
begin
  Result := Length(FData.Sfx);
end;

function TSoundEditor.ItemName(I: Integer): string;
begin
  Result := FData.Sfx[I].Name;
end;

procedure TSoundEditor.DescribeItem(I: Integer; var B: TPBuilder);
begin
  DescribeSfx(B, FData.Sfx[I]);
end;

procedure TSoundEditor.AddItem;
begin
  SetLength(FData.Sfx, Length(FData.Sfx) + 1);
  FData.Sfx[High(FData.Sfx)] := DefaultSfx('new_sound' + IntToStr(Length(FData.Sfx)));
  FData.Sfx[High(FData.Sfx)].UseB := True;
  SyncAudioBank;
end;

procedure TSoundEditor.DupItem(I: Integer);
var
  j: Integer;
begin
  SetLength(FData.Sfx, Length(FData.Sfx) + 1);
  for j := High(FData.Sfx) downto I + 2 do FData.Sfx[j] := FData.Sfx[j - 1];
  FData.Sfx[I + 1] := FData.Sfx[I];
  FData.Sfx[I + 1].Name := FData.Sfx[I].Name + '_copy';
  SyncAudioBank;
end;

procedure TSoundEditor.DelItem(I: Integer);
var
  j: Integer;
begin
  for j := I to High(FData.Sfx) - 1 do FData.Sfx[j] := FData.Sfx[j + 1];
  SetLength(FData.Sfx, Length(FData.Sfx) - 1);
  SyncAudioBank;
end;

procedure TSoundEditor.SwapItems(A, B: Integer);
var
  t: TSfxDef;
begin
  t := FData.Sfx[A]; FData.Sfx[A] := FData.Sfx[B]; FData.Sfx[B] := t;
  SyncAudioBank;
end;

procedure TSoundEditor.SaveData;
begin
  FData.SaveSfx;
end;

procedure TSoundEditor.RevertData;
begin
  FData.Sfx := DefaultSfxBank;
  FData.LoadSfx;
  SyncAudioBank;
end;

procedure TSoundEditor.DefaultsData;
begin
  FData.Sfx := DefaultSfxBank;
  SyncAudioBank;
end;

procedure TSoundEditor.ItemSelected(I: Integer);
begin
  Rebuild(False);
end;

procedure TSoundEditor.ParamChanged(const AKey: string);
begin
  FPending := True;     { re-render after the slider settles (timer) }
end;

procedure TSoundEditor.Rebuild(APlay: Boolean);
var
  i: Integer;
  peak, rms, lp, a, el, et: Double;
begin
  if FSel < 0 then Exit;
  if Audio <> nil then
  begin
    Audio.UpdateSfx(FSel, FData.Sfx[FSel]);
    FSamples := Audio.SfxSamples(FSel);
  end
  else
    FSamples := RenderSfx(FData.Sfx[FSel]);
  { loudness + bass share (energy below ~120 Hz) }
  peak := 0; et := 0; el := 0; lp := 0;
  a := Exp(-2 * Pi * 120 / SAMPLE_RATE);
  for i := 0 to High(FSamples) do
  begin
    peak := Max(peak, Abs(FSamples[i]));
    et := et + Sqr(FSamples[i]);
    lp := lp * a + (1 - a) * FSamples[i];
    el := el + lp * lp;
  end;
  rms := Sqrt(et / Max(1, Length(FSamples)));
  FInfo.Caption := Format('%s   length %.2f s   peak %.2f   RMS %.1f dBFS   bass (<120 Hz) %.0f%%   %s',
    [FData.Sfx[FSel].Name, Length(FSamples) / SAMPLE_RATE, peak, 20 * Log10(Max(1e-6, rms)),
     100 * el / Max(1e-12, et), BoolToStr(FData.Sfx[FSel].UseB, 'layers A+B', 'layer A')]);
  FWave.Invalidate;
  if APlay and (Audio <> nil) then
  begin
    Audio.PlaySfxIndex(FSel);
    FPlayStart := GetTickCount64;
    FPlaying := True;
  end;
end;

procedure TSoundEditor.TimerTick(Sender: TObject);
begin
  if FPending then
  begin
    FPending := False;
    Rebuild(FAuto.Checked);
  end;
  if FPlaying then
  begin
    FWave.Invalidate;
    if GetTickCount64 - FPlayStart > Length(FSamples) * 1000 div SAMPLE_RATE + 100 then FPlaying := False;
  end;
end;

procedure TSoundEditor.WavePaint(Sender: TObject);
var
  c: TCanvas;
  w, h, x, i0, i1, i, mid: Integer;
  mn, mx, e: Single;
  px: Integer;
begin
  c := FWave.Canvas;
  w := FWave.Width; h := FWave.Height;
  c.Brush.Color := RGBToColor(12, 12, 18);
  c.FillRect(0, 0, w, h);
  mid := h div 2;
  c.Pen.Color := RGBToColor(40, 40, 55);
  c.Line(0, mid, w, mid);
  { time grid every 100 ms }
  if Length(FSamples) > 0 then
    for i := 1 to Length(FSamples) div (SAMPLE_RATE div 10) do
    begin
      x := Round(i * (SAMPLE_RATE div 10) / Length(FSamples) * w);
      c.Line(x, 0, x, h);
    end;
  if Length(FSamples) = 0 then Exit;
  for x := 0 to w - 1 do
  begin
    i0 := Int64(x) * Length(FSamples) div w;
    i1 := Max(i0 + 1, Int64(x + 1) * Length(FSamples) div w);
    mn := 0; mx := 0; e := 0;
    for i := i0 to Min(i1, Length(FSamples)) - 1 do
    begin
      mn := Min(mn, FSamples[i]);
      mx := Max(mx, FSamples[i]);
      e := e + Sqr(FSamples[i]);
    end;
    e := Sqrt(e / Max(1, i1 - i0));
    c.Pen.Color := RGBToColor(120 + Round(135 * Min(1, e * 2)), 170, 255);
    c.Line(x, mid - Round(mx * mid * 0.95), x, mid - Round(mn * mid * 0.95) + 1);
  end;
  { playhead }
  if FPlaying then
  begin
    px := Round((GetTickCount64 - FPlayStart) / 1000 * SAMPLE_RATE / Length(FSamples) * w);
    c.Pen.Color := clWhite;
    c.Line(px, 0, px, h);
  end;
  c.Font.Color := clSilver;
  c.Brush.Style := bsClear;
  c.TextOut(8, 6, 'Space = play   |   layer A = character   layer B = sub / thump (heavy bass)');
  c.Brush.Style := bsSolid;
end;

procedure TSoundEditor.PlayClick(Sender: TObject);
begin
  Rebuild(True);
end;

procedure TSoundEditor.PitchClick(Sender: TObject);
begin
  if (Audio <> nil) and (FSel >= 0) then
    Audio.PlaySfxIndex(FSel, 1, 0, TButton(Sender).Tag / 100);
end;

procedure TSoundEditor.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_SPACE) and not (ActiveControl is TCustomEdit) then
  begin
    Rebuild(True);
    Key := 0;
  end;
end;

procedure TSoundEditor.ApplyTemplateClick(Sender: TObject);
var
  s: TSfxDef;
  bank: TSfxDefs;
  keepName: string;

  function FromBank(const N: string): TSfxDef;
  var
    k: Integer;
  begin
    k := FindSfx(bank, N);
    if k >= 0 then Result := bank[k] else Result := DefaultSfx(N);
  end;

begin
  if FSel < 0 then Exit;
  keepName := FData.Sfx[FSel].Name;
  bank := DefaultSfxBank;
  s := DefaultSfx(keepName);
  case FTemplate.ItemIndex of
    0: begin { Kick 808 }
         s.A.Wave := 0; s.A.BaseNote := 33; s.A.PitchEnv := 36; s.A.PitchDecay := 0.05; s.A.Decay := 0.6;
         s.A.Duration := 0.5; s.A.Drive := 4; s.A.SubLevel := 0.4; s.A.Volume := 1;
       end;
    1: s := FromBank('gameover');
    2: s := FromBank('hit');
    3: begin { Wobble bass }
         s.A.Wave := 1; s.A.Detune := 18; s.A.BaseNote := 33; s.A.Duration := 1.2; s.A.Sustain := 0.9;
         s.A.Decay := 1; s.A.Cutoff := 250; s.A.Resonance := 0.65; s.A.LfoRate := 4; s.A.LfoCutoff := 3.5;
         s.A.Drive := 8; s.A.SubLevel := 0.5; s.A.Volume := 0.6;
       end;
    4: begin { Laser }
         s.A.Wave := 2; s.A.BaseNote := 96; s.A.Slide := -80; s.A.Decay := 0.25; s.A.Duration := 0.2;
         s.A.Cutoff := 6000; s.A.Volume := 0.4;
       end;
    5: s := FromBank('collect');
    6: begin { 8-bit coin }
         s.A.Wave := 2; s.A.BaseNote := 83; s.A.Arp := '0 5'; s.A.ArpRate := 14; s.A.Decay := 0.25;
         s.A.Duration := 0.18; s.A.Crush := 5; s.A.Downsample := 3; s.A.Volume := 0.35;
         s.UseB := True; s.B.Wave := 0; s.B.BaseNote := 45; s.B.PitchEnv := 12; s.B.Decay := 0.12;
         s.B.Duration := 0.1; s.B.Volume := 0.6;
       end;
    7: s := FromBank('life');
    8: s := FromBank('nova');
    9: s := FromBank('levelup');
    10: begin { Glitch blip }
          s.A.Wave := 4; s.A.Crush := 3; s.A.Downsample := 12; s.A.Decay := 0.15; s.A.Duration := 0.1;
          s.A.FilterType := 2; s.A.Cutoff := 1800; s.A.Resonance := 0.7; s.A.Volume := 0.6;
          s.UseB := True; s.B.Wave := 0; s.B.BaseNote := 36; s.B.PitchEnv := 24; s.B.Decay := 0.2;
          s.B.Duration := 0.15; s.B.Drive := 5; s.B.Volume := 0.8;
        end;
  end;
  s.Name := keepName;
  FData.Sfx[FSel] := s;
  FParams.RefreshValues;
  MarkDirty;
  Rebuild(True);
end;

procedure TSoundEditor.RandomizeClick(Sender: TObject);
var
  s: TSfxDef;

  function R(a, b: Single): Single;
  begin
    Result := a + Random * (b - a);
  end;

begin
  if FSel < 0 then Exit;
  s := FData.Sfx[FSel];
  s.A := DefaultSynth;
  s.A.Wave := Random(5);
  s.A.BaseNote := R(40, 90);
  s.A.PitchEnv := IfThen(Random < 0.4, R(-24, 36), 0);
  s.A.Slide := IfThen(Random < 0.4, R(-60, 60), 0);
  s.A.Decay := R(0.05, 0.8);
  s.A.Duration := R(0.05, 0.6);
  s.A.Cutoff := R(400, 12000);
  s.A.Resonance := R(0, 0.7);
  s.A.FilterEnv := R(-2, 4);
  s.A.Drive := R(1, 8);
  if Random < 0.3 then s.A.Arp := '0 ' + IntToStr(3 + Random(5)) + ' ' + IntToStr(7 + Random(6));
  s.A.ArpRate := R(8, 30);
  if Random < 0.25 then s.A.Crush := 3 + Random(5);
  s.A.Volume := R(0.3, 0.7);
  s.UseB := Random < 0.8;
  s.B := DefaultSynth;
  s.B.Wave := 0;
  s.B.BaseNote := R(26, 45);
  s.B.PitchEnv := R(12, 36);
  s.B.PitchDecay := R(0.03, 0.12);
  s.B.Decay := R(0.15, 1.2);
  s.B.Duration := s.B.Decay * 0.8;
  s.B.Drive := R(2, 6);
  s.B.SubLevel := R(0.2, 0.6);
  s.B.Volume := R(0.6, 1.0);
  s.EchoMix := IfThen(Random < 0.3, R(0.2, 0.5), 0);
  FData.Sfx[FSel] := s;
  FParams.RefreshValues;
  MarkDirty;
  Rebuild(True);
end;

procedure TSoundEditor.MutateClick(Sender: TObject);
var
  i: Integer;
  d: TPDesc;
  v: Single;
begin
  if FSel < 0 then Exit;
  for i := 0 to High(FParams.Descs) do
  begin
    d := FParams.Descs[i];
    if (d.Kind = pkFloat) and (Random < 0.3) and (d.Key <> 'gain') then
    begin
      v := PSingle(d.P)^ + (Random - 0.5) * 0.15 * (d.MaxV - d.MinV);
      PSingle(d.P)^ := EnsureRange(v, d.MinV, d.MaxV);
    end;
  end;
  FParams.RefreshValues;
  MarkDirty;
  Rebuild(True);
end;

procedure TSoundEditor.ExportClick(Sender: TObject);
var
  dlg: TSaveDialog;
begin
  if FSel < 0 then Exit;
  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter := 'WAV audio|*.wav';
    dlg.DefaultExt := 'wav';
    dlg.FileName := FData.Sfx[FSel].Name + '.wav';
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if dlg.Execute then
    begin
      WriteWav(dlg.FileName, RenderSfx(FData.Sfx[FSel]), 1);
      SetStatus('Exported ' + ExtractFileName(dlg.FileName));
    end;
  finally
    dlg.Free;
  end;
end;

end.

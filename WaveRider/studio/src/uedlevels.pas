{ Level editor: every level parameter + live autopilot simulation,
  spawn-rate timeline and validation of the object mixes. }
unit uEdLevels;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Dialogs,
  uParams, uGameData, uEdBase, uPreview;

type

  { TLevelEditor }

  TLevelEditor = class(TListEditor)
  private
    FPreview: TGamePreview;
    FGraph: TPaintBox;
    FCheck: TLabel;
    FTimer: TTimer;
    procedure RestartSim(Sender: TObject);
    procedure GraphPaint(Sender: TObject);
    procedure Validate;
    procedure SkipEndClick(Sender: TObject);
    procedure TimerTick(Sender: TObject);
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

{ TLevelEditor }

constructor TLevelEditor.Create(AOwner: TComponent; AData: TGameData);
var
  bottom: TPanel;
begin
  inherited CreateEditor(AOwner, AData, 'Levels', True);
  bottom := TPanel.Create(Self);
  bottom.Parent := FRight;
  bottom.Align := alBottom;
  bottom.Height := 170;
  bottom.BevelOuter := bvNone;
  FCheck := TLabel.Create(Self);
  FCheck.Parent := bottom;
  FCheck.Align := alTop;
  FCheck.WordWrap := True;
  FCheck.AutoSize := True;
  FCheck.BorderSpacing.Around := 4;
  FGraph := TPaintBox.Create(Self);
  FGraph.Parent := bottom;
  FGraph.Align := alClient;
  FGraph.OnPaint := @GraphPaint;

  FPreview := TGamePreview.Create(Self, AData);
  FPreview.Parent := FRight;
  FPreview.Align := alClient;
  FPreview.OnRestart := @RestartSim;
  FPreview.AddButton('Jump to end', @SkipEndClick);

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 250;
  FTimer.OnTimer := @TimerTick;
  RefreshList;
  SelectItem(0);
end;

function TLevelEditor.ItemCount: Integer;
begin
  Result := Length(FData.Levels);
end;

function TLevelEditor.ItemName(I: Integer): string;
begin
  Result := Format('%d  %s', [I + 1, FData.Levels[I].Name]);
  if FData.Levels[I].Pixel then Result := Result + '  [8-bit]';
end;

procedure TLevelEditor.DescribeItem(I: Integer; var B: TPBuilder);
begin
  DescribeLevel(B, FData.Levels[I]);
end;

procedure TLevelEditor.AddItem;
begin
  SetLength(FData.Levels, Length(FData.Levels) + 1);
  FData.Levels[High(FData.Levels)] := DefaultLevel;
  FData.Levels[High(FData.Levels)].Name := 'Level ' + IntToStr(Length(FData.Levels));
  FPreview.Game.DataChanged;
end;

procedure TLevelEditor.DupItem(I: Integer);
var
  j: Integer;
begin
  SetLength(FData.Levels, Length(FData.Levels) + 1);
  for j := High(FData.Levels) downto I + 2 do FData.Levels[j] := FData.Levels[j - 1];
  FData.Levels[I + 1] := FData.Levels[I];
  FData.Levels[I + 1].Name := FData.Levels[I].Name + ' copy';
  FPreview.Game.DataChanged;
end;

procedure TLevelEditor.DelItem(I: Integer);
var
  j: Integer;
begin
  for j := I to High(FData.Levels) - 1 do FData.Levels[j] := FData.Levels[j + 1];
  SetLength(FData.Levels, Length(FData.Levels) - 1);
  FPreview.Game.DataChanged;
end;

procedure TLevelEditor.SwapItems(A, B: Integer);
var
  t: TLevelDef;
begin
  t := FData.Levels[A]; FData.Levels[A] := FData.Levels[B]; FData.Levels[B] := t;
end;

procedure TLevelEditor.SaveData;
begin
  FData.SaveLevels;
end;

procedure TLevelEditor.RevertData;
begin
  FData.Levels := DefaultLevels;
  FData.LoadLevels;
  FPreview.Game.DataChanged;
end;

procedure TLevelEditor.DefaultsData;
begin
  FData.Levels := DefaultLevels;
  FPreview.Game.DataChanged;
end;

procedure TLevelEditor.RestartSim(Sender: TObject);
begin
  if FSel >= 0 then FPreview.Game.SimLevel(FSel);
end;

procedure TLevelEditor.ItemSelected(I: Integer);
begin
  FPreview.Game.SimLevel(I);
  Validate;
  FGraph.Invalidate;
end;

procedure TLevelEditor.ParamChanged(const AKey: string);
begin
  Validate;
  FGraph.Invalidate;
  FPreview.Game.DataChanged;
  { spawn tables and lives are read when a level starts }
  if (Pos('Mix', AKey) > 0) or (AKey = 'lives') or (AKey = 'musicSection') then RestartSim(nil);
end;

procedure TLevelEditor.SkipEndClick(Sender: TObject);
begin
  if FSel < 0 then Exit;
  if FData.Levels[FSel].Duration > 3 then
    FPreview.Game.PlayTime := FData.Levels[FSel].Duration - 3;
end;

procedure TLevelEditor.TimerTick(Sender: TObject);
begin
  FGraph.Invalidate;
end;

procedure TLevelEditor.Validate;
var
  l: TLevelDef;
  msg: string;

  procedure Check(const AMix, ATitle: string; ARole: Integer);
  var
    sl: TStringList;
    i, p, idx: Integer;
    name: string;
  begin
    sl := TStringList.Create;
    try
      sl.Delimiter := ' ';
      sl.DelimitedText := StringReplace(AMix, ',', ' ', [rfReplaceAll]);
      if sl.Count = 0 then msg := msg + ATitle + ' mix is empty.  ';
      for i := 0 to sl.Count - 1 do
      begin
        p := Pos(':', sl[i]);
        if p > 0 then name := Copy(sl[i], 1, p - 1) else name := sl[i];
        idx := FData.FindObject(name);
        if idx < 0 then msg := msg + 'Unknown object "' + name + '" in ' + ATitle + ' mix.  '
        else if FData.Objects[idx].Role <> ARole then
          msg := msg + '"' + name + '" is a ' + EnumName(ROLE_NAMES, FData.Objects[idx].Role) + ', listed in ' + ATitle + ' mix.  ';
      end;
    finally
      sl.Free;
    end;
  end;

begin
  if FSel < 0 then Exit;
  l := FData.Levels[FSel];
  msg := '';
  Check(l.CollectMix, 'Collect', RL_COLLECT);
  Check(l.HazardMix, 'Hazard', RL_HAZARD);
  Check(l.BonusMix, 'Bonus', RL_BONUS);
  if l.SpeedEnd < l.SpeedStart then msg := msg + 'Speed end is lower than speed start.  ';
  if (l.Star1 > l.Star2) or (l.Star2 > l.Star3) then msg := msg + 'Star scores should increase.  ';
  if msg = '' then
  begin
    FCheck.Font.Color := RGBToColor(40, 150, 60);
    FCheck.Caption := 'Level OK  -  objects: ' + IntToStr(Length(FData.Objects)) +
      '   (mix format: Name:weight separated by spaces)';
  end
  else
  begin
    FCheck.Font.Color := clRed;
    FCheck.Caption := msg;
  end;
end;

procedure TLevelEditor.GraphPaint(Sender: TObject);
var
  c: TCanvas;
  l: TLevelDef;
  w, h, x, i, n: Integer;
  dur, p, ramp, maxRate, t: Single;
  rates: array[0..2] of Single;
  cols: array[0..2] of TColor;
  names: array[0..2] of string;
  py: array[0..2] of Integer;
begin
  c := FGraph.Canvas;
  w := FGraph.Width; h := FGraph.Height;
  c.Brush.Color := RGBToColor(14, 14, 20);
  c.FillRect(0, 0, w, h);
  if FSel < 0 then Exit;
  l := FData.Levels[FSel];
  if l.Duration > 0 then dur := l.Duration else dur := 240;
  cols[0] := RGBToColor(120, 220, 255); cols[1] := RGBToColor(255, 90, 110); cols[2] := RGBToColor(255, 210, 90);
  names[0] := 'collectibles/s'; names[1] := 'hazards/s'; names[2] := 'bonuses/s x10';
  maxRate := Max(0.5, Max(l.CollectRate, l.HazardRate) * Max(1, l.RateRamp) * 1.1);
  for n := 0 to 2 do py[n] := -1;
  for x := 0 to w - 1 do
  begin
    p := x / Max(1, w - 1);
    ramp := 1 + (l.RateRamp - 1) * p;
    rates[0] := l.CollectRate * ramp;
    rates[1] := l.HazardRate * ramp;
    rates[2] := l.BonusRate * (0.8 + 0.4 * p) * 10;
    for n := 0 to 2 do
    begin
      i := h - 18 - Round(Min(1, rates[n] / maxRate) * (h - 30));
      c.Pen.Color := cols[n];
      if py[n] >= 0 then c.Line(x - 1, py[n], x, i);
      py[n] := i;
    end;
  end;
  { speed ramp as a faint fill }
  c.Pen.Color := RGBToColor(70, 70, 90);
  c.Line(0, h - 18 - Round(l.SpeedStart / 1500 * (h - 30)), w, h - 18 - Round(l.SpeedEnd / 1500 * (h - 30)));
  { playhead from the simulation }
  t := FPreview.Game.PlayTime;
  if l.Duration > 0 then x := Round(Min(1, t / dur) * w) else x := Round(Min(1, t / 240) * w);
  c.Pen.Color := clWhite;
  c.Line(x, 0, x, h);
  c.Brush.Style := bsClear;
  c.Font.Size := 8;
  for n := 0 to 2 do
  begin
    c.Font.Color := cols[n];
    c.TextOut(8 + n * 130, 4, names[n]);
  end;
  c.Font.Color := RGBToColor(140, 140, 160);
  c.TextOut(400, 4, 'grey = flow speed');
  c.TextOut(8, h - 16, '0 s');
  c.TextOut(w - 60, h - 16, Format('%.0f s', [dur]));
  c.Brush.Style := bsSolid;
end;

end.

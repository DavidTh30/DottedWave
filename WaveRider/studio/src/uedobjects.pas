{ Object & effect editor: every collectible / hazard / bonus with
  - live simulation (the object keeps spawning, the autopilot flies into it so
    pickup / hit effects, rings, particles, sounds and music sweeps can be tuned)
  - zoomed sprite view
  - pixel-art painter (palette . 1 2 W K) }
unit uEdObjects;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Spin, Dialogs,
  BGRABitmap, BGRABitmapTypes, uParams, uGameData, uEdBase, uPreview;

type

  { TObjectEditor }

  TObjectEditor = class(TListEditor)
  private
    FPreview: TGamePreview;
    FSide: TPanel;
    FZoom: TPaintBox;
    FPix: TPaintBox;
    FZoomBmp: TBGRABitmap;
    FStyleLevel: TComboBox;
    FBrush: Char;
    FBrushBtns: array[0..4] of TButton;
    FPixW, FPixH: TSpinEdit;
    FGridChars: array of string;
    FPainting: Boolean;
    FTimer: TTimer;
    FUpdating: Boolean;
    procedure RestartSim(Sender: TObject);
    procedure SpawnClick(Sender: TObject);
    procedure ZoomPaint(Sender: TObject);
    procedure PixPaint(Sender: TObject);
    procedure PixDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PixMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PixUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BrushClick(Sender: TObject);
    procedure PixSizeChange(Sender: TObject);
    procedure ClearPixClick(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure LoadGrid;
    procedure StoreGrid;
    procedure PaintAt(X, Y: Integer; AErase: Boolean);
    function CellSize: Integer;
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
    destructor Destroy; override;
  end;

implementation

const
  BRUSHES: array[0..4] of Char = ('.', '1', '2', 'W', 'K');
  BRUSH_NAMES: array[0..4] of string = ('Erase', 'Color 1', 'Color 2', 'White', 'Black');

{ TObjectEditor }

constructor TObjectEditor.Create(AOwner: TComponent; AData: TGameData);
var
  lbl: TLabel;
  row: TPanel;
  i: Integer;
  b: TButton;
  split: TSplitter;
begin
  inherited CreateEditor(AOwner, AData, 'Objects & Effects', True);

  FSide := TPanel.Create(Self);
  FSide.Parent := FRight;
  FSide.Align := alRight;
  FSide.Width := 300;
  FSide.BevelOuter := bvNone;
  split := TSplitter.Create(Self);
  split.Parent := FRight;
  split.Align := alRight;

  lbl := TLabel.Create(Self);
  lbl.Parent := FSide; lbl.Align := alTop; lbl.Caption := ' SPRITE (zoom x3)'; lbl.Font.Style := [fsBold];
  FZoom := TPaintBox.Create(Self);
  FZoom.Parent := FSide; FZoom.Align := alTop; FZoom.Top := 100; FZoom.Height := 220;
  FZoom.OnPaint := @ZoomPaint;

  lbl := TLabel.Create(Self);
  lbl.Parent := FSide; lbl.Align := alTop; lbl.Top := 400; lbl.Caption := ' PIXEL ART (style = Pixel)';
  lbl.Font.Style := [fsBold];
  row := TPanel.Create(Self);
  row.Parent := FSide; row.Align := alTop; row.Top := 500; row.Height := 28; row.BevelOuter := bvNone;
  for i := 0 to 4 do
  begin
    b := TButton.Create(Self);
    b.Parent := row; b.Caption := BRUSHES[i]; b.Hint := BRUSH_NAMES[i]; b.ShowHint := True;
    b.Width := 34; b.Left := i * 100; b.Align := alLeft; b.Tag := i; b.OnClick := @BrushClick;
    FBrushBtns[i] := b;
  end;
  b := TButton.Create(Self);
  b.Parent := row; b.Caption := 'Clear'; b.Left := 1000; b.Align := alLeft; b.OnClick := @ClearPixClick;
  row := TPanel.Create(Self);
  row.Parent := FSide; row.Align := alTop; row.Top := 600; row.Height := 28; row.BevelOuter := bvNone;
  lbl := TLabel.Create(Self); lbl.Parent := row; lbl.Caption := ' Size W '; lbl.Layout := tlCenter; lbl.Align := alLeft;
  FPixW := TSpinEdit.Create(Self); FPixW.Parent := row; FPixW.MinValue := 2; FPixW.MaxValue := 16; FPixW.Value := 8;
  FPixW.Width := 50; FPixW.Left := 100; FPixW.Align := alLeft; FPixW.OnChange := @PixSizeChange;
  lbl := TLabel.Create(Self); lbl.Parent := row; lbl.Caption := '  H '; lbl.Layout := tlCenter; lbl.Left := 200; lbl.Align := alLeft;
  FPixH := TSpinEdit.Create(Self); FPixH.Parent := row; FPixH.MinValue := 2; FPixH.MaxValue := 16; FPixH.Value := 8;
  FPixH.Width := 50; FPixH.Left := 300; FPixH.Align := alLeft; FPixH.OnChange := @PixSizeChange;
  FPix := TPaintBox.Create(Self);
  FPix.Parent := FSide; FPix.Align := alClient;
  FPix.OnPaint := @PixPaint; FPix.OnMouseDown := @PixDown; FPix.OnMouseMove := @PixMove; FPix.OnMouseUp := @PixUp;

  FPreview := TGamePreview.Create(Self, AData);
  FPreview.Parent := FRight;
  FPreview.Align := alClient;
  FPreview.OnRestart := @RestartSim;
  FPreview.AddButton('Spawn at ship', @SpawnClick);
  FStyleLevel := TComboBox.Create(Self);
  FStyleLevel.Parent := FPreview.Bar;
  FStyleLevel.Style := csDropDownList;
  for i := 0 to High(AData.Levels) do FStyleLevel.Items.Add('Backdrop: ' + AData.Levels[i].Name);
  FStyleLevel.ItemIndex := 0;
  FStyleLevel.Width := 170;
  FStyleLevel.Left := 5000;
  FStyleLevel.Align := alLeft;
  FStyleLevel.OnChange := @RestartSim;

  FBrush := '1';
  FZoomBmp := TBGRABitmap.Create(2, 2);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 33;
  FTimer.OnTimer := @TimerTick;
  RefreshList;
  SelectItem(0);
end;

destructor TObjectEditor.Destroy;
begin
  FZoomBmp.Free;
  inherited Destroy;
end;

function TObjectEditor.ItemCount: Integer;
begin
  Result := Length(FData.Objects);
end;

function TObjectEditor.ItemName(I: Integer): string;
const
  R: array[0..2] of string = ('+', '!', '*');
begin
  Result := Format('%s %s  (%s)', [R[EnsureRange(FData.Objects[I].Role, 0, 2)], FData.Objects[I].Name,
    EnumName(EFFECT_NAMES, FData.Objects[I].Effect)]);
end;

procedure TObjectEditor.DescribeItem(I: Integer; var B: TPBuilder);
begin
  DescribeObject(B, FData.Objects[I]);
end;

procedure TObjectEditor.AddItem;
begin
  SetLength(FData.Objects, Length(FData.Objects) + 1);
  FData.Objects[High(FData.Objects)] := DefaultObject('Object' + IntToStr(Length(FData.Objects)));
  FPreview.Game.DataChanged;
end;

procedure TObjectEditor.DupItem(I: Integer);
var
  j: Integer;
begin
  SetLength(FData.Objects, Length(FData.Objects) + 1);
  for j := High(FData.Objects) downto I + 2 do FData.Objects[j] := FData.Objects[j - 1];
  FData.Objects[I + 1] := FData.Objects[I];
  FData.Objects[I + 1].Name := FData.Objects[I].Name + 'Copy';
  FPreview.Game.DataChanged;
  FPreview.Game.SimObject(I + 1, FStyleLevel.ItemIndex);
end;

procedure TObjectEditor.DelItem(I: Integer);
var
  j: Integer;
begin
  FPreview.Game.SimObject(-1, FStyleLevel.ItemIndex);
  for j := I to High(FData.Objects) - 1 do FData.Objects[j] := FData.Objects[j + 1];
  SetLength(FData.Objects, Length(FData.Objects) - 1);
  FPreview.Game.DataChanged;
end;

procedure TObjectEditor.SwapItems(A, B: Integer);
var
  t: TObjDef;
begin
  FPreview.Game.SimObject(-1, FStyleLevel.ItemIndex);
  t := FData.Objects[A]; FData.Objects[A] := FData.Objects[B]; FData.Objects[B] := t;
end;

procedure TObjectEditor.SaveData;
begin
  FData.SaveObjects;
end;

procedure TObjectEditor.RevertData;
begin
  FPreview.Game.SimObject(-1, 0);
  FData.Objects := DefaultObjects;
  FData.LoadObjects;
  FPreview.Game.DataChanged;
end;

procedure TObjectEditor.DefaultsData;
begin
  FPreview.Game.SimObject(-1, 0);
  FData.Objects := DefaultObjects;
  FPreview.Game.DataChanged;
end;

procedure TObjectEditor.RestartSim(Sender: TObject);
begin
  if FSel >= 0 then FPreview.Game.SimObject(FSel, Max(0, FStyleLevel.ItemIndex));
end;

procedure TObjectEditor.SpawnClick(Sender: TObject);
begin
  if FSel >= 0 then FPreview.Game.SpawnNearShip(FSel);
end;

procedure TObjectEditor.ItemSelected(I: Integer);
begin
  RestartSim(nil);
  LoadGrid;
end;

procedure TObjectEditor.ParamChanged(const AKey: string);
begin
  FPreview.Game.DataChanged;
  if AKey = 'pixelArt' then LoadGrid;
  if AKey = 'role' then RestartSim(nil);
end;

procedure TObjectEditor.TimerTick(Sender: TObject);
begin
  if IsVisible then FZoom.Invalidate;
end;

procedure TObjectEditor.ZoomPaint(Sender: TObject);
var
  k: Single;
begin
  if (FZoomBmp.Width <> FZoom.Width) or (FZoomBmp.Height <> FZoom.Height) then
    FZoomBmp.SetSize(Max(2, FZoom.Width), Max(2, FZoom.Height));
  FZoomBmp.Fill(BGRA(8, 8, 14));
  if FSel >= 0 then
  begin
    k := 3;
    FPreview.Game.DrawObjectPreview(FZoomBmp, FSel, FZoomBmp.Width / 2, FZoomBmp.Height / 2, k);
    FZoomBmp.FontHeight := 12;
    FZoomBmp.TextOut(6, FZoomBmp.Height - 18, Format('radius %.0f   score %d   %s', [FData.Objects[FSel].Radius,
      FData.Objects[FSel].Score, EnumName(STYLE_NAMES, FData.Objects[FSel].Style)]), BGRA(170, 170, 190));
  end;
  FZoomBmp.Draw(FZoom.Canvas, 0, 0, True);
end;

{ ---------- pixel art painter ---------- }

procedure TObjectEditor.LoadGrid;
var
  rows: TStringList;
  r, w, h: Integer;
begin
  if FSel < 0 then Exit;
  rows := TStringList.Create;
  try
    rows.Delimiter := '/';
    rows.StrictDelimiter := True;
    rows.DelimitedText := FData.Objects[FSel].PixelArt;
    h := Max(1, rows.Count);
    w := 1;
    for r := 0 to rows.Count - 1 do w := Max(w, Length(rows[r]));
    if FData.Objects[FSel].PixelArt = '' then begin w := 8; h := 8; end;
    w := EnsureRange(w, 2, 16); h := EnsureRange(h, 2, 16);
    SetLength(FGridChars, h);
    for r := 0 to h - 1 do
    begin
      if r < rows.Count then FGridChars[r] := Copy(rows[r], 1, w) else FGridChars[r] := '';
      while Length(FGridChars[r]) < w do FGridChars[r] := FGridChars[r] + '.';
    end;
  finally
    rows.Free;
  end;
  FUpdating := True;
  FPixW.Value := w;
  FPixH.Value := h;
  FUpdating := False;
  FPix.Invalidate;
end;

procedure TObjectEditor.StoreGrid;
var
  s: string;
  r: Integer;
begin
  if FSel < 0 then Exit;
  s := '';
  for r := 0 to High(FGridChars) do
  begin
    if r > 0 then s := s + '/';
    s := s + FGridChars[r];
  end;
  FData.Objects[FSel].PixelArt := s;
  FParams.RefreshValues;
  FPreview.Game.DataChanged;
  MarkDirty;
end;

function TObjectEditor.CellSize: Integer;
begin
  if Length(FGridChars) = 0 then Exit(16);
  Result := Max(6, Min((FPix.Width - 8) div Max(1, Length(FGridChars[0])), (FPix.Height - 8) div Length(FGridChars)));
end;

procedure TObjectEditor.PixPaint(Sender: TObject);
var
  c: TCanvas;
  r, k, cs: Integer;
  col: TColor;
  o: TObjDef;
begin
  c := FPix.Canvas;
  c.Brush.Color := RGBToColor(20, 20, 26);
  c.FillRect(0, 0, FPix.Width, FPix.Height);
  if (FSel < 0) or (Length(FGridChars) = 0) then Exit;
  o := FData.Objects[FSel];
  cs := CellSize;
  for r := 0 to High(FGridChars) do
    for k := 1 to Length(FGridChars[r]) do
    begin
      case FGridChars[r][k] of
        '1': col := RGBToColor(o.Color1.red, o.Color1.green, o.Color1.blue);
        '2': col := RGBToColor(o.Color2.red, o.Color2.green, o.Color2.blue);
        'W': col := clWhite;
        'K': col := RGBToColor(0, 0, 0);
      else
        if (r + k) mod 2 = 0 then col := RGBToColor(40, 40, 48) else col := RGBToColor(48, 48, 58);
      end;
      c.Brush.Color := col;
      c.FillRect(4 + (k - 1) * cs, 4 + r * cs, 4 + k * cs - 1, 4 + (r + 1) * cs - 1);
    end;
end;

procedure TObjectEditor.PaintAt(X, Y: Integer; AErase: Boolean);
var
  cs, r, k: Integer;
  ch: Char;
begin
  if Length(FGridChars) = 0 then Exit;
  cs := CellSize;
  r := (Y - 4) div cs;
  k := (X - 4) div cs + 1;
  if (r < 0) or (r > High(FGridChars)) or (k < 1) or (k > Length(FGridChars[r])) then Exit;
  if AErase then ch := '.' else ch := FBrush;
  if FGridChars[r][k] = ch then Exit;
  FGridChars[r][k] := ch;
  FPix.Invalidate;
  StoreGrid;
end;

procedure TObjectEditor.PixDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FPainting := True;
  PaintAt(X, Y, Button = mbRight);
end;

procedure TObjectEditor.PixMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FPainting then PaintAt(X, Y, ssRight in Shift);
end;

procedure TObjectEditor.PixUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FPainting := False;
end;

procedure TObjectEditor.BrushClick(Sender: TObject);
var
  i: Integer;
begin
  FBrush := BRUSHES[TButton(Sender).Tag];
  for i := 0 to 4 do
    if i = TButton(Sender).Tag then FBrushBtns[i].Font.Style := [fsBold, fsUnderline]
    else FBrushBtns[i].Font.Style := [];
end;

procedure TObjectEditor.PixSizeChange(Sender: TObject);
var
  r, w, h: Integer;
begin
  if FUpdating or (FSel < 0) then Exit;
  w := FPixW.Value; h := FPixH.Value;
  SetLength(FGridChars, h);
  for r := 0 to h - 1 do
  begin
    FGridChars[r] := Copy(FGridChars[r], 1, w);
    while Length(FGridChars[r]) < w do FGridChars[r] := FGridChars[r] + '.';
  end;
  FPix.Invalidate;
  StoreGrid;
end;

procedure TObjectEditor.ClearPixClick(Sender: TObject);
var
  r: Integer;
begin
  for r := 0 to High(FGridChars) do FGridChars[r] := StringOfChar('.', Length(FGridChars[r]));
  FPix.Invalidate;
  StoreGrid;
end;

end.

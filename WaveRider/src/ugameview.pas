{ Shared frame pipeline for the game window and every editor preview.

    normal levels:  engine mesh -> world sprites -> HUD          (full res)
    pixel levels :  engine mesh -> world sprites -> posterize    (1/PixelSize res)
                    -> nearest-neighbour upscale -> HUD           (full res) }
unit uGameView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, BGRABitmap, BGRABitmapTypes, uWaveTypes, uWaveEngine, uGame, uGfx;

type

  { TGameRenderer }

  TGameRenderer = class
  private
    FEngine: TWaveEngine;
    FFrame: TBGRABitmap;
    FLow: TBGRABitmap;
    FXMap: array of Integer;
  public
    constructor Create;
    destructor Destroy; override;
    { renders one frame of AGame at AW x AH and returns the frame (owned) }
    function Render(AGame: TWaveGame; AW, AH: Integer): TBGRABitmap;
    property Engine: TWaveEngine read FEngine;
    property Frame: TBGRABitmap read FFrame;
  end;

procedure UpscaleNearest(Src, Dst: TBGRABitmap; var XMap: array of Integer);

implementation

procedure UpscaleNearest(Src, Dst: TBGRABitmap; var XMap: array of Integer);
var
  x, y, sy: Integer;
  ps, pd: PBGRAPixel;
begin
  for x := 0 to Min(Dst.Width, Length(XMap)) - 1 do
    XMap[x] := Min(Src.Width - 1, x * Src.Width div Dst.Width);
  for y := 0 to Dst.Height - 1 do
  begin
    sy := Min(Src.Height - 1, y * Src.Height div Dst.Height);
    ps := Src.ScanLine[sy];
    pd := Dst.ScanLine[y];
    for x := 0 to Dst.Width - 1 do
    begin
      pd^ := (ps + XMap[x])^;
      Inc(pd);
    end;
  end;
  Dst.InvalidateBitmap;
end;

{ TGameRenderer }

constructor TGameRenderer.Create;
begin
  inherited Create;
  FEngine := TWaveEngine.Create;
  FFrame := TBGRABitmap.Create(2, 2);
  FLow := TBGRABitmap.Create(2, 2);
end;

destructor TGameRenderer.Destroy;
begin
  FEngine.Free;
  FFrame.Free;
  FLow.Free;
  inherited Destroy;
end;

function TGameRenderer.Render(AGame: TWaveGame; AW, AH: Integer): TBGRABitmap;
var
  ps, lw, lh, post: Integer;
  scl: Single;
begin
  AW := Max(8, AW); AH := Max(8, AH);
  if (FFrame.Width <> AW) or (FFrame.Height <> AH) then
  begin
    FFrame.SetSize(AW, AH);
    SetLength(FXMap, AW);
  end;
  AGame.SetField(AW, AH);
  AGame.ApplyToEngine(FEngine);
  ps := AGame.PixelSize;
  if ps > 1 then
  begin
    lw := Max(8, AW div ps);
    lh := Max(8, AH div ps);
    if (FLow.Width <> lw) or (FLow.Height <> lh) then FLow.SetSize(lw, lh);
    { keep dots readable as pixels at the low resolution }
    scl := lh / REF_HEIGHT;
    AGame.Config.Values[wpDotSpacing] := Max(AGame.Config.Values[wpDotSpacing], 2.0 / scl);
    AGame.Config.Values[wpDotSize] := Max(AGame.Config.Values[wpDotSize], 1.0 / scl);
    AGame.Config.Values[wpLines] := Min(AGame.Config.Values[wpLines], lh / 3.2);
    FEngine.Render(FLow, AGame.Config, AGame.Phase, AGame.PlayTime);
    AGame.DrawWorld(FLow);
    post := AGame.PosterizeLevels;
    if post > 1 then Posterize(FLow, post);
    UpscaleNearest(FLow, FFrame, FXMap);
  end
  else
  begin
    FEngine.Render(FFrame, AGame.Config, AGame.Phase, AGame.PlayTime);
    AGame.DrawWorld(FFrame);
  end;
  AGame.DrawHud(FFrame);
  Result := FFrame;
end;

end.

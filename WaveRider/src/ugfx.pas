{ WaveRider graphics helpers (CPU, BGRABitmap)

  TTextCache   pre-rendered text sprites (fine antialiasing is expensive)
  TGlowCache   radial glow sprites by radius + color
  TDotText     "Dotted Iridescent Pearl" text: the glyph mask is sampled on a
               grid once (cached), then every frame each dot gets a pearl /
               iridescent color, shimmer sweep, sparkle and a vertical wave
  Posterize    retro palette reduction for pixel-art levels
  ColorForMode object color modes (fixed / hue / pearl / holo / oil / rainbow / beetle) }
unit uGfx;

{$mode objfpc}{$H+}
{$Q-}{$R-}

interface

uses
  Classes, SysUtils, Math, BGRABitmap, BGRABitmapTypes, BGRAGraphics, uWaveEngine, uGameData;

type

  { TTextCache }

  TTextCache = class
  private
    FList: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Get(const S: string; ASize: Integer; const ACol: TBGRAPixel; ABold: Boolean;
      const AFont: string; AShadow: Boolean): TBGRABitmap;
    procedure Draw(Bmp: TBGRABitmap; X, Y: Single; const S: string; ASize: Integer;
      const ACol: TBGRAPixel; AAlign: TAlignment; ABold: Boolean = True;
      const AFont: string = 'Segoe UI'; AShadow: Boolean = True);
    function Width(const S: string; ASize: Integer; ABold: Boolean = True; const AFont: string = 'Segoe UI'): Integer;
  end;

  { TGlowCache }

  TGlowCache = class
  private
    FList: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Get(ARadius: Integer; const C: TBGRAPixel): TBGRABitmap;
    procedure Draw(Bmp: TBGRABitmap; X, Y: Single; ARadius: Integer; const C: TBGRAPixel; AOpacity: Byte);
  end;

  TDotLayout = class
    W, H: Integer;
    Pts: array of TPoint;      { dot centers relative to the text box (device px) }
    Glow: TBGRABitmap;         { blurred mask for the halo }
    destructor Destroy; override;
  end;

  { TDotText }

  TDotText = class
  private
    FList: TStringList;
    FLut: array[0..255] of TBGRAPixel;
    FLutPal: Integer;
    FLutSat: Single;
    function Layout(const S: string; ASizePx: Integer; ASpacing: Single; AGlow: Boolean): TDotLayout;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    { CX = horizontal center, Y = top (device px). K = device px per reference px. }
    procedure Draw(Bmp: TBGRABitmap; const S: string; CX, Y: Single; ASizeRef: Single;
      const Fx: TScreenFx; K, Time: Single; AAlpha: Byte = 255);
    function TextWidth(const S: string; ASizeRef, K: Single): Integer;
  end;

function HueToColor(AHue: Single; AAlpha: Byte = 255): TBGRAPixel;
function PearlMix(const C: TBGRAPixel; AAmount: Single): TBGRAPixel;
function ColorForMode(AMode: Integer; const C1: TBGRAPixel; T: Single): TBGRAPixel;
procedure BlendRect(Bmp: TBGRABitmap; X0, Y0, X1, Y1: Integer; const C: TBGRAPixel; A: Integer);
procedure Posterize(Bmp: TBGRABitmap; ALevels: Integer);
procedure DimRect(Bmp: TBGRABitmap; AAmount: Single);

implementation

function PearlMix(const C: TBGRAPixel; AAmount: Single): TBGRAPixel;
begin
  { mother-of-pearl: mostly white with an iridescent tint }
  AAmount := EnsureRange(AAmount, 0, 1);
  Result.red := Round(255 + (C.red - 255) * AAmount);
  Result.green := Round(255 + (C.green - 255) * AAmount);
  Result.blue := Round(255 + (C.blue - 255) * AAmount);
  Result.alpha := 255;
end;

function HueToColor(AHue: Single; AAlpha: Byte): TBGRAPixel;
var
  h, f: Single;
  i: Integer;
  q, t: Byte;
begin
  h := AHue - Floor(AHue);
  h := h * 6;
  i := Trunc(h);
  f := h - i;
  q := Round(255 * (1 - f));
  t := Round(255 * f);
  case i of
    0: Result := BGRA(255, t, 0, AAlpha);
    1: Result := BGRA(q, 255, 0, AAlpha);
    2: Result := BGRA(0, 255, t, AAlpha);
    3: Result := BGRA(0, q, 255, AAlpha);
    4: Result := BGRA(t, 0, 255, AAlpha);
  else
    Result := BGRA(255, 0, q, AAlpha);
  end;
  Result.red := 70 + Result.red * 185 div 255;
  Result.green := 70 + Result.green * 185 div 255;
  Result.blue := 70 + Result.blue * 185 div 255;
end;

function ColorForMode(AMode: Integer; const C1: TBGRAPixel; T: Single): TBGRAPixel;
begin
  case AMode of
    CM_HUE: Result := HueToColor(T);
    CM_PEARL: Result := PearlMix(IriPaletteColor(1, T, 0.9), 0.5);
    CM_HOLO: Result := IriPaletteColor(3, T, 1.0);
    CM_OIL: Result := IriPaletteColor(2, T, 1.0);
    CM_RAINBOW: Result := IriPaletteColor(0, T, 1.1);
    CM_BEETLE: Result := IriPaletteColor(4, T, 1.0);
  else
    Result := C1;
  end;
  Result.alpha := 255;
end;

procedure BlendRect(Bmp: TBGRABitmap; X0, Y0, X1, Y1: Integer; const C: TBGRAPixel; A: Integer);
var
  x, y: Integer;
  p: PBGRAPixel;
begin
  if A <= 0 then Exit;
  if A > 256 then A := 256;
  if X0 < 0 then X0 := 0;
  if Y0 < 0 then Y0 := 0;
  if X1 > Bmp.Width then X1 := Bmp.Width;
  if Y1 > Bmp.Height then Y1 := Bmp.Height;
  for y := Y0 to Y1 - 1 do
  begin
    p := Bmp.ScanLine[y] + X0;
    for x := X0 to X1 - 1 do
    begin
      p^.red := p^.red + ((C.red - p^.red) * A) div 256;
      p^.green := p^.green + ((C.green - p^.green) * A) div 256;
      p^.blue := p^.blue + ((C.blue - p^.blue) * A) div 256;
      Inc(p);
    end;
  end;
end;

procedure DimRect(Bmp: TBGRABitmap; AAmount: Single);
var
  n, m: Integer;
  p: PBGRAPixel;
begin
  if AAmount <= 0.004 then Exit;
  m := Round(256 * (1 - EnsureRange(AAmount, 0, 1)));
  p := Bmp.Data;
  for n := 1 to Bmp.NbPixels do
  begin
    p^.red := (p^.red * m) shr 8;
    p^.green := (p^.green * m) shr 8;
    p^.blue := (p^.blue * m) shr 8;
    Inc(p);
  end;
  Bmp.InvalidateBitmap;
end;

procedure Posterize(Bmp: TBGRABitmap; ALevels: Integer);
var
  lut: array[0..255] of Byte;
  i: Integer;
  p: PBGRAPixel;
begin
  if ALevels < 2 then Exit;
  for i := 0 to 255 do
    lut[i] := Round(Round(i / 255 * (ALevels - 1)) * 255 / (ALevels - 1));
  p := Bmp.Data;
  for i := 1 to Bmp.NbPixels do
  begin
    p^.red := lut[p^.red];
    p^.green := lut[p^.green];
    p^.blue := lut[p^.blue];
    Inc(p);
  end;
  Bmp.InvalidateBitmap;
end;

procedure SetFont(B: TBGRABitmap; ASize: Integer; ABold: Boolean; const AFont: string);
begin
  B.FontName := AFont;
  B.FontHeight := Max(6, ASize);
  if ABold then B.FontStyle := [fsBold] else B.FontStyle := [];
  B.FontQuality := fqFineAntialiasing;
end;

{ TTextCache }

constructor TTextCache.Create;
begin
  FList := TStringList.Create;
  FList.Sorted := True;
end;

destructor TTextCache.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TTextCache.Clear;
var
  i: Integer;
begin
  for i := 0 to FList.Count - 1 do FList.Objects[i].Free;
  FList.Clear;
end;

function TTextCache.Get(const S: string; ASize: Integer; const ACol: TBGRAPixel; ABold: Boolean;
  const AFont: string; AShadow: Boolean): TBGRABitmap;
var
  key: string;
  idx, off, cr, cg, cb: Integer;
  tmp: TBGRABitmap;
  sz: TSize;
begin
  cr := Min(255, (ACol.red + 8) and $1F0);
  cg := Min(255, (ACol.green + 8) and $1F0);
  cb := Min(255, (ACol.blue + 8) and $1F0);
  key := Format('%s|%d|%d|%d|%.2x%.2x%.2x|%s', [AFont, ASize, Ord(ABold), Ord(AShadow), cr, cg, cb, S]);
  idx := FList.IndexOf(key);
  if idx >= 0 then Exit(TBGRABitmap(FList.Objects[idx]));
  if FList.Count > 400 then Clear;
  off := Max(1, ASize div 16);
  tmp := TBGRABitmap.Create(1, 1);
  try
    SetFont(tmp, ASize, ABold, AFont);
    sz := tmp.TextSize(S);
  finally
    tmp.Free;
  end;
  Result := TBGRABitmap.Create(Max(1, sz.cx + off + 2), Max(1, sz.cy + off + 2), BGRAPixelTransparent);
  SetFont(Result, ASize, ABold, AFont);
  if AShadow then Result.TextOut(off, off, S, BGRA(0, 0, 0, 190));
  Result.TextOut(0, 0, S, BGRA(cr, cg, cb, 255));
  FList.AddObject(key, Result);
end;

procedure TTextCache.Draw(Bmp: TBGRABitmap; X, Y: Single; const S: string; ASize: Integer;
  const ACol: TBGRAPixel; AAlign: TAlignment; ABold: Boolean; const AFont: string; AShadow: Boolean);
var
  spr: TBGRABitmap;
  off: Integer;
begin
  if (S = '') or (ACol.alpha = 0) then Exit;
  spr := Get(S, ASize, ACol, ABold, AFont, AShadow);
  off := Max(1, ASize div 16) + 2;
  case AAlign of
    taCenter: X := X - (spr.Width - off) / 2;
    taRightJustify: X := X - (spr.Width - off);
  end;
  Bmp.PutImage(Round(X), Round(Y), spr, dmDrawWithTransparency, ACol.alpha);
end;

function TTextCache.Width(const S: string; ASize: Integer; ABold: Boolean; const AFont: string): Integer;
begin
  Result := Get(S, ASize, BGRAWhite, ABold, AFont, True).Width - Max(1, ASize div 16) - 2;
end;

{ TGlowCache }

constructor TGlowCache.Create;
begin
  FList := TStringList.Create;
  FList.Sorted := True;
end;

destructor TGlowCache.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TGlowCache.Clear;
var
  i: Integer;
begin
  for i := 0 to FList.Count - 1 do FList.Objects[i].Free;
  FList.Clear;
end;

function TGlowCache.Get(ARadius: Integer; const C: TBGRAPixel): TBGRABitmap;
var
  key: string;
  idx, r, g, b: Integer;
begin
  ARadius := Max(2, ARadius);
  r := Min(255, (C.red + 8) and $1F0);
  g := Min(255, (C.green + 8) and $1F0);
  b := Min(255, (C.blue + 8) and $1F0);
  key := Format('%d|%.2x%.2x%.2x', [ARadius, r, g, b]);
  idx := FList.IndexOf(key);
  if idx >= 0 then Exit(TBGRABitmap(FList.Objects[idx]));
  if FList.Count > 300 then Clear;
  Result := TBGRABitmap.Create(ARadius * 2, ARadius * 2, BGRAPixelTransparent);
  Result.GradientFill(0, 0, ARadius * 2, ARadius * 2,
    BGRA(r, g, b, 200), BGRA(r, g, b, 0), gtRadial,
    PointF(ARadius, ARadius), PointF(ARadius * 2, ARadius), dmSet);
  FList.AddObject(key, Result);
end;

procedure TGlowCache.Draw(Bmp: TBGRABitmap; X, Y: Single; ARadius: Integer; const C: TBGRAPixel; AOpacity: Byte);
var
  g: TBGRABitmap;
begin
  if (ARadius < 2) or (AOpacity = 0) then Exit;
  g := Get(ARadius, C);
  Bmp.BlendImageOver(Round(X) - g.Width div 2, Round(Y) - g.Height div 2, g, boAdditive, AOpacity);
end;

{ TDotLayout }

destructor TDotLayout.Destroy;
begin
  Glow.Free;
  inherited Destroy;
end;

{ TDotText }

constructor TDotText.Create;
begin
  FList := TStringList.Create;
  FList.Sorted := True;
  FLutPal := -1;
end;

destructor TDotText.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TDotText.Clear;
var
  i: Integer;
begin
  for i := 0 to FList.Count - 1 do FList.Objects[i].Free;
  FList.Clear;
end;

function TDotText.Layout(const S: string; ASizePx: Integer; ASpacing: Single; AGlow: Boolean): TDotLayout;
var
  key: string;
  idx, n, gx, gy, cols, rows, x, y: Integer;

  mask, blur: TBGRABitmap;
  sz: TSize;
  p: PBGRAPixel;
begin
  ASpacing := Max(1.2, ASpacing);
  key := Format('%d|%.2f|%d|%s', [ASizePx, ASpacing, Ord(AGlow), S]);
  idx := FList.IndexOf(key);
  if idx >= 0 then Exit(TDotLayout(FList.Objects[idx]));
  if FList.Count > 120 then Clear;

  mask := TBGRABitmap.Create(1, 1);
  SetFont(mask, ASizePx, True, 'Segoe UI');
  sz := mask.TextSize(S);
  mask.SetSize(Max(1, sz.cx + 4), Max(1, sz.cy + 4));
  mask.Fill(BGRAPixelTransparent);
  mask.TextOut(2, 2, S, BGRAWhite);

  Result := TDotLayout.Create;
  Result.W := mask.Width;
  Result.H := mask.Height;
  cols := Trunc(mask.Width / ASpacing);
  rows := Trunc(mask.Height / ASpacing);
  SetLength(Result.Pts, cols * rows);
  n := 0;
  for gy := 0 to rows - 1 do
  begin
    y := Round((gy + 0.5) * ASpacing);
    if y >= mask.Height then Continue;
    p := mask.ScanLine[y];
    for gx := 0 to cols - 1 do
    begin
      x := Round((gx + 0.5) * ASpacing);
      if x >= mask.Width then Continue;
      if (p + x)^.alpha > 110 then
      begin
        Result.Pts[n] := Point(x, y);
        Inc(n);
      end;
    end;
  end;
  SetLength(Result.Pts, n);
  if AGlow then
  begin
    blur := mask.FilterBlurRadial(Max(2, ASizePx div 7), rbFast) as TBGRABitmap;
    { premultiply: additive blending must not add the colour of transparent pixels }
    p := blur.Data;
    for n := 1 to blur.NbPixels do
    begin
      p^.red := p^.alpha;
      p^.green := p^.alpha;
      p^.blue := p^.alpha;
      p^.alpha := 255;
      Inc(p);
    end;
    blur.InvalidateBitmap;
    Result.Glow := blur;
  end;
  mask.Free;
  FList.AddObject(key, Result);
end;

function TDotText.TextWidth(const S: string; ASizeRef, K: Single): Integer;
var
  tmp: TBGRABitmap;
begin
  tmp := TBGRABitmap.Create(1, 1);
  try
    SetFont(tmp, Round(ASizeRef * K), True, 'Segoe UI');
    Result := tmp.TextSize(S).cx;
  finally
    tmp.Free;
  end;
end;

procedure TDotText.Draw(Bmp: TBGRABitmap; const S: string; CX, Y: Single; ASizeRef: Single;
  const Fx: TScreenFx; K, Time: Single; AAlpha: Byte);
var
  lay: TDotLayout;
  i, li, ds, x0, y0, px, py, a, hsh: Integer;
  u, v, t, band, sweep, bright, dy, spacing, dsRef: Single;
  c: TBGRAPixel;
begin
  if (S = '') or (AAlpha = 0) then Exit;
  { small text gets a finer grid so it stays readable }
  dsRef := Min(Fx.DotSpacing, ASizeRef / 13);
  spacing := Max(1.2, dsRef * K);
  lay := Layout(S, Max(8, Round(ASizeRef * K)), spacing, Fx.Glow > 0.01);

  { palette LUT for this frame }
  if (FLutPal <> Fx.Palette) or (FLutSat <> Fx.Saturation) then
  begin
    { Saturation also sets how much of the white pearl body shows through }
    for i := 0 to 255 do
      FLut[i] := PearlMix(IriPaletteColor(Fx.Palette, i / 256, 1.0), Min(1, Fx.Saturation * 0.7));
    FLutPal := Fx.Palette;
    FLutSat := Fx.Saturation;
  end;

  x0 := Round(CX - lay.W / 2);
  y0 := Round(Y);
  if (lay.Glow <> nil) and (Fx.Glow > 0.01) then
    Bmp.BlendImageOver(x0, y0, lay.Glow, boAdditive, Round(EnsureRange(Fx.Glow * 0.55, 0, 1) * AAlpha));

  ds := Max(1, Round(Fx.DotSize * dsRef / Max(0.1, Fx.DotSpacing) * K));
  sweep := Frac(Time * Fx.ShimmerSpeed) * 1.8 - 0.4;
  for i := 0 to High(lay.Pts) do
  begin
    u := lay.Pts[i].x / Max(1, lay.W);
    v := lay.Pts[i].y / Max(1, lay.H);
    t := u * Fx.HueScale * 0.5 + v * 0.35 + Time * Fx.HueSpeed;
    li := Trunc((t - Floor(t)) * 256) and 255;
    c := FLut[li];
    { pearl shimmer: soft light band sweeping across + sparkle }
    band := Exp(-Sqr((u - sweep - v * 0.25) * 5));
    bright := (1 - Fx.Shimmer * 0.45) + Fx.Shimmer * 0.8 * band;
    hsh := (lay.Pts[i].x * 73856093) xor (lay.Pts[i].y * 19349663) xor Trunc(Time * 9) * 83492791;
    if (hsh and 255) < 3 then bright := bright + 0.6 * Fx.Shimmer;
    c.red := Min(255, Round(c.red * bright));
    c.green := Min(255, Round(c.green * bright));
    c.blue := Min(255, Round(c.blue * bright));
    dy := Sin(lay.Pts[i].x / K * Fx.DotWaveFreq + Time * Fx.DotWaveSpeed) * Fx.DotWave * K;
    px := x0 + lay.Pts[i].x - ds div 2;
    py := y0 + lay.Pts[i].y - ds div 2 + Round(dy);
    a := AAlpha + 1;
    if Fx.DotRound and (ds >= 3) then
    begin
      BlendRect(Bmp, px + 1, py, px + ds - 1, py + ds, c, a);
      BlendRect(Bmp, px, py + 1, px + 1, py + ds - 1, c, a);
      BlendRect(Bmp, px + ds - 1, py + 1, px + ds, py + ds - 1, c, a);
    end
    else
      BlendRect(Bmp, px, py, px + ds, py + ds, c, a);
  end;
end;

end.

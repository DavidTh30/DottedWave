{ WaveRider Light FX - spectral ray tracing of light through glass.

  A white beam is traced as N wavelength bands (red .. violet). Every band
  uses its own refractive index  n(t) = Index + Dispersion * (t - 0.5),
  so the bands overlap (and add up to white) until glass splits them into a
  rainbow fan. Optics:
    Dispersion Prism     one triangular prism
    Newton's Prisms      two prisms, the second one spreads the spectrum again
    Diffraction Grating  a line that splits every band into orders m = -n..n
                         with sin(out) = sin(in) + m * lambda * pitch
    Diamond              brilliant cut, n = 2.42: total internal reflection
                         throws the "fire" out in many directions
  Rays are drawn into an additive float layer (soft core + halo), so
  overlapping colours mix like light, then composited onto the frame. }
unit uLightFx;

{$mode objfpc}{$H+}
{$Q-}{$R-}

interface

uses
  Classes, SysUtils, Math, IniFiles, BGRABitmap, BGRABitmapTypes, uParams;

const
  LIGHT_KINDS = 'Dispersion Prism|Newton''s Prisms|Diffraction Grating|Diamond';
  LIGHT_SCENES = 'None|Dispersion Prism|Newton''s Prisms|Diffraction Grating|Diamond';
  LK_PRISM = 0; LK_NEWTON = 1; LK_GRATING = 2; LK_DIAMOND = 3;
  MAX_BANDS = 32;

type
  TLightDef = record
    Name: string;
    Index, Dispersion: Single;
    Bands: Integer;
    BeamWidth, Glow, Intensity, InnerGlow: Single;
    Size, Tilt, Swing, SwingSpeed: Single;
    Pitch: Single;            { grating spread }
    Orders: Integer;          { grating orders +-n }
    MaxBounce: Integer;
    GlassAlpha, EdgeGlow: Single;
    BeamLength: Single;
    Reflect: Single;          { partial reflection strength }
  end;
  TLightDefs = array[0..3] of TLightDef;

  TOpticElem = record
    IsGrating: Boolean;
    Pts: array of TPointF;     { closed convex polygon, counter clockwise }
    Center: TPointF;
    N, Disp: Single;
    A, B: TPointF;             { grating segment }
    Pitch: Single;
    Orders: Integer;
    Facets: array of TPointF;  { decorative inner lines (pairs) }
  end;

  TLightSeg = record
    X0, Y0, X1, Y1: Single;
    R, G, B: Single;
    Inside: Boolean;
  end;

  { TLightLayer - additive float RGB layer }

  TLightLayer = class
  private
    FAcc: array of Single;
    FW, FH: Integer;
    FMinX, FMinY, FMaxX, FMaxY: Integer;
    FProfile: array of Single;
    procedure Touch(X0, Y0, X1, Y1: Integer);
  public
    ClipX0, ClipY0, ClipX1, ClipY1: Single;   { device px, set by SetClip }
    procedure Start(AW, AH: Integer);
    procedure SetClip(X0, Y0, X1, Y1: Single);
    procedure NoClip;
    procedure Line(X0, Y0, X1, Y1, R, G, B, W, AGlow: Single);
    procedure Dot(X, Y, ARadius, R, G, B: Single);
    procedure Composite(Bmp: TBGRABitmap);
    function Used: Boolean;
  end;

  { TLightScene }

  TLightScene = class
  private
    FDef: TLightDef;
    FBandT: array[0..MAX_BANDS - 1] of Single;
    FBandC: array[0..MAX_BANDS - 1, 0..2] of Single;
    FBands: Integer;
    procedure AddSeg(X0, Y0, X1, Y1: Single; const C: array of Single; AInt: Single; AInside: Boolean);
    procedure TraceBand(OX, OY, DX, DY: Single; ABand, ADepth: Integer; AInt: Single; AInside: Integer);
    procedure PrepareBands;
  public
    Elems: array of TOpticElem;
    Segs: array of TLightSeg;
    SegCount: Integer;
    SourceX, SourceY: Single;
    procedure Clear;
    procedure AddPrism(CX, CY, ASize, AAngle, AIndex, ADisp: Single);
    procedure AddDiamond(CX, CY, ASize, AAngle, AIndex, ADisp: Single);
    procedure AddGrating(CX, CY, ALen, AAngle, APitch: Single; AOrders: Integer);
    procedure Shoot(X, Y, AAngle: Single; const D: TLightDef);
    procedure DrawLight(Layer: TLightLayer; K, AIntensity: Single);
    procedure DrawGlass(Bmp: TBGRABitmap; K, AAlpha: Single; ATime: Single);
    function HitsCircle(CX, CY, R: Single): Boolean;
    { traces one ray of index AN through the glass elements; True when it entered
      the glass and came out again. (PX,PY) exit point, (EX,EY) exit direction. }
    function ProbeExit(OX, OY, DX, DY, AN: Single; out PX, PY, EX, EY: Single): Boolean;
  end;

function DefaultLightDef(AKind: Integer): TLightDef;
procedure DescribeLightDef(var B: TPBuilder; var D: TLightDef);
procedure SaveLightDefs(const AFile: string; const L: TLightDefs);
procedure LoadLightDefs(const AFile: string; var L: TLightDefs);
{ builds the classic demo setup of a kind around (CX,CY), scale S (ref px) }
procedure BuildKindScene(Scene: TLightScene; AKind: Integer; const D: TLightDef; CX, CY, S, ATime: Single);
{ ship beam: the optic hovers above the ship, the beam goes straight up into it }
procedure BuildBeamScene(Scene: TLightScene; AKind: Integer; const D: TLightDef; SX, SY, ATime: Single);
procedure SpectrumRGB(T: Single; out R, G, B: Single);

implementation

{ ---------------- spectrum ---------------- }

procedure SpectrumRGB(T: Single; out R, G, B: Single);
var
  w, f: Single;
begin
  { t = 0 red (700 nm) .. 1 violet (400 nm), after Dan Bruton }
  w := 700 - 300 * EnsureRange(T, 0, 1);
  if w < 440 then begin R := (440 - w) / 60; G := 0; B := 1; end
  else if w < 490 then begin R := 0; G := (w - 440) / 50; B := 1; end
  else if w < 510 then begin R := 0; G := 1; B := (510 - w) / 20; end
  else if w < 580 then begin R := (w - 510) / 70; G := 1; B := 0; end
  else if w < 645 then begin R := 1; G := (645 - w) / 65; B := 0; end
  else begin R := 1; G := 0; B := 0; end;
  if w < 420 then f := 0.3 + 0.7 * (w - 400) / 20
  else if w > 680 then f := 0.3 + 0.7 * (700 - w) / 20
  else f := 1;
  R := R * f; G := G * f; B := B * f;
end;

{ ---------------- defaults / io ---------------- }

function DefaultLightDef(AKind: Integer): TLightDef;
begin
  Result := Default(TLightDef);
  Result.Name := EnumName(LIGHT_KINDS, AKind);
  Result.Index := 1.52;
  Result.Dispersion := 0.08;
  Result.Bands := 14;
  Result.BeamWidth := 1.8;
  Result.Glow := 1.0;
  Result.Intensity := 1.1;
  Result.InnerGlow := 0.35;
  Result.Size := 120;
  Result.Tilt := 0;
  Result.Swing := 8;
  Result.SwingSpeed := 0.6;
  Result.Pitch := 0.55;
  Result.Orders := 2;
  Result.MaxBounce := 6;
  Result.GlassAlpha := 0.6;
  Result.EdgeGlow := 0.8;
  Result.BeamLength := 1600;
  Result.Reflect := 0.12;
  case AKind of
    LK_NEWTON: begin Result.Dispersion := 0.1; Result.Size := 95; end;
    LK_GRATING: begin Result.Bands := 12; Result.Pitch := 0.6; Result.Orders := 2; end;
    LK_DIAMOND: begin Result.Index := 2.42; Result.Dispersion := 0.3; Result.MaxBounce := 9; Result.Reflect := 0.3;
      Result.Bands := 12; Result.InnerGlow := 0.45; Result.Intensity := 1.2; end;
  end;
end;

procedure DescribeLightDef(var B: TPBuilder; var D: TLightDef);
begin
  B.G('Glass');
  B.S('name', 'Name', @D.Name);
  B.F('index', 'Refractive index', @D.Index, 1.0, 3.0, 3, 'Glass 1.5, diamond 2.42');
  B.F('dispersion', 'Dispersion', @D.Dispersion, 0, 0.6, 3, 'How far the colours split');
  B.F('size', 'Size', @D.Size, 20, 400, 0, 'Optic size (reference px)');
  B.F('tilt', 'Tilt (deg)', @D.Tilt, -90, 90, 1);
  B.F('swing', 'Swing (deg)', @D.Swing, 0, 45, 1, 'Animated rotation amplitude');
  B.F('swingSpeed', 'Swing speed', @D.SwingSpeed, 0, 5, 2);
  B.F('glassAlpha', 'Glass opacity', @D.GlassAlpha, 0, 1, 2);
  B.F('edgeGlow', 'Edge glow', @D.EdgeGlow, 0, 2, 2);
  B.G('Light');
  B.I('bands', 'Spectral bands', @D.Bands, 3, MAX_BANDS, 'More bands = smoother rainbow, slower');
  B.F('beamWidth', 'Beam width', @D.BeamWidth, 0.5, 8, 2);
  B.F('glow', 'Halo', @D.Glow, 0, 3, 2);
  B.F('intensity', 'Intensity', @D.Intensity, 0, 3, 2);
  B.F('innerGlow', 'Inside glass', @D.InnerGlow, 0, 1.5, 2, 'Brightness of the beam inside the glass');
  B.I('maxBounce', 'Max bounces', @D.MaxBounce, 1, 16);
  B.F('beamLength', 'Beam length', @D.BeamLength, 100, 4000, 0);
  B.F('reflect', 'Partial reflection', @D.Reflect, 0, 0.8, 2, 'Fresnel reflections: more sparkle, more beams');
  B.G('Grating');
  B.F('pitch', 'Pitch (spread)', @D.Pitch, 0.05, 1.5, 3, 'sin(out) = sin(in) + m * lambda * pitch');
  B.I('orders', 'Orders +-', @D.Orders, 0, 4);
end;

procedure SaveLightDefs(const AFile: string; const L: TLightDefs);
var
  ini: TMemIniFile;
  i: Integer;
  b: TPBuilder;
  tmp: TLightDefs;
begin
  tmp := L;
  ForceDirectories(ExtractFilePath(AFile));
  ini := TMemIniFile.Create(AFile);
  try
    ini.Clear;
    for i := 0 to 3 do
    begin
      b.Clear;
      DescribeLightDef(b, tmp[i]);
      WriteDescs(ini, 'Light' + IntToStr(i), b.List);
    end;
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

procedure LoadLightDefs(const AFile: string; var L: TLightDefs);
var
  ini: TMemIniFile;
  i: Integer;
  b: TPBuilder;
begin
  if not FileExists(AFile) then Exit;
  ini := TMemIniFile.Create(AFile);
  try
    for i := 0 to 3 do
    begin
      b.Clear;
      DescribeLightDef(b, L[i]);
      ReadDescs(ini, 'Light' + IntToStr(i), b.List);
    end;
  finally
    ini.Free;
  end;
end;

{ ---------------- layer ---------------- }

procedure TLightLayer.Start(AW, AH: Integer);
begin
  if (AW <> FW) or (AH <> FH) then
  begin
    FW := AW; FH := AH;
    SetLength(FAcc, AW * AH * 3);
    FillChar(FAcc[0], Length(FAcc) * SizeOf(Single), 0);
  end;
  FMinX := FW; FMinY := FH; FMaxX := -1; FMaxY := -1;
  NoClip;
end;

procedure TLightLayer.SetClip(X0, Y0, X1, Y1: Single);
begin
  ClipX0 := Max(0, X0); ClipY0 := Max(0, Y0);
  ClipX1 := Min(FW - 1, X1); ClipY1 := Min(FH - 1, Y1);
end;

procedure TLightLayer.NoClip;
begin
  ClipX0 := 0; ClipY0 := 0; ClipX1 := FW - 1; ClipY1 := FH - 1;
end;

function TLightLayer.Used: Boolean;
begin
  Result := FMaxX >= FMinX;
end;

procedure TLightLayer.Touch(X0, Y0, X1, Y1: Integer);
begin
  if X0 < FMinX then FMinX := Max(0, X0);
  if Y0 < FMinY then FMinY := Max(0, Y0);
  if X1 > FMaxX then FMaxX := Min(FW - 1, X1);
  if Y1 > FMaxY then FMaxY := Min(FH - 1, Y1);
end;

procedure TLightLayer.Line(X0, Y0, X1, Y1, R, G, B, W, AGlow: Single);
var
  dx, dy, len, rad, t0, t1, p, q, d, f, inv, hw, xs, ys: Single;
  i, a0, a1, b0, b1, a, k, nl, li: Integer;
  steep: Boolean;
  pp: array[0..3] of Single;
  qq: array[0..3] of Single;
begin
  if FW = 0 then Exit;
  W := Max(0.5, W);
  hw := W * 2.6;                          { halo width }
  if AGlow > 0.01 then rad := Ceil(hw * 1.7) else rad := Ceil(W * 2.2);
  { radial profile lookup (8 samples per pixel) instead of Exp per pixel }
  nl := Round(rad * 8) + 2;
  if Length(FProfile) < nl then SetLength(FProfile, nl);
  for i := 0 to nl - 1 do
  begin
    p := i / 8;
    f := Exp(-Sqr(p / W));
    if AGlow > 0.01 then f := f + AGlow * 0.22 * Exp(-Sqr(p / hw));
    FProfile[i] := f;
  end;
  { clip the segment to the layer (expanded) - Liang Barsky }
  dx := X1 - X0; dy := Y1 - Y0;
  t0 := 0; t1 := 1;
  pp[0] := -dx; qq[0] := X0 - ClipX0;
  pp[1] := dx;  qq[1] := ClipX1 - X0;
  pp[2] := -dy; qq[2] := Y0 - ClipY0;
  pp[3] := dy;  qq[3] := ClipY1 - Y0;
  for i := 0 to 3 do
  begin
    p := pp[i]; q := qq[i];
    if Abs(p) < 1e-9 then
    begin
      if q < 0 then Exit;
    end
    else
    begin
      f := q / p;
      if p < 0 then begin if f > t1 then Exit; if f > t0 then t0 := f; end
      else begin if f < t0 then Exit; if f < t1 then t1 := f; end;
    end;
  end;
  xs := X0 + dx * t0; ys := Y0 + dy * t0;
  X1 := X0 + dx * t1; Y1 := Y0 + dy * t1;
  X0 := xs; Y0 := ys;
  dx := X1 - X0; dy := Y1 - Y0;
  len := Sqrt(dx * dx + dy * dy);
  if len < 0.3 then Exit;
  steep := Abs(dy) > Abs(dx);
  if steep then
  begin
    a0 := Floor(Min(Y0, Y1)); a1 := Ceil(Max(Y0, Y1));
    inv := Abs(dy) / len;          { perpendicular distance factor for a horizontal offset }
  end
  else
  begin
    a0 := Floor(Min(X0, X1)); a1 := Ceil(Max(X0, X1));
    inv := Abs(dx) / len;
  end;
  if steep then a0 := Max(a0, 0) else a0 := Max(a0, 0);
  if steep then a1 := Min(a1, FH - 1) else a1 := Min(a1, FW - 1);
  for a := a0 to a1 do
  begin
    { centre of the line on the minor axis at this major coordinate }
    if steep then
    begin
      if Abs(dy) < 1e-6 then Continue;
      d := X0 + (a - Y0) * dx / dy;
    end
    else
    begin
      if Abs(dx) < 1e-6 then Continue;
      d := Y0 + (a - X0) * dy / dx;
    end;
    if steep then
    begin
      b0 := Max(Round(ClipX0), Floor(d - rad));
      b1 := Min(Round(ClipX1), Ceil(d + rad));
    end
    else
    begin
      b0 := Max(Round(ClipY0), Floor(d - rad));
      b1 := Min(Round(ClipY1), Ceil(d + rad));
    end;
    for k := b0 to b1 do
    begin
      li := Round(Abs(k - d) * inv * 8);             { true perpendicular distance }
      if li >= nl then Continue;
      f := FProfile[li];
      if f < 0.004 then Continue;
      if steep then i := (a * FW + k) * 3 else i := (k * FW + a) * 3;
      FAcc[i] := FAcc[i] + R * f;
      FAcc[i + 1] := FAcc[i + 1] + G * f;
      FAcc[i + 2] := FAcc[i + 2] + B * f;
    end;
    if steep then Touch(b0, a, b1, a) else Touch(a, b0, a, b1);
  end;
end;

procedure TLightLayer.Dot(X, Y, ARadius, R, G, B: Single);
var
  x0, y0, x1, y1, xx, yy, i: Integer;
  f: Single;
begin
  if (FW = 0) or (ARadius < 0.5) then Exit;
  x0 := Max(0, Floor(X - ARadius * 2)); x1 := Min(FW - 1, Ceil(X + ARadius * 2));
  y0 := Max(0, Floor(Y - ARadius * 2)); y1 := Min(FH - 1, Ceil(Y + ARadius * 2));
  if (x1 < x0) or (y1 < y0) then Exit;
  for yy := y0 to y1 do
    for xx := x0 to x1 do
    begin
      f := Exp(-(Sqr(xx - X) + Sqr(yy - Y)) / Sqr(ARadius));
      if f < 0.004 then Continue;
      i := (yy * FW + xx) * 3;
      FAcc[i] := FAcc[i] + R * f;
      FAcc[i + 1] := FAcc[i + 1] + G * f;
      FAcc[i + 2] := FAcc[i + 2] + B * f;
    end;
  Touch(x0, y0, x1, y1);
end;

procedure TLightLayer.Composite(Bmp: TBGRABitmap);
var
  x, y, i: Integer;
  p: PBGRAPixel;
  r, g, b: Single;
begin
  if not Used then Exit;
  if (Bmp.Width <> FW) or (Bmp.Height <> FH) then Exit;
  for y := FMinY to FMaxY do
  begin
    p := Bmp.ScanLine[y] + FMinX;
    i := (y * FW + FMinX) * 3;
    for x := FMinX to FMaxX do
    begin
      r := FAcc[i]; g := FAcc[i + 1]; b := FAcc[i + 2];
      if (r > 0.002) or (g > 0.002) or (b > 0.002) then
      begin
        { additive light with a soft shoulder so bright cores stay white, not clipped flat }
        p^.red := Min(255, p^.red + Round(255 * (1 - Exp(-r * 1.6))));
        p^.green := Min(255, p^.green + Round(255 * (1 - Exp(-g * 1.6))));
        p^.blue := Min(255, p^.blue + Round(255 * (1 - Exp(-b * 1.6))));
        FAcc[i] := 0; FAcc[i + 1] := 0; FAcc[i + 2] := 0;
      end;
      Inc(p);
      Inc(i, 3);
    end;
  end;
  Bmp.InvalidateBitmap;
  FMinX := FW; FMinY := FH; FMaxX := -1; FMaxY := -1;
end;

{ ---------------- scene ---------------- }

procedure TLightScene.Clear;
begin
  Elems := nil;
  SegCount := 0;
end;

function Rot(const P: TPointF; A: Single): TPointF;
begin
  Result := PointF(P.x * Cos(A) - P.y * Sin(A), P.x * Sin(A) + P.y * Cos(A));
end;

procedure TLightScene.AddPrism(CX, CY, ASize, AAngle, AIndex, ADisp: Single);
var
  e: TOpticElem;
  i: Integer;
begin
  e := Default(TOpticElem);
  SetLength(e.Pts, 3);
  for i := 0 to 2 do
    e.Pts[i] := Rot(PointF(Cos(-Pi / 2 + i * 2 * Pi / 3) * ASize * 0.62, Sin(-Pi / 2 + i * 2 * Pi / 3) * ASize * 0.62), AAngle)
      + PointF(CX, CY);
  e.Center := PointF(CX, CY);
  e.N := AIndex;
  e.Disp := ADisp;
  SetLength(Elems, Length(Elems) + 1);
  Elems[High(Elems)] := e;
end;

procedure TLightScene.AddDiamond(CX, CY, ASize, AAngle, AIndex, ADisp: Single);
const
  { brilliant cut profile: table, crown, girdle, pavilion to culet }
  PX: array[0..6] of Single = (-0.30, 0.30, 0.62, 0.66, 0.0, -0.66, -0.62);
  PY: array[0..6] of Single = (-0.42, -0.42, -0.16, -0.08, 0.62, -0.08, -0.16);
var
  e: TOpticElem;
  i: Integer;
begin
  e := Default(TOpticElem);
  SetLength(e.Pts, 7);
  for i := 0 to 6 do
    e.Pts[i] := Rot(PointF(PX[i] * ASize, PY[i] * ASize), AAngle) + PointF(CX, CY);
  { facet lines for the look }
  SetLength(e.Facets, 10);
  e.Facets[0] := e.Pts[0]; e.Facets[1] := e.Pts[4];
  e.Facets[2] := e.Pts[1]; e.Facets[3] := e.Pts[4];
  e.Facets[4] := e.Pts[6]; e.Facets[5] := e.Pts[2];
  e.Facets[6] := e.Pts[0]; e.Facets[7] := e.Pts[5];
  e.Facets[8] := e.Pts[1]; e.Facets[9] := e.Pts[3];
  e.Center := PointF(CX, CY);
  e.N := AIndex;
  e.Disp := ADisp;
  SetLength(Elems, Length(Elems) + 1);
  Elems[High(Elems)] := e;
end;

procedure TLightScene.AddGrating(CX, CY, ALen, AAngle, APitch: Single; AOrders: Integer);
var
  e: TOpticElem;
begin
  e := Default(TOpticElem);
  e.IsGrating := True;
  e.A := Rot(PointF(0, -ALen / 2), AAngle) + PointF(CX, CY);
  e.B := Rot(PointF(0, ALen / 2), AAngle) + PointF(CX, CY);
  e.Center := PointF(CX, CY);
  e.Pitch := APitch;
  e.Orders := AOrders;
  SetLength(Elems, Length(Elems) + 1);
  Elems[High(Elems)] := e;
end;

procedure TLightScene.PrepareBands;
var
  i: Integer;
  r, g, b, sr, sg, sb: Single;
begin
  FBands := EnsureRange(FDef.Bands, 3, MAX_BANDS);
  sr := 0; sg := 0; sb := 0;
  for i := 0 to FBands - 1 do
  begin
    FBandT[i] := (i + 0.5) / FBands;
    SpectrumRGB(FBandT[i], r, g, b);
    FBandC[i, 0] := r; FBandC[i, 1] := g; FBandC[i, 2] := b;
    sr := sr + r; sg := sg + g; sb := sb + b;
  end;
  { normalise so all bands together give white }
  for i := 0 to FBands - 1 do
  begin
    FBandC[i, 0] := FBandC[i, 0] / Max(1e-6, sr);
    FBandC[i, 1] := FBandC[i, 1] / Max(1e-6, sg);
    FBandC[i, 2] := FBandC[i, 2] / Max(1e-6, sb);
  end;
end;

procedure TLightScene.AddSeg(X0, Y0, X1, Y1: Single; const C: array of Single; AInt: Single; AInside: Boolean);
begin
  if SegCount >= Length(Segs) then SetLength(Segs, Max(64, Length(Segs) * 2));
  Segs[SegCount].X0 := X0; Segs[SegCount].Y0 := Y0;
  Segs[SegCount].X1 := X1; Segs[SegCount].Y1 := Y1;
  Segs[SegCount].R := C[0] * AInt;
  Segs[SegCount].G := C[1] * AInt;
  Segs[SegCount].B := C[2] * AInt;
  Segs[SegCount].Inside := AInside;
  Inc(SegCount);
end;

function RaySeg(OX, OY, DX, DY: Single; const A, B: TPointF; out T, U: Single): Boolean;
var
  ex, ey, den: Single;
begin
  ex := B.x - A.x; ey := B.y - A.y;
  den := DX * ey - DY * ex;
  Result := False;
  if Abs(den) < 1e-9 then Exit;
  T := ((A.x - OX) * ey - (A.y - OY) * ex) / den;
  U := ((A.x - OX) * DY - (A.y - OY) * DX) / den;
  Result := (T > 1e-3) and (U >= 0) and (U <= 1);
end;

procedure TLightScene.TraceBand(OX, OY, DX, DY: Single; ABand, ADepth: Integer; AInt: Single; AInside: Integer);
var
  bounce, i, j, hitE, hitEdge, m, nb: Integer;
  bestT, t, u, nx, ny, cosi, eta, k, n1, n2, nBand, len, sinIn, sinOut, tx, ty, lambda, ang: Single;
  e: TOpticElem;
  inside: Integer;
  c: array[0..2] of Single;
begin
  c[0] := FBandC[ABand, 0]; c[1] := FBandC[ABand, 1]; c[2] := FBandC[ABand, 2];
  inside := AInside;
  for bounce := 0 to FDef.MaxBounce + 2 do
  begin
    if AInt < 0.02 then Exit;
    bestT := 1e9; hitE := -1; hitEdge := -1;
    for i := 0 to High(Elems) do
    begin
      if Elems[i].IsGrating then
      begin
        if RaySeg(OX, OY, DX, DY, Elems[i].A, Elems[i].B, t, u) and (t < bestT) then
        begin
          bestT := t; hitE := i; hitEdge := -1;
        end;
      end
      else
      begin
        nb := Length(Elems[i].Pts);
        for j := 0 to nb - 1 do
          if RaySeg(OX, OY, DX, DY, Elems[i].Pts[j], Elems[i].Pts[(j + 1) mod nb], t, u) and (t < bestT) then
          begin
            bestT := t; hitE := i; hitEdge := j;
          end;
      end;
    end;
    if hitE < 0 then
    begin
      AddSeg(OX, OY, OX + DX * FDef.BeamLength, OY + DY * FDef.BeamLength, c, AInt, inside >= 0);
      Exit;
    end;
    tx := OX + DX * bestT; ty := OY + DY * bestT;
    AddSeg(OX, OY, tx, ty, c, AInt, inside >= 0);
    e := Elems[hitE];
    if e.IsGrating then
    begin
      { diffraction orders }
      if ADepth > 1 then Exit;
      nx := -(e.B.y - e.A.y); ny := e.B.x - e.A.x;          { grating normal }
      len := Sqrt(nx * nx + ny * ny); nx := nx / len; ny := ny / len;
      if nx * DX + ny * DY < 0 then begin nx := -nx; ny := -ny; end;
      sinIn := DX * (-ny) + DY * nx;                          { component along the grating line }
      lambda := 0.75 - 0.35 * FBandT[ABand];                  { long red .. short violet }
      for m := -e.Orders to e.Orders do
      begin
        sinOut := sinIn + m * lambda * e.Pitch;
        if Abs(sinOut) >= 0.999 then Continue;
        ang := ArcSin(sinOut);
        { direction = normal * cos + tangent * sin }
        if m = 0 then k := 0.45 else k := 0.6 / Abs(m);     { IfThen would evaluate 0.6/0 }
        TraceBand(tx + nx * 0.5, ty + ny * 0.5, nx * Cos(ang) + (-ny) * sinOut, ny * Cos(ang) + nx * sinOut,
          ABand, ADepth + 1, AInt * k, -1);
      end;
      Exit;
    end;
    { refraction / total internal reflection at a glass edge }
    nb := Length(e.Pts);
    nx := e.Pts[(hitEdge + 1) mod nb].y - e.Pts[hitEdge].y;
    ny := -(e.Pts[(hitEdge + 1) mod nb].x - e.Pts[hitEdge].x);
    len := Sqrt(nx * nx + ny * ny); nx := nx / len; ny := ny / len;
    { make the normal point outward (away from the centre) }
    if (tx - e.Center.x) * nx + (ty - e.Center.y) * ny < 0 then begin nx := -nx; ny := -ny; end;
    nBand := e.N + e.Disp * (FBandT[ABand] - 0.5);
    if DX * nx + DY * ny < 0 then
    begin
      n1 := 1; n2 := nBand;                                   { entering }
    end
    else
    begin
      n1 := nBand; n2 := 1;                                   { leaving: normal must face the ray }
      nx := -nx; ny := -ny;
    end;
    cosi := -(DX * nx + DY * ny);
    eta := n1 / n2;
    k := 1 - eta * eta * (1 - cosi * cosi);
    if k < 0 then
    begin
      DX := DX + 2 * cosi * nx; DY := DY + 2 * cosi * ny;    { total internal reflection }
      AInt := AInt * 0.92;
    end
    else
    begin
      { partial (Fresnel) reflection: the sparkle of cut glass }
      if (ADepth < 2) and (AInt > 0.2) and (FDef.Reflect > 0) then
        TraceBand(tx + (DX + 2 * cosi * nx) * 0.05, ty + (DY + 2 * cosi * ny) * 0.05,
          DX + 2 * cosi * nx, DY + 2 * cosi * ny, ABand, ADepth + 1, AInt * FDef.Reflect, inside);
      DX := eta * DX + (eta * cosi - Sqrt(k)) * nx;
      DY := eta * DY + (eta * cosi - Sqrt(k)) * ny;
      if n1 < n2 then inside := hitE else inside := -1;
      AInt := AInt * 0.96;
    end;
    len := Sqrt(DX * DX + DY * DY); DX := DX / len; DY := DY / len;
    OX := tx + DX * 0.05; OY := ty + DY * 0.05;
  end;
end;

procedure TLightScene.Shoot(X, Y, AAngle: Single; const D: TLightDef);
var
  b: Integer;
begin
  FDef := D;
  PrepareBands;
  SourceX := X; SourceY := Y;
  for b := 0 to FBands - 1 do
    TraceBand(X, Y, Cos(AAngle), Sin(AAngle), b, 0, 1, -1);
end;

procedure TLightScene.DrawLight(Layer: TLightLayer; K, AIntensity: Single);
var
  i, j: Integer;
  f, w: Single;
begin
  w := FDef.BeamWidth * Max(0.35, K);
  { all bands share the white part of the beam: draw such segments once }
  for i := 0 to SegCount - 1 do
  begin
    if Segs[i].R + Segs[i].G + Segs[i].B <= 0 then Continue;
    for j := i + 1 to SegCount - 1 do
      if (Abs(Segs[j].X0 - Segs[i].X0) < 0.3) and (Abs(Segs[j].Y0 - Segs[i].Y0) < 0.3) and
         (Abs(Segs[j].X1 - Segs[i].X1) < 0.3) and (Abs(Segs[j].Y1 - Segs[i].Y1) < 0.3) then
      begin
        Segs[i].R := Segs[i].R + Segs[j].R; Segs[i].G := Segs[i].G + Segs[j].G; Segs[i].B := Segs[i].B + Segs[j].B;
        Segs[j].R := 0; Segs[j].G := 0; Segs[j].B := 0;
      end;
  end;
  for i := 0 to SegCount - 1 do
  begin
    if Segs[i].R + Segs[i].G + Segs[i].B <= 0 then Continue;
    if Segs[i].Inside then f := AIntensity * FDef.Intensity * FDef.InnerGlow
    else f := AIntensity * FDef.Intensity;
    Layer.Line(Segs[i].X0 * K, Segs[i].Y0 * K, Segs[i].X1 * K, Segs[i].Y1 * K,
      Segs[i].R * f, Segs[i].G * f, Segs[i].B * f, w, FDef.Glow);
  end;
  { hot spot at the source }
  Layer.Dot(SourceX * K, SourceY * K, 4 * K, 0.5 * AIntensity, 0.5 * AIntensity, 0.55 * AIntensity);
end;

procedure TLightScene.DrawGlass(Bmp: TBGRABitmap; K, AAlpha: Single; ATime: Single);
var
  i, j, n: Integer;
  pts: array of TPointF;
  a: Integer;
  c: TBGRAPixel;
  x, y, t: Single;
begin
  a := Round(255 * EnsureRange(AAlpha * FDef.GlassAlpha, 0, 1));
  for i := 0 to High(Elems) do
  begin
    if Elems[i].IsGrating then
    begin
      Bmp.DrawLineAntialias(Elems[i].A.x * K, Elems[i].A.y * K, Elems[i].B.x * K, Elems[i].B.y * K,
        BGRA(200, 200, 220, a), Max(1, 1.5 * K));
      for j := 0 to 12 do
      begin
        t := j / 12;
        x := (Elems[i].A.x + (Elems[i].B.x - Elems[i].A.x) * t) * K;
        y := (Elems[i].A.y + (Elems[i].B.y - Elems[i].A.y) * t) * K;
        Bmp.FillEllipseAntialias(x, y, Max(0.8, 1.6 * K), Max(0.8, 1.6 * K), BGRA(230, 230, 255, a));
      end;
      Continue;
    end;
    n := Length(Elems[i].Pts);
    SetLength(pts, n);
    for j := 0 to n - 1 do pts[j] := PointF(Elems[i].Pts[j].x * K, Elems[i].Pts[j].y * K);
    Bmp.FillPolyAntialias(pts, BGRA(120, 130, 160, a div 5));
    for j := 0 to Length(Elems[i].Facets) div 2 - 1 do
      Bmp.DrawLineAntialias(Elems[i].Facets[j * 2].x * K, Elems[i].Facets[j * 2].y * K,
        Elems[i].Facets[j * 2 + 1].x * K, Elems[i].Facets[j * 2 + 1].y * K, BGRA(220, 225, 255, a div 3), Max(0.7, K));
    Bmp.DrawPolygonAntialias(pts, BGRA(235, 240, 255, a), Max(1, 1.4 * K));
    { iridescent edge highlight sliding around the glass }
    if FDef.EdgeGlow > 0 then
    begin
      j := Trunc(ATime * 0.8) mod n;
      t := Frac(ATime * 0.8);
      c := BGRA(255, 255, 255, Round(Min(255, 200 * FDef.EdgeGlow)));
      Bmp.DrawLineAntialias(pts[j].x, pts[j].y,
        pts[j].x + (pts[(j + 1) mod n].x - pts[j].x) * t, pts[j].y + (pts[(j + 1) mod n].y - pts[j].y) * t,
        c, Max(1.2, 2.2 * K));
    end;
  end;
end;

function TLightScene.ProbeExit(OX, OY, DX, DY, AN: Single; out PX, PY, EX, EY: Single): Boolean;
var
  bounce, i, j, nb, hitE, hitEdge: Integer;
  bestT, t, u, tx, ty, nx, ny, len, n1, n2, cosi, eta, k: Single;
  entered: Boolean;
begin
  Result := False;
  PX := OX; PY := OY; EX := DX; EY := DY;
  entered := False;
  for bounce := 0 to 10 do
  begin
    bestT := 1e9; hitE := -1; hitEdge := -1;
    for i := 0 to High(Elems) do
    begin
      if Elems[i].IsGrating then Continue;
      nb := Length(Elems[i].Pts);
      for j := 0 to nb - 1 do
        if RaySeg(OX, OY, DX, DY, Elems[i].Pts[j], Elems[i].Pts[(j + 1) mod nb], t, u) and (t < bestT) then
        begin
          bestT := t; hitE := i; hitEdge := j;
        end;
    end;
    if hitE < 0 then Exit;                     { missed the glass, or lost inside }
    tx := OX + DX * bestT; ty := OY + DY * bestT;
    nb := Length(Elems[hitE].Pts);
    nx := Elems[hitE].Pts[(hitEdge + 1) mod nb].y - Elems[hitE].Pts[hitEdge].y;
    ny := -(Elems[hitE].Pts[(hitEdge + 1) mod nb].x - Elems[hitE].Pts[hitEdge].x);
    len := Sqrt(nx * nx + ny * ny); nx := nx / len; ny := ny / len;
    if (tx - Elems[hitE].Center.x) * nx + (ty - Elems[hitE].Center.y) * ny < 0 then begin nx := -nx; ny := -ny; end;
    if DX * nx + DY * ny < 0 then begin n1 := 1; n2 := AN; end
    else begin n1 := AN; n2 := 1; nx := -nx; ny := -ny; end;
    cosi := -(DX * nx + DY * ny);
    eta := n1 / n2;
    k := 1 - eta * eta * (1 - cosi * cosi);
    if k < 0 then
    begin
      DX := DX + 2 * cosi * nx; DY := DY + 2 * cosi * ny;
    end
    else
    begin
      DX := eta * DX + (eta * cosi - Sqrt(k)) * nx;
      DY := eta * DY + (eta * cosi - Sqrt(k)) * ny;
      if n1 < n2 then entered := True
      else if entered then
      begin
        len := Sqrt(DX * DX + DY * DY);
        PX := tx; PY := ty; EX := DX / len; EY := DY / len;
        Exit(True);
      end;
    end;
    len := Sqrt(DX * DX + DY * DY); DX := DX / len; DY := DY / len;
    OX := tx + DX * 0.05; OY := ty + DY * 0.05;
  end;
end;

function TLightScene.HitsCircle(CX, CY, R: Single): Boolean;
var
  i: Integer;
  dx, dy, l2, t, px, py: Single;
begin
  Result := False;
  for i := 0 to SegCount - 1 do
  begin
    if Segs[i].Inside then Continue;
    if Segs[i].R + Segs[i].G + Segs[i].B < 0.01 then Continue;
    dx := Segs[i].X1 - Segs[i].X0; dy := Segs[i].Y1 - Segs[i].Y0;
    l2 := dx * dx + dy * dy;
    if l2 < 1e-6 then Continue;
    t := EnsureRange(((CX - Segs[i].X0) * dx + (CY - Segs[i].Y0) * dy) / l2, 0, 1);
    px := Segs[i].X0 + dx * t; py := Segs[i].Y0 + dy * t;
    if Sqr(px - CX) + Sqr(py - CY) < R * R then Exit(True);
  end;
end;

{ ---------------- presets ---------------- }

procedure LayoutKind(Scene: TLightScene; AKind: Integer; const D: TLightDef; CX, CY, S, ATime: Single;
  out SX, SY, Ang: Single);
var
  sw: Single;
begin
  Scene.Clear;
  sw := DegToRad(D.Tilt + D.Swing * Sin(ATime * D.SwingSpeed));
  S := S * D.Size / 120;
  case AKind of
    LK_NEWTON:
      begin
        Scene.AddPrism(CX - S * 0.75, CY + S * 0.05, S * 0.9, sw, D.Index, D.Dispersion);
        Scene.AddPrism(CX + S * 0.45, CY + S * 0.72, S * 0.9, Pi + sw * 0.5, D.Index, D.Dispersion);
        SX := CX - S * 2.6; SY := CY + S * 0.25;
        Ang := ArcTan2(CY + S * 0.1 - SY, CX - S * 0.75 - SX);
      end;
    LK_GRATING:
      begin
        Scene.AddGrating(CX - S * 0.4, CY, S * 1.1, sw * 0.5, D.Pitch, D.Orders);
        SX := CX - S * 2.4; SY := CY;
        Ang := 0;
      end;
    LK_DIAMOND:
      begin
        Scene.AddDiamond(CX, CY, S * 0.9, sw, D.Index, D.Dispersion);
        SX := CX - S * 2.2; SY := CY - S * 1.1;
        Ang := ArcTan2(CY - S * 0.28 - SY, CX - S * 0.15 - SX);
      end;
  else
    begin
      Scene.AddPrism(CX, CY, S, sw, D.Index, D.Dispersion);
      SX := CX - S * 2.4; SY := CY + S * 0.35;
      Ang := ArcTan2(CY + S * 0.05 - SY, CX - S * 0.2 - SX);
    end;
  end;
end;

procedure BuildKindScene(Scene: TLightScene; AKind: Integer; const D: TLightDef; CX, CY, S, ATime: Single);
var
  sx, sy, ang: Single;
begin
  LayoutKind(Scene, AKind, D, CX, CY, S, ATime, sx, sy, ang);
  Scene.Shoot(sx, sy, ang, D);
end;

procedure BuildBeamScene(Scene: TLightScene; AKind: Integer; const D: TLightDef; SX, SY, ATime: Single);
const
  ROT = -Pi / 2;          { the classic left-to-right setup, turned to shoot upwards }
var
  lx, ly, ang, dx, dy: Single;
  i, j: Integer;
  bd: TLightDef;

  function T(const P: TPointF): TPointF;
  begin
    Result := PointF(P.x * Cos(ROT) - P.y * Sin(ROT) + dx, P.x * Sin(ROT) + P.y * Cos(ROT) + dy);
  end;

begin
  bd := D;
  bd.Reflect := Min(bd.Reflect, 0.05);            { keep the play field readable }
  LayoutKind(Scene, AKind, bd, 0, 0, 62, ATime * 1.6, lx, ly, ang);
  { place the light source on the ship }
  dx := SX - (lx * Cos(ROT) - ly * Sin(ROT));
  dy := SY - 22 - (lx * Sin(ROT) + ly * Cos(ROT));
  for i := 0 to High(Scene.Elems) do
  begin
    for j := 0 to High(Scene.Elems[i].Pts) do Scene.Elems[i].Pts[j] := T(Scene.Elems[i].Pts[j]);
    for j := 0 to High(Scene.Elems[i].Facets) do Scene.Elems[i].Facets[j] := T(Scene.Elems[i].Facets[j]);
    Scene.Elems[i].Center := T(Scene.Elems[i].Center);
    Scene.Elems[i].A := T(Scene.Elems[i].A);
    Scene.Elems[i].B := T(Scene.Elems[i].B);
  end;
  Scene.Shoot(SX, SY - 22, ang + ROT, bd);
end;

end.

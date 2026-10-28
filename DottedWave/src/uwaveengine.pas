{ Dotted Wave Mesh - CPU renderer (BGRABitmap), multi-threaded

  Pipeline per frame:
    1. Height field: fBm simplex noise sampled on the (line x dot) grid   [parallel by grid row]
       + wells (gaussian bumps/pits) + expanding rings + mouse ripple
    2. Displace each dot vertically by height * amplitude (+ horizontal warp)
    3. Normal from grid finite differences -> Lambert + Blinn-Phong        [parallel by grid row]
       intensity (+ iridescent color)
    4. Additive box-filtered splat of each square dot into float buffers   [serial, cheap]
    5. Colorize buffers + vignette into the bitmap                         [parallel by pixel row]

  Threads: persistent worker pool (one per extra CPU core), created on the
  first render and woken with RTL events, so there is no per-frame thread
  creation cost. Set Threads := 1 before the first Render to stay single-threaded. }
unit uWaveEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, BGRABitmap, BGRABitmapTypes, uWaveTypes, uSimplexNoise, uPlatform;

type
  TWaveRipple = record
    X, Y: Single;      { normalized 0..1 in canvas space }
    Energy: Single;    { 0..1, decays over time }
  end;

  { Local gaussian deformation of the surface (all units: reference px).
    Height: added to the normalized height field (x amplitude on screen)
    Darken: >0 absorbs light near the center, <0 makes dots brighter }
  TWaveWell = record
    X, Y, Radius, Height, Darken: Single;
  end;

  { Expanding ring wave: the caller ages it and passes current R / Strength }
  TWaveRing = record
    X, Y, R, Width, Strength: Single;
  end;

  TRangeProc = procedure(AFrom, ATo: Integer) of object;

  TWaveEngine = class;

  { TWavePoolWorker }

  TWavePoolWorker = class(TThread)
  private
    FGo, FDone: PRTLEvent;
    FProc: TRangeProc;
    FFrom, FTo: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  { per-frame constants shared by the parallel passes }
  TWaveFrame = record
    W, H, lines, rows, cols, marginRows, oct: Integer;
    sc, amp, ns, lineSp, dotSp, marginRef, widthRef, tilt, sx, warp, lac, gain: Single;
    ox, oy, nz, driftX, driftY, scrollY, realTime: Single;
    ripE, rx, ry, rr: Single;
    Lx, Ly, Lz, Hx, Hy, Hz, relief, ambient, kd, ks, sp, expo, gam, dotS: Single;
    iriAmt, iriFreq, iriH, iriSpread, iriPh, iriSpecW: Single;
    dotR, dotG, dotB: Single;
    bg: TBGRAPixel;
    bgR, bgG, bgB, dR, dG, dB, vig: Single;
  end;

  { TWaveEngine }

  TWaveEngine = class
  private
    FAcc: array of Single;          { coverage * intensity }
    FRGB: array of Single;          { per-channel color accumulation (iridescent mode) }
    FLut: array[0..255, 0..2] of Single;
    FUseRGB: Boolean;
    FAccW, FAccH: Integer;
    FHeight, FPosX, FPosY, FShade, FInten: array of Single;
    FColR, FColG, FColB: array of Single;
    FFieldWidth: Single;
    FSeed: Integer;
    FF: TWaveFrame;
    FBmp: TBGRABitmap;
    FLines: array of PBGRAPixel;    { scanline pointers, fetched once on the main thread }
    FImgLines: array of PBGRAPixel;
    FImgOn: Boolean;
    FDotMul: array of Single;
    FPool: array of TWavePoolWorker;
    FPoolReady: Boolean;
    procedure Splat(x, y, s, v, cr, cg, cb: Single);
    procedure BuildIriLut(APalette: Integer; ASat: Single);
    procedure EnsurePool;
    procedure RunParallel(ACount: Integer; AProc: TRangeProc);
    procedure HeightRows(AFrom, ATo: Integer);
    procedure LightRows(AFrom, ATo: Integer);
    procedure ColorRows(AFrom, ATo: Integer);
  public
    Ripple: TWaveRipple;
    DotCount: Integer;
    RenderMs: Double;
    Threads: Integer;               { worker count incl. caller; default = CPU cores (max 16) }
    { game / interaction hooks (empty = plain wallpaper rendering) }
    Wells: array of TWaveWell;
    Rings: array of TWaveRing;
    ScrollY: Single;                { reference px; increasing value flows the surface downward }
    { image drawn BY the dots (anime levels): every dot takes brightness and colour
      from the image at its wave-displaced position. Not owned. ImageX/Y/W/H in reference px. }
    Image: TBGRABitmap;
    ImageX, ImageY, ImageW, ImageH, ImageMix: Single;
    ImageDotSize: Single;           { dot size multiplier inside the image (default 1.7) }
    ImageBgDim: Single;             { dims the mesh outside the image so the picture reads (0.45) }
    property FieldWidth: Single read FFieldWidth;   { canvas width in reference px (last render) }
    constructor Create;
    destructor Destroy; override;
    { Phase: animation time (already multiplied by speed)
      RealTime: wall-clock seconds, drives ripple animation }
    procedure Render(Bmp: TBGRABitmap; const Cfg: TWaveConfig; Phase, RealTime: Double);
  end;

{ Iridescent cosine palette sample (same palettes as the renderer).
  APalette 0 Rainbow, 1 Pearl, 2 Oil slick, 3 Holographic, 4 Beetle, 5 Mono pearl-white.
  T wraps every 1.0. Brightest channel normalized to 255. }
function IriPaletteColor(APalette: Integer; T, ASat: Single): TBGRAPixel;

implementation

const
  { Cosine palettes  col = 0.5 + 0.5 * cos(2pi * (c*t + d))  (after I. Quilez) }
  IriC: array[0..4, 0..2] of Single = (
    (1, 1, 1), (1, 1, 1), (2, 1, 0), (1, 0.7, 0.4), (1, 1, 0.5));
  IriD: array[0..4, 0..2] of Single = (
    (0, 0.33, 0.67), (0, 0.10, 0.20), (0.5, 0.20, 0.25), (0, 0.15, 0.20), (0.8, 0.90, 0.30));

function IriPaletteColor(APalette: Integer; T, ASat: Single): TBGRAPixel;
var
  ch: Integer;
  col: array[0..2] of Single;
  lum, m: Single;
begin
  if APalette >= 5 then
  begin
    { mono pearl: near-white with a faint cool / warm drift }
    lum := 0.5 + 0.5 * Cos(2 * Pi * T);
    Result := BGRA(Round(225 + 30 * lum), Round(228 + 22 * (1 - lum)), 255, 255);
    Exit;
  end;
  APalette := EnsureRange(APalette, 0, High(IriC));
  for ch := 0 to 2 do
    col[ch] := 0.5 + 0.5 * Cos(2 * Pi * (IriC[APalette, ch] * T + IriD[APalette, ch]));
  lum := 0.299 * col[0] + 0.587 * col[1] + 0.114 * col[2];
  m := 0.05;
  for ch := 0 to 2 do
  begin
    col[ch] := EnsureRange(lum + (col[ch] - lum) * ASat, 0, 1);
    if col[ch] > m then m := col[ch];
  end;
  Result := BGRA(Round(col[0] / m * 255), Round(col[1] / m * 255), Round(col[2] / m * 255), 255);
end;

{ TWavePoolWorker }

constructor TWavePoolWorker.Create;
begin
  FGo := RTLEventCreate;
  FDone := RTLEventCreate;
  inherited Create(False);
end;

destructor TWavePoolWorker.Destroy;
begin
  RTLEventDestroy(FGo);
  RTLEventDestroy(FDone);
  inherited Destroy;
end;

procedure TWavePoolWorker.Execute;
begin
  while True do
  begin
    RTLEventWaitFor(FGo);
    if Terminated then Break;
    try
      if Assigned(FProc) then FProc(FFrom, FTo);
    except
      { never let a worker die: the caller would wait forever }
    end;
    RTLEventSetEvent(FDone);
  end;
end;

{ TWaveEngine }

constructor TWaveEngine.Create;
begin
  inherited Create;
  ImageDotSize := 1.7;
  ImageBgDim := 0.45;
  FSeed := -1;
  Threads := EnsureRange(TThread.ProcessorCount, 1, 16);
end;

destructor TWaveEngine.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FPool) do
  begin
    FPool[i].Terminate;
    RTLEventSetEvent(FPool[i].FGo);
    FPool[i].WaitFor;
    FPool[i].Free;
  end;
  inherited Destroy;
end;

procedure TWaveEngine.EnsurePool;
var
  i: Integer;
begin
  if FPoolReady then Exit;
  FPoolReady := True;
  SetLength(FPool, Max(0, Threads - 1));
  for i := 0 to High(FPool) do
    FPool[i] := TWavePoolWorker.Create;
end;

procedure TWaveEngine.RunParallel(ACount: Integer; AProc: TRangeProc);
var
  n, i: Integer;
begin
  EnsurePool;
  n := Min(Length(FPool) + 1, Max(1, ACount div 8));
  if n <= 1 then
  begin
    AProc(0, ACount);
    Exit;
  end;
  for i := 0 to n - 2 do
  begin
    FPool[i].FProc := AProc;
    FPool[i].FFrom := ACount * i div n;
    FPool[i].FTo := ACount * (i + 1) div n;
    RTLEventSetEvent(FPool[i].FGo);
  end;
  AProc(ACount * (n - 1) div n, ACount);
  for i := 0 to n - 2 do
    RTLEventWaitFor(FPool[i].FDone);
end;

procedure TWaveEngine.BuildIriLut(APalette: Integer; ASat: Single);
var
  k, ch: Integer;
  t, lum, m: Single;
  col: array[0..2] of Single;
begin
  APalette := EnsureRange(APalette, 0, High(IriC));
  for k := 0 to 255 do
  begin
    t := k / 256;
    for ch := 0 to 2 do
      col[ch] := 0.5 + 0.5 * Cos(2 * Pi * (IriC[APalette, ch] * t + IriD[APalette, ch]));
    lum := 0.299 * col[0] + 0.587 * col[1] + 0.114 * col[2];
    m := 0;
    for ch := 0 to 2 do
    begin
      col[ch] := EnsureRange(lum + (col[ch] - lum) * ASat, 0, 1);
      if col[ch] > m then m := col[ch];
    end;
    { normalize so the brightest channel is 1: dots keep full luminosity }
    if m < 0.05 then m := 0.05;
    for ch := 0 to 2 do
      FLut[k, ch] := col[ch] / m * 255;
  end;
end;

procedure TWaveEngine.Splat(x, y, s, v, cr, cg, cb: Single);
var
  x0, x1, y0, y1, cx, cy, wgt: Single;
  ix0, ix1, iy0, iy1, px, py, row, k: Integer;
begin
  x0 := x - s * 0.5; x1 := x0 + s;
  y0 := y - s * 0.5; y1 := y0 + s;
  ix0 := Floor(x0); ix1 := Ceil(x1) - 1;
  iy0 := Floor(y0); iy1 := Ceil(y1) - 1;
  if (ix1 < 0) or (iy1 < 0) or (ix0 >= FAccW) or (iy0 >= FAccH) then Exit;
  if ix0 < 0 then ix0 := 0;
  if iy0 < 0 then iy0 := 0;
  if ix1 >= FAccW then ix1 := FAccW - 1;
  if iy1 >= FAccH then iy1 := FAccH - 1;
  for py := iy0 to iy1 do
  begin
    cy := Min(y1, py + 1) - Max(y0, py);
    if cy <= 0 then Continue;
    cy := cy * v;
    row := py * FAccW;
    for px := ix0 to ix1 do
    begin
      cx := Min(x1, px + 1) - Max(x0, px);
      if cx > 0 then
      begin
        wgt := cx * cy;
        FAcc[row + px] := FAcc[row + px] + wgt;
        if FUseRGB then
        begin
          k := (row + px) * 3;
          FRGB[k] := FRGB[k] + wgt * cr;
          FRGB[k + 1] := FRGB[k + 1] + wgt * cg;
          FRGB[k + 2] := FRGB[k + 2] + wgt * cb;
        end;
      end;
    end;
  end;
end;

{ --- pass 1+2: height field and displaced positions (grid rows) --- }
procedure TWaveEngine.HeightRows(AFrom, ATo: Integer);
var
  r, c, o, idx, wi: Integer;
  vv, fv, depthK, baseX, baseY, nx, ny, hsum, a, f, norm, d, shade, wdx, wdy, wd2, wg: Single;
begin
  for r := AFrom to ATo - 1 do
  begin
    vv := (r - FF.marginRows) / FF.lines;
    fv := vv * (1 - FF.tilt) + FF.tilt * vv * vv;          { perspective spacing }
    depthK := Max(0.2, 1 - FF.tilt + 2 * FF.tilt * vv);   { nearer rows = larger }
    baseY := fv * REF_HEIGHT;
    idx := r * FF.cols;
    for c := 0 to FF.cols - 1 do
    begin
      baseX := -FF.marginRef + c * FF.dotSp;
      nx := baseX * FF.ns * FF.sx + FF.ox + FF.driftX;
      ny := (baseY - FF.scrollY) * FF.ns + FF.oy + FF.driftY;
      hsum := 0; a := 1; f := 1; norm := 0;
      for o := 0 to FF.oct - 1 do
      begin
        hsum := hsum + a * Simplex3(nx * f, ny * f, FF.nz * (1 + o * 0.35) + o * 7.13);
        norm := norm + a;
        a := a * FF.gain;
        f := f * FF.lac;
      end;
      hsum := hsum / norm;

      if FF.ripE > 0.001 then
      begin
        d := Sqrt(Sqr(baseX - FF.rx) + Sqr(baseY - FF.ry)) / FF.rr;
        if d < 3 then
          hsum := hsum + FF.ripE * Exp(-d * d) * Cos(d * 6 - FF.realTime * 7);
      end;

      shade := 1;
      for wi := 0 to High(Wells) do
      begin
        wdx := baseX - Wells[wi].X;
        wdy := baseY - Wells[wi].Y;
        wd2 := wdx * wdx + wdy * wdy;
        if wd2 < 9 * Wells[wi].Radius * Wells[wi].Radius then
        begin
          wg := Exp(-wd2 / (Wells[wi].Radius * Wells[wi].Radius));
          hsum := hsum + Wells[wi].Height * wg;
          shade := shade * (1 - Wells[wi].Darken * wg);
        end;
      end;
      for wi := 0 to High(Rings) do
      begin
        wdx := baseX - Rings[wi].X;
        wdy := baseY - Rings[wi].Y;
        wd2 := Sqrt(wdx * wdx + wdy * wdy) - Rings[wi].R;
        if Abs(wd2) < 3 * Rings[wi].Width then
          hsum := hsum + Rings[wi].Strength * Exp(-Sqr(wd2 / Rings[wi].Width));
      end;
      if shade < 0 then shade := 0;

      FShade[idx] := shade;
      FHeight[idx] := hsum;
      if FF.warp > 0 then
        FPosX[idx] := baseX + FF.warp * Simplex3(nx * 0.6 + 31.7, ny * 0.6 - 11.3, FF.nz * 0.5)
      else
        FPosX[idx] := baseX;
      FPosY[idx] := baseY + hsum * FF.amp * depthK;
      Inc(idx);
    end;
  end;
end;

{ --- pass 3: lighting / color per dot (grid rows) --- }
procedure TWaveEngine.LightRows(AFrom, ATo: Integer);
var
  r, c, idx, cL, cR, rU, rD, li, ix, iy: Integer;
  x, y, hx, hy, nlen, qx, qy, qz, diff, spec, raw, inten, t, ws, colR, colG, colB, ia, lum, mx: Single;
  ip: PBGRAPixel;
begin
  for r := AFrom to ATo - 1 do
  begin
    rU := Max(0, r - 1); rD := Min(FF.rows - 1, r + 1);
    for c := 0 to FF.cols - 1 do
    begin
      idx := r * FF.cols + c;
      FInten[idx] := 0;
      x := FPosX[idx] * FF.sc;
      y := FPosY[idx] * FF.sc;
      if (x < -4) or (x > FF.W + 4) or (y < -4) or (y > FF.H + 4) then Continue;
      cL := Max(0, c - 1); cR := Min(FF.cols - 1, c + 1);
      hx := (FHeight[r * FF.cols + cR] - FHeight[r * FF.cols + cL]) / ((cR - cL) * FF.dotSp) * FF.amp * FF.relief;
      hy := (FHeight[rD * FF.cols + c] - FHeight[rU * FF.cols + c]) / ((rD - rU) * FF.lineSp) * FF.amp * FF.relief;
      nlen := Sqrt(hx * hx + hy * hy + 1);
      qx := -hx / nlen; qy := -hy / nlen; qz := 1 / nlen;
      diff := qx * FF.Lx + qy * FF.Ly + qz * FF.Lz;
      if diff < 0 then diff := 0;
      spec := qx * FF.Hx + qy * FF.Hy + qz * FF.Hz;
      if (spec > 0) and (FF.ks > 0) then spec := Power(spec, FF.sp) else spec := 0;
      raw := FF.ambient + FF.kd * diff + FF.ks * spec;
      inten := FF.expo * raw;
      if inten > 0 then inten := Power(inten, FF.gam) * FShade[idx] else inten := 0;
      if FImgOn then
      begin
        { sample the image at the displaced dot position }
        ix := Trunc((FPosX[idx] - ImageX) / ImageW * Image.Width);
        iy := Trunc((FPosY[idx] - ImageY) / ImageH * Image.Height);
        if (ix >= 0) and (iy >= 0) and (ix < Image.Width) and (iy < Image.Height) then
        begin
          ip := FImgLines[iy] + ix;
          ia := ip^.alpha / 255 * ImageMix;
          if ia > 0.02 then
          begin
            lum := (0.3 * ip^.red + 0.59 * ip^.green + 0.11 * ip^.blue) / 255;
            mx := Max(24, Max(ip^.red, Max(ip^.green, ip^.blue)));
            { line art stays dark, fills glow; the wave light still shades it a little }
            inten := inten * (1 - ia) + ia * (0.06 + 2.1 * lum) * (0.85 + 0.3 * diff);
            if inten < 0.004 then Continue;
            FInten[idx] := inten;
            FDotMul[idx] := 1 + (ImageDotSize - 1) * ia;
            FColR[idx] := (ip^.red / mx * 255 * ia + FF.dotR * (1 - ia)) * inten;
            FColG[idx] := (ip^.green / mx * 255 * ia + FF.dotG * (1 - ia)) * inten;
            FColB[idx] := (ip^.blue / mx * 255 * ia + FF.dotB * (1 - ia)) * inten;
            Continue;
          end;
        end;
      end;
      if FImgOn then inten := inten * (1 - ImageBgDim);
      if inten < 0.004 then Continue;
      FInten[idx] := inten;
      FDotMul[idx] := 1;
      if FUseRGB and (FF.iriAmt > 0.001) then
      begin
        { thin-film style hue: surface angle + wave height + screen position + time }
        t := FF.iriFreq * Sqrt(qx * qx + qy * qy) + FF.iriH * FHeight[idx]
           + FF.iriSpread * (FPosX[idx] / FF.widthRef * 0.6 + FPosY[idx] / REF_HEIGHT) + FF.iriPh;
        li := Trunc((t - Floor(t)) * 256) and 255;
        colR := FF.dotR + (FLut[li, 0] - FF.dotR) * FF.iriAmt;
        colG := FF.dotG + (FLut[li, 1] - FF.dotG) * FF.iriAmt;
        colB := FF.dotB + (FLut[li, 2] - FF.dotB) * FF.iriAmt;
        { specular highlight drifts toward white }
        ws := FF.iriSpecW * FF.ks * spec / raw;
        FColR[idx] := (colR + (255 - colR) * ws) * inten;
        FColG[idx] := (colG + (255 - colG) * ws) * inten;
        FColB[idx] := (colB + (255 - colB) * ws) * inten;
      end
      else if FUseRGB then
      begin
        FColR[idx] := FF.dotR * inten;
        FColG[idx] := FF.dotG * inten;
        FColB[idx] := FF.dotB * inten;
      end;
    end;
  end;
end;

{ --- pass 5: colorize (pixel rows) --- }
procedure TWaveEngine.ColorRows(AFrom, ATo: Integer);
var
  x, y, i: Integer;
  a, fx, fy, vy, vk, sInv: Single;
  p: PBGRAPixel;
begin
  for y := AFrom to ATo - 1 do
  begin
    p := FLines[y];
    fy := (y / FF.H - 0.5) * 2;
    vy := fy * fy;
    i := y * FF.W;
    for x := 0 to FF.W - 1 do
    begin
      a := FAcc[i];
      if a <= 0.002 then
        p^ := FF.bg
      else
      begin
        vk := 1;
        if FF.vig > 0 then
        begin
          fx := (x / FF.W - 0.5) * 2;
          vk := Max(0, 1 - FF.vig * 0.5 * (fx * fx + vy));
        end;
        if FUseRGB then
        begin
          { bg * (1 - coverage) + accumulated rgb, normalized where dots overlap }
          sInv := vk / Max(1, a);
          a := Min(1, a) * vk;
          p^.red   := Min(255, Round(FF.bgR * (1 - a) + FRGB[i * 3] * sInv));
          p^.green := Min(255, Round(FF.bgG * (1 - a) + FRGB[i * 3 + 1] * sInv));
          p^.blue  := Min(255, Round(FF.bgB * (1 - a) + FRGB[i * 3 + 2] * sInv));
        end
        else
        begin
          a := Min(1, a * vk);
          p^.red := Round(FF.bgR + FF.dR * a);
          p^.green := Round(FF.bgG + FF.dG * a);
          p^.blue := Round(FF.bgB + FF.dB * a);
        end;
        p^.alpha := 255;
      end;
      Inc(p);
      Inc(i);
    end;
  end;
end;

procedure TWaveEngine.Render(Bmp: TBGRABitmap; const Cfg: TWaveConfig; Phase, RealTime: Double);
var
  V: array[TWaveParam] of Single;
  idx, n: Integer;
  az, el, nlen: Single;
  t0: Double;
begin
  t0 := NowSeconds;
  if (Bmp.Width < 2) or (Bmp.Height < 2) then Exit;
  V := Cfg.Values;
  FBmp := Bmp;
  FF.W := Bmp.Width;
  FF.H := Bmp.Height;

  if Round(V[wpSeed]) <> FSeed then
  begin
    FSeed := Round(V[wpSeed]);
    NoiseSeed(LongWord(FSeed));
  end;

  { --- buffers --- }
  if (FAccW <> FF.W) or (FAccH <> FF.H) then
  begin
    FAccW := FF.W; FAccH := FF.H;
    SetLength(FAcc, FF.W * FF.H);
  end;
  FillChar(FAcc[0], FF.W * FF.H * SizeOf(Single), 0);
  FF.iriAmt := V[wpIriAmount];
  FImgOn := (Image <> nil) and (Image.Width > 1) and (ImageW > 1) and (ImageH > 1) and (ImageMix > 0.01);
  if FImgOn then
  begin
    SetLength(FImgLines, Image.Height);
    for idx := 0 to Image.Height - 1 do FImgLines[idx] := Image.ScanLine[idx];
  end;
  FUseRGB := (FF.iriAmt > 0.001) or FImgOn;
  if FUseRGB then
  begin
    if Length(FRGB) <> FF.W * FF.H * 3 then SetLength(FRGB, FF.W * FF.H * 3);
    FillChar(FRGB[0], FF.W * FF.H * 3 * SizeOf(Single), 0);
    BuildIriLut(Round(V[wpIriPalette]), V[wpIriSaturation]);
  end;

  { --- frame constants --- }
  FF.sc := FF.H / REF_HEIGHT;                   { device px per reference px }
  FF.lines := Max(4, Round(V[wpLines]));
  FF.amp := V[wpAmplitude];
  FF.ns := V[wpNoiseScale];
  FF.lineSp := REF_HEIGHT / FF.lines;
  FF.dotSp := Max(0.5, V[wpDotSpacing]);
  FF.tilt := V[wpTilt];
  FF.sx := V[wpStretchX];
  FF.warp := V[wpWarp];
  FF.oct := EnsureRange(Round(V[wpOctaves]), 1, 8);
  FF.lac := V[wpLacunarity];
  FF.gain := V[wpGain];
  FF.widthRef := FF.W / FF.sc;
  FF.marginRef := FF.amp * 0.25 + FF.warp + FF.dotSp * 2;
  FF.marginRows := Ceil(FF.amp * 1.2 / FF.lineSp) + 2;
  FF.rows := FF.lines + 1 + 2 * FF.marginRows;
  FF.cols := Ceil((FF.widthRef + 2 * FF.marginRef) / FF.dotSp) + 1;
  DotCount := FF.rows * FF.cols;
  FFieldWidth := FF.widthRef;
  if Length(FHeight) < DotCount then
  begin
    SetLength(FHeight, DotCount);
    SetLength(FPosX, DotCount);
    SetLength(FPosY, DotCount);
    SetLength(FShade, DotCount);
    SetLength(FInten, DotCount);
    SetLength(FColR, DotCount);
    SetLength(FColG, DotCount);
    SetLength(FColB, DotCount);
    SetLength(FDotMul, DotCount);
  end;

  FF.ox := FSeed * 17.31;
  FF.oy := FSeed * 9.73;
  FF.nz := Phase;
  FF.driftX := Phase * V[wpDriftX];
  FF.driftY := Phase * V[wpDriftY];
  FF.scrollY := ScrollY;
  FF.realTime := RealTime;
  FF.ripE := Ripple.Energy * V[wpRippleStrength];
  FF.rx := Ripple.X * FF.widthRef;
  FF.ry := Ripple.Y * REF_HEIGHT;
  FF.rr := Max(1, V[wpRippleRadius]);

  az := DegToRad(V[wpLightAzimuth]);
  el := DegToRad(V[wpLightElevation]);
  FF.Lx := Cos(el) * Cos(az); FF.Ly := Cos(el) * Sin(az); FF.Lz := Sin(el);
  { Blinn half vector, viewer at (0,0,1) }
  FF.Hx := FF.Lx; FF.Hy := FF.Ly; FF.Hz := FF.Lz + 1;
  nlen := Sqrt(FF.Hx * FF.Hx + FF.Hy * FF.Hy + FF.Hz * FF.Hz);
  FF.Hx := FF.Hx / nlen; FF.Hy := FF.Hy / nlen; FF.Hz := FF.Hz / nlen;
  FF.relief := V[wpRelief];
  FF.ambient := V[wpAmbient];
  FF.kd := V[wpDiffuse];
  FF.ks := V[wpSpecular];
  FF.sp := V[wpSpecPower];
  FF.expo := V[wpExposure];
  FF.gam := V[wpContrast];
  FF.dotS := Max(0.35, V[wpDotSize] * FF.sc);
  FF.iriFreq := V[wpIriFrequency];
  FF.iriH := V[wpIriHeight];
  FF.iriSpread := V[wpIriSpread];
  FF.iriPh := V[wpIriSpeed] * Phase + V[wpIriOffset];
  FF.iriSpecW := V[wpIriSpecWhite];
  FF.dotR := Cfg.DotColor.red;
  FF.dotG := Cfg.DotColor.green;
  FF.dotB := Cfg.DotColor.blue;
  FF.bg := Cfg.BgColor;
  FF.bgR := FF.bg.red; FF.bgG := FF.bg.green; FF.bgB := FF.bg.blue;
  FF.dR := FF.dotR - FF.bgR; FF.dG := FF.dotG - FF.bgG; FF.dB := FF.dotB - FF.bgB;
  FF.vig := V[wpVignette];

  { --- passes --- }
  RunParallel(FF.rows, @HeightRows);
  RunParallel(FF.rows, @LightRows);
  n := DotCount;
  for idx := 0 to n - 1 do
    if FInten[idx] > 0 then
      Splat(FPosX[idx] * FF.sc, FPosY[idx] * FF.sc, FF.dotS * FDotMul[idx], FInten[idx],
        FColR[idx], FColG[idx], FColB[idx]);
  SetLength(FLines, FF.H);
  for idx := 0 to FF.H - 1 do
    FLines[idx] := Bmp.ScanLine[idx];
  RunParallel(FF.H, @ColorRows);

  Bmp.InvalidateBitmap;
  RenderMs := (NowSeconds - t0) * 1000;
end;

end.

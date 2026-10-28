{ WaveRider anime layer (v3: chibi)

  Original chibi characters, drawn procedurally (no external artwork):
    Mimi  purple cat girl, star hair clip, spiral blush, ring eyes, :3 mouth
    Kuma  girl in a bear hood, waving a bear paw, ^ ^ eyes, big laugh
    Neko  black-haired cat girl, bow, sparkly eyes, little fang
    Ao    long blue hair with an ahoge, wink + peace sign
    Party all four take turns
  TAnimeDirector plays short chibi moments that come and go:
    Peek  pops up from a bottom corner (bounce + squash), waves, ducks down
    Hop   bounces across the screen, squashing on every landing
    Pop   a pink star frame springs open, wink + peace, vanishes in sparkles
    Side  a big face peeks in from the screen edge, blinks, slides back
  Characters are drawn on worker threads (double buffered).
  Your own art: data/anime/<file.png> or a folder of PNG frames. }
unit uAnime;

{$mode objfpc}{$H+}
{$Q-}{$R-}

interface

uses
  Classes, SysUtils, Math, BGRABitmap, BGRABitmapTypes, BGRAGraphics;

const
  ANIME_NAMES = 'None|Mimi|Kuma|Neko|Ao|Party|Image';
  AN_NONE = 0; AN_MIMI = 1; AN_KUMA = 2; AN_NEKO = 3; AN_AO = 4; AN_PARTY = 5; AN_IMAGE = 6;

type
  TChibiExpr = (exHappy, exCat, exWink, exSparkle, exXD, exSmile);
  TChibiHand = (chNone, chWave, chPeace, chPaw);

  TChibiPose = record
    Expr: TChibiExpr;
    Blink: Single;      { 1 open .. 0 closed (for open-eye expressions) }
    Hand: TChibiHand;
    HandUp: Single;     { 0 down .. 1 raised }
    Frame: Boolean;     { pink star frame behind (Pop) }
  end;

  TShotKind = (skPeek, skHop, skPop, skSide);

  TCharLayer = record
    Bmp: TBGRABitmap;
    Visible: Boolean;
    CX, CY, W, H, Rot, Alpha: Single;
    VX, VY: Single;
    Char: Integer;
    BmpShot: Integer;          { shot the current bitmap was drawn for }
  end;

  { TAnimeWorker }

  TAnimeWorker = class(TThread)
  private
    FGo: PRTLEvent;
  protected
    procedure Execute; override;
  public
    Back: TBGRABitmap;
    W, H, Char, Feather: Integer;
    OX, OY, S, T: Single;
    Pose: TChibiPose;
    Busy, Done: Boolean;
    ShotIdx: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Start;
  end;

  { TAnimeDirector }

  TAnimeDirector = class
  private
    FKind: Integer;
    FPath: string;
    FFrames: array of TBGRABitmap;
    FShot: TShotKind;
    FShotT, FShotDur, FGap: Single;
    FShotIdx: Integer;
    FDir: Integer;
    FTime, FDrawClock: Single;
    FFieldW, FFieldH: Single;
    FPortrait: TBGRABitmap;
    FPortraitClock: Single;
    FWork: array[0..1] of TAnimeWorker;
    FPoofT, FPoofX, FPoofY, FPoofR: Single;
    FPose: TChibiPose;
    FNominal: Single;          { full size of the current shot (render resolution) }
    procedure FreeFrames;
    procedure LoadFrames(const APath: string);
    function UserFrame: TBGRABitmap;
    procedure NextShot;
    procedure RenderLayer(I: Integer);
    procedure Place(I: Integer; X, Y, W, H: Single);
    procedure FlushWorkers;
  public
    L: array[0..1] of TCharLayer;
    EchoMix: Single;            { kept for the engine hook: chibis are never drawn by the dots }
    Flash: Single;
    SizeMul: Single;
    Excited: Single;
    RenderScale: Single;
    Opacity: Byte;              { character overlay opacity (128 = half transparent) }
    constructor Create;
    destructor Destroy; override;
    procedure Setup(AKind: Integer; const AFileOrDir: string);
    procedure Step(dt, AFieldW, AFieldH: Single);
    procedure DrawOverlay(Bmp: TBGRABitmap; K: Single);
    function Active: Boolean;
    function CloseUpOn: Boolean;
    function Shown: Boolean;
    property Portrait: TBGRABitmap read FPortrait;
  end;

procedure DrawChibi(Bmp: TBGRABitmap; AChar: Integer; OX, OY, S: Single; const Pz: TChibiPose; T: Single);
function DefaultChibiPose(AChar: Integer): TChibiPose;

var
  AnimeDbg: Integer = 0;

implementation

type
  TPts = array of TPointF;

procedure AddP(var A: TPts; const P: TPointF);
begin
  SetLength(A, Length(A) + 1);
  A[High(A)] := P;
end;

function QB(const P0, P1, P2: TPointF; t: Single): TPointF;
var
  u: Single;
begin
  u := 1 - t;
  Result := PointF(u * u * P0.x + 2 * u * t * P1.x + t * t * P2.x, u * u * P0.y + 2 * u * t * P1.y + t * t * P2.y);
end;

procedure AddQ(var A: TPts; const P0, P1, P2: TPointF; N: Integer);
var
  i: Integer;
begin
  for i := 1 to N do AddP(A, QB(P0, P1, P2, i / N));
end;

function Strand(const Root, Ctrl, Tip: TPointF; WRoot, WTip: Single): TPts;
var
  i, n: Integer;
  t, u, w, nx, ny, l: Single;
  p, d: TPointF;
  right: TPts;
begin
  n := 14;
  Result := nil; right := nil;
  for i := 0 to n do
  begin
    t := i / n; u := 1 - t;
    p := QB(Root, Ctrl, Tip, t);
    d := PointF(2 * u * (Ctrl.x - Root.x) + 2 * t * (Tip.x - Ctrl.x), 2 * u * (Ctrl.y - Root.y) + 2 * t * (Tip.y - Ctrl.y));
    l := Max(1e-4, Sqrt(d.x * d.x + d.y * d.y));
    nx := -d.y / l; ny := d.x / l;
    w := WRoot + (WTip - WRoot) * t;
    AddP(Result, PointF(p.x + nx * w, p.y + ny * w));
    AddP(right, PointF(p.x - nx * w, p.y - ny * w));
  end;
  for i := High(right) downto 0 do AddP(Result, right[i]);
end;

function WithA(const C: TBGRAPixel; A: Byte): TBGRAPixel;
begin
  Result := C;
  Result.alpha := A;
end;

function DefaultChibiPose(AChar: Integer): TChibiPose;
begin
  Result.Blink := 1;
  Result.HandUp := 0;
  Result.Frame := False;
  case AChar of
    AN_KUMA: begin Result.Expr := exHappy; Result.Hand := chPaw; end;
    AN_NEKO: begin Result.Expr := exSparkle; Result.Hand := chWave; end;
    AN_AO: begin Result.Expr := exWink; Result.Hand := chPeace; end;
  else
    begin Result.Expr := exCat; Result.Hand := chNone; end;
  end;
end;

{ ------------------------------------------------------------------------
  Chibi drawing. u horizontal from the centre, v from the top of the ears /
  hood (0) to the feet (1). The head is ~60 % of the height.
  ------------------------------------------------------------------------ }
procedure DrawChibi(Bmp: TBGRABitmap; AChar: Integer; OX, OY, S: Single; const Pz: TChibiPose; T: Single);
const
  HX = 0.0; HY = 0.39; HRX = 0.33; HRY = 0.29;    { head ellipse }
var
  ink, skin, blush, hair, hairD, hairL, outfit, outfit2, iris, irisL, accent: TBGRAPixel;
  lw, hairLen, a, r, bob: Single;
  pts: TPts;
  i, side: Integer;
  catEars, longHair, hood: Boolean;

  function P(U, V: Single): TPointF;
  begin
    Result := PointF(OX + U * S, OY + (V + bob) * S);
  end;

  procedure Poly(const A: TPts; const C: TBGRAPixel; Outline: Boolean = True);
  begin
    if Length(A) < 3 then Exit;
    Bmp.FillPolyAntialias(A, C);
    if Outline then Bmp.DrawPolygonAntialias(A, ink, lw);
  end;

  procedure Ell(U, V, RX, RY: Single; const C: TBGRAPixel; Outline: Boolean = True);
  begin
    Bmp.FillEllipseAntialias(P(U, V).x, P(U, V).y, RX * S, RY * S, C);
    if Outline then Bmp.EllipseAntialias(P(U, V).x, P(U, V).y, RX * S, RY * S, ink, lw);
  end;

  procedure Line(U0, V0, U1, V1: Single; const C: TBGRAPixel; W: Single);
  begin
    Bmp.DrawLineAntialias(P(U0, V0).x, P(U0, V0).y, P(U1, V1).x, P(U1, V1).y, C, W);
  end;

  procedure Arc(U, V, RX, RY, A0, A1: Single; const C: TBGRAPixel; W: Single);
  var
    q: TPts;
    k: Integer;
  begin
    q := nil;
    for k := 0 to 16 do
      AddP(q, P(U + Cos(A0 + (A1 - A0) * k / 16) * RX, V + Sin(A0 + (A1 - A0) * k / 16) * RY));
    Bmp.DrawPolyLineAntialias(q, C, W);
  end;

  procedure Sparkle(U, V, R: Single; const C: TBGRAPixel);
  var
    q: TPts;
    k: Integer;
  begin
    q := nil;
    for k := 0 to 7 do
      if k mod 2 = 0 then AddP(q, P(U + Cos(k * Pi / 4) * R, V + Sin(k * Pi / 4) * R))
      else AddP(q, P(U + Cos(k * Pi / 4) * R * 0.28, V + Sin(k * Pi / 4) * R * 0.28));
    Bmp.FillPolyAntialias(q, C);
  end;

  procedure ClosedArc(U, V: Single);
  begin
    Arc(U, V + 0.015, 0.05, 0.035, Pi * 1.1, Pi * 1.9, ink, lw * 3.2);    { ^ }
  end;

  procedure Chevron(U, V: Single; Dir: Integer);
  begin
    Line(U - Dir * 0.04, V - 0.035, U + Dir * 0.035, V, ink, lw * 3.2);
    Line(U + Dir * 0.035, V, U - Dir * 0.04, V + 0.035, ink, lw * 3.2);
  end;

  procedure SparkleEye(U, V: Single);
  begin
    if Pz.Blink < 0.15 then begin ClosedArc(U, V); Exit; end;
    Ell(U, V, 0.058, 0.075 * Pz.Blink, iris, False);
    Ell(U, V + 0.03 * Pz.Blink, 0.05, 0.04 * Pz.Blink, irisL, False);
    Ell(U, V - 0.035 * Pz.Blink, 0.056, 0.035 * Pz.Blink, WithA(ink, 120), False);
    Ell(U, V + 0.005, 0.026, 0.04 * Pz.Blink, WithA(ink, 200), False);
    Ell(U - 0.022, V - 0.03 * Pz.Blink, 0.022, 0.024 * Pz.Blink, BGRAWhite, False);
    Ell(U + 0.02, V + 0.035 * Pz.Blink, 0.011, 0.011 * Pz.Blink, BGRAWhite, False);
    Sparkle(U + 0.022, V - 0.012, 0.018, BGRAWhite);
    Arc(U, V + 0.005, 0.064, 0.08 * Pz.Blink, Pi * 1.08, Pi * 1.92, ink, lw * 3.4);
  end;

  procedure RingEye(U, V: Single);
  begin
    if Pz.Blink < 0.15 then begin ClosedArc(U, V); Exit; end;
    Bmp.FillEllipseAntialias(P(U, V).x, P(U, V).y, 0.05 * S, 0.05 * S * Pz.Blink, BGRAWhite);
    Bmp.EllipseAntialias(P(U, V).x, P(U, V).y, 0.044 * S, 0.044 * S * Pz.Blink, ink, lw * 4.2);
    Line(U, V - 0.05, U, V - 0.075, ink, lw * 1.6);
  end;

  procedure DotEye(U, V: Single);
  begin
    if Pz.Blink < 0.15 then begin ClosedArc(U, V); Exit; end;
    Ell(U, V, 0.034, 0.048 * Pz.Blink, ink, False);
    Ell(U - 0.01, V - 0.016 * Pz.Blink, 0.012, 0.015 * Pz.Blink, BGRAWhite, False);
  end;

  procedure OpenMouth(U, V, W, Hh: Single; Fang: Boolean);
  var
    q: TPts;
  begin
    q := nil;
    AddP(q, P(U - W, V));
    AddP(q, P(U + W, V));
    AddQ(q, P(U + W, V), P(U, V + Hh * 2.2), P(U - W, V), 12);
    Poly(q, BGRA(176, 48, 72));
    Ell(U, V + Hh * 0.75, W * 0.55, Hh * 0.38, BGRA(255, 140, 160), False);
    if Fang then
    begin
      q := nil;
      AddP(q, P(U - W * 0.55, V)); AddP(q, P(U - W * 0.25, V)); AddP(q, P(U - W * 0.4, V + Hh * 0.55));
      Bmp.FillPolyAntialias(q, BGRAWhite);
    end;
  end;

  procedure CatMouth(U, V: Single);
  begin
    Arc(U - 0.022, V, 0.022, 0.02, 0, Pi, ink, lw * 1.8);
    Arc(U + 0.022, V, 0.022, 0.02, 0, Pi, ink, lw * 1.8);
  end;

  procedure Spiral(U, V: Single);
  var
    q: TPts;
    k: Integer;
    rr, aa: Single;
  begin
    q := nil;
    for k := 0 to 40 do
    begin
      aa := k * 0.42;
      rr := 0.004 + k * 0.0011;
      AddP(q, P(U + Cos(aa) * rr, V + Sin(aa) * rr * 0.85));
    end;
    Bmp.DrawPolyLineAntialias(q, WithA(blush, 230), lw * 1.5);
  end;

  procedure Hand(Side: Integer; Up: Single; Kind: TChibiHand);
  var
    hx, hy, wv: Single;
    q: TPts;
    sleeve: TBGRAPixel;
    k: Integer;
  begin
    wv := 0;
    if Kind in [chWave, chPaw] then wv := Sin(T * 13) * 0.025 * Up;
    hx := Side * (0.22 + 0.1 * Up) + wv;
    hy := 0.84 - 0.42 * Up;
    if hood then sleeve := hairD else sleeve := outfit;
    q := Strand(P(Side * 0.14, 0.7), P(Side * (0.2 + 0.08 * Up), 0.76 - 0.2 * Up), P(hx, hy + 0.03), 0.045 * S, 0.04 * S);
    Poly(q, sleeve);
    if Kind = chPaw then
    begin
      Ell(hx, hy, 0.072, 0.068, sleeve);
      Ell(hx, hy + 0.012, 0.032, 0.028, BGRA(255, 150, 170), False);
      for k := -1 to 1 do Ell(hx + k * 0.03, hy - 0.035 + Abs(k) * 0.008, 0.014, 0.014, BGRA(255, 150, 170), False);
    end
    else
    begin
      if Kind = chPeace then
      begin
        Poly(Strand(P(hx - 0.012, hy - 0.02), P(hx - 0.025, hy - 0.06), P(hx - 0.035, hy - 0.11), 0.014 * S, 0.012 * S), skin);
        Poly(Strand(P(hx + 0.012, hy - 0.02), P(hx + 0.02, hy - 0.06), P(hx + 0.03, hy - 0.11), 0.014 * S, 0.012 * S), skin);
      end;
      Ell(hx, hy, 0.045, 0.042, skin);
    end;
  end;

begin
  ink := BGRA(60, 36, 60);
  skin := BGRA(255, 236, 222);
  blush := BGRA(255, 120, 150);
  catEars := False; longHair := True; hood := False; hairLen := 0.62;
  case AChar of
    AN_KUMA:
      begin
        hair := BGRA(98, 64, 52); hairD := BGRA(46, 54, 76); hairL := BGRA(150, 110, 90);
        outfit := BGRA(56, 66, 92); outfit2 := BGRA(230, 220, 205);
        iris := BGRA(60, 40, 40); irisL := BGRA(140, 90, 70); accent := BGRA(255, 150, 170);
        hood := True; longHair := False;
      end;
    AN_NEKO:
      begin
        hair := BGRA(46, 38, 44); hairD := BGRA(24, 20, 26); hairL := BGRA(110, 96, 112);
        outfit := BGRA(36, 32, 40); outfit2 := BGRA(250, 248, 252);
        iris := BGRA(140, 30, 30); irisL := BGRA(240, 110, 80); accent := BGRA(140, 86, 60);
        catEars := True; hairLen := 0.84;
      end;
    AN_AO:
      begin
        hair := BGRA(76, 128, 236); hairD := BGRA(40, 74, 170); hairL := BGRA(160, 200, 255);
        outfit := BGRA(220, 48, 60); outfit2 := BGRA(250, 250, 255);
        iris := BGRA(30, 120, 70); irisL := BGRA(110, 220, 130); accent := BGRA(255, 120, 170);
        hairLen := 0.86;
      end;
  else
    begin
      hair := BGRA(150, 82, 200); hairD := BGRA(96, 40, 150); hairL := BGRA(206, 160, 245);
      outfit := BGRA(255, 150, 60); outfit2 := BGRA(255, 236, 200);
      iris := BGRA(30, 30, 30); irisL := BGRA(80, 80, 80); accent := BGRA(255, 210, 50);
      catEars := True; hairLen := 0.6;
    end;
  end;
  lw := Max(1, 0.006 * S);
  bob := 0.006 * Sin(T * 3);

  { star frame (Pop) }
  if Pz.Frame then
  begin
    pts := nil;
    for i := 0 to 9 do
    begin
      a := -Pi / 2 + i * Pi / 5;
      if i mod 2 = 0 then r := 0.56 else r := 0.25;
      AddP(pts, P(Cos(a) * r, 0.52 + Sin(a) * r));
    end;
    Bmp.FillPolyAntialias(pts, BGRA(255, 238, 246));
    Bmp.DrawPolygonAntialias(pts, BGRA(255, 130, 175), lw * 6);
  end;

  { back hair / hood }
  if hood then
  begin
    for side := -1 to 1 do
      if side <> 0 then
      begin
        Ell(side * 0.25, 0.08, 0.085, 0.08, hairD);
        Ell(side * 0.25, 0.085, 0.045, 0.042, BGRA(90, 100, 128), False);
      end;
    Ell(HX, HY - 0.01, HRX + 0.07, HRY + 0.09, hairD);
  end
  else if longHair then
  begin
    pts := nil;
    for i := 0 to 20 do
    begin
      a := Pi + i * Pi / 20;
      AddP(pts, P(Cos(a) * (HRX + 0.05), HY + Sin(a) * (HRY + 0.06)));
    end;
    AddP(pts, P(HRX + 0.07, hairLen - 0.05));
    for i := 0 to 6 do
      AddP(pts, P(HRX + 0.07 - i * (2 * HRX + 0.14) / 6, hairLen + 0.03 * ((i + 1) mod 2) + 0.01 * Sin(T * 2 + i)));
    AddP(pts, P(-HRX - 0.07, hairLen - 0.05));
    Poly(pts, hairD);
  end;

  { body }
  for side := -1 to 1 do
    if side <> 0 then
      Ell(side * 0.075, 0.955, 0.06, 0.04, BGRA(70, 56, 80));
  pts := nil;
  AddP(pts, P(-0.13, 0.66)); AddP(pts, P(0.13, 0.66));
  AddQ(pts, P(0.13, 0.66), P(0.2, 0.78), P(0.19, 0.93), 6);
  AddP(pts, P(-0.19, 0.93));
  AddQ(pts, P(-0.19, 0.93), P(-0.2, 0.78), P(-0.13, 0.66), 6);
  if hood then Poly(pts, hairD) else Poly(pts, outfit);
  case AChar of
    AN_KUMA: Ell(0, 0.82, 0.1, 0.085, BGRA(120, 130, 156), False);
    AN_AO:
      begin
        Line(-0.035, 0.67, -0.06, 0.92, outfit2, lw * 3);
        Line(0.035, 0.67, 0.06, 0.92, outfit2, lw * 3);
      end;
    AN_NEKO:
      begin
        pts := nil;
        AddP(pts, P(-0.1, 0.66)); AddP(pts, P(0.1, 0.66)); AddP(pts, P(0, 0.74));
        Poly(pts, outfit2);
        Ell(0, 0.71, 0.018, 0.018, accent, False);
      end;
  else
    begin
      Ell(0, 0.79, 0.05, 0.035, outfit2, False);
      Line(-0.03, 0.67, -0.04, 0.73, outfit2, lw * 2);
      Line(0.03, 0.67, 0.04, 0.73, outfit2, lw * 2);
    end;
  end;
  if Pz.Hand = chNone then
  begin
    Hand(-1, 0, chWave);
    Hand(1, 0, chWave);
  end
  else
    Hand(-1, 0, chWave);

  { face }
  Ell(HX, HY, HRX, HRY, skin);
  if AChar = AN_MIMI then
  begin
    Spiral(-0.2, 0.5);
    Spiral(0.2, 0.5);
  end
  else
    for side := -1 to 1 do
      if side <> 0 then
      begin
        Ell(side * 0.19, 0.5, 0.05, 0.022, WithA(blush, 110), False);
        for i := 0 to 2 do
          Line(side * 0.19 - 0.022 + i * 0.02, 0.488, side * 0.19 - 0.03 + i * 0.02, 0.512, WithA(blush, 200), lw * 0.9);
      end;
  case Pz.Expr of
    exHappy: begin ClosedArc(-0.13, 0.45); ClosedArc(0.13, 0.45); end;
    exXD: begin Chevron(-0.13, 0.45, 1); Chevron(0.13, 0.45, -1); end;
    exWink: begin Chevron(-0.13, 0.45, 1); SparkleEye(0.13, 0.45); end;
    exSparkle: begin SparkleEye(-0.13, 0.45); SparkleEye(0.13, 0.45); end;
    exCat: begin RingEye(-0.14, 0.45); RingEye(0.14, 0.45); end;
  else
    begin DotEye(-0.13, 0.45); DotEye(0.13, 0.45); end;
  end;
  case Pz.Expr of
    exCat, exSmile: CatMouth(0, 0.55);
    exSparkle: OpenMouth(0, 0.545, 0.045, 0.028, AChar = AN_NEKO);
    exWink: OpenMouth(0, 0.55, 0.035, 0.024, False);
  else
    OpenMouth(0, 0.545, 0.05, 0.032, False);
  end;

  { front hair }
  if hood then
  begin
    pts := nil;
    AddP(pts, P(-0.3, 0.3));
    for i := 0 to 8 do
      AddP(pts, P(-0.3 + i * 0.075, 0.36 + 0.03 * (i mod 2)));
    AddP(pts, P(0.3, 0.3));
    AddQ(pts, P(0.3, 0.3), P(0, 0.12), P(-0.3, 0.3), 10);
    Poly(pts, hair);
    Arc(HX, HY - 0.02, HRX + 0.03, HRY - 0.01, Pi * 1.05, Pi * 1.95, hairD, lw * 9);
    Ell(0, 0.13, 0.016, 0.016, BGRA(20, 20, 28), False);
    Ell(-0.06, 0.1, 0.012, 0.012, BGRA(20, 20, 28), False);
    Ell(0.06, 0.1, 0.012, 0.012, BGRA(20, 20, 28), False);
  end
  else
  begin
    pts := nil;
    for i := 0 to 20 do
    begin
      a := Pi + i * Pi / 20;
      AddP(pts, P(Cos(a) * (HRX + 0.03), HY - 0.01 + Sin(a) * (HRY + 0.04)));
    end;
    for i := 0 to 9 do
      AddP(pts, P(HRX + 0.02 - i * (2 * HRX + 0.04) / 9, 0.33 + 0.07 * Ord(i mod 2 = 1) - 0.03 * Ord((i = 0) or (i = 9))));
    Poly(pts, hair);
    Arc(HX, HY - 0.04, HRX - 0.06, HRY - 0.07, Pi * 1.2, Pi * 1.45, WithA(hairL, 220), lw * 4);
    Arc(HX, HY - 0.04, HRX - 0.06, HRY - 0.07, Pi * 1.55, Pi * 1.75, WithA(hairL, 220), lw * 4);
    for side := -1 to 1 do
      if side <> 0 then
        Poly(Strand(P(side * 0.29, 0.3), P(side * (HRX + 0.04), 0.5), P(side * 0.3, hairLen - 0.02 + Ord(not longHair) * 0.1),
          0.05 * S, 0.006 * S), hair);
    if catEars then
      for side := -1 to 1 do
        if side <> 0 then
        begin
          pts := nil;
          AddP(pts, P(side * 0.12, 0.16)); AddP(pts, P(side * 0.29, -0.02 + 0.01 * Sin(T * 4 + side))); AddP(pts, P(side * 0.31, 0.24));
          Poly(pts, hair);
          pts := nil;
          AddP(pts, P(side * 0.17, 0.16)); AddP(pts, P(side * 0.275, 0.04)); AddP(pts, P(side * 0.28, 0.2));
          if AChar = AN_NEKO then Poly(pts, BGRA(250, 245, 250), False) else Poly(pts, BGRA(255, 170, 200), False);
        end;
    if AChar = AN_AO then
      Poly(Strand(P(0.02, 0.1), P(0.1, -0.04 + 0.01 * Sin(T * 5)), P(0.02, -0.07), 0.018 * S, 0.003 * S), hair);
  end;

  { accessories }
  case AChar of
    AN_MIMI:
      begin
        Sparkle(-0.27, 0.2, 0.09, WithA(accent, 140));
        pts := nil;
        for i := 0 to 9 do
        begin
          a := -Pi / 2 + i * Pi / 5;
          if i mod 2 = 0 then r := 0.075 else r := 0.032;
          AddP(pts, P(-0.26 + Cos(a) * r, 0.2 + Sin(a) * r));
        end;
        Poly(pts, accent);
        Line(0.2, 0.26, 0.29, 0.22, BGRA(150, 80, 230), lw * 4);
        Line(0.21, 0.3, 0.3, 0.26, BGRA(150, 80, 230), lw * 4);
      end;
    AN_NEKO:
      begin
        pts := nil;
        AddP(pts, P(-0.12, 0.2)); AddP(pts, P(-0.24, 0.13)); AddP(pts, P(-0.23, 0.27));
        Poly(pts, accent);
        pts := nil;
        AddP(pts, P(-0.12, 0.2)); AddP(pts, P(0.0, 0.13)); AddP(pts, P(-0.01, 0.27));
        Poly(pts, accent);
        Ell(-0.12, 0.2, 0.03, 0.03, BGRA(240, 190, 120));
      end;
  end;

  if Pz.Hand <> chNone then Hand(1, Pz.HandUp, Pz.Hand);
end;

{ ------------------------------------------------------------------------ }

procedure FeatherEdges(B: TBGRABitmap);
var
  x, y, bw, bh: Integer;
  p: PBGRAPixel;
  f, dy: Single;
  fx: array of Single;
begin
  bw := B.Width; bh := B.Height;
  SetLength(fx, bw);
  for x := 0 to bw - 1 do fx[x] := Sqr((x / bw - 0.5) * 2) * 0.9;
  for y := 0 to bh - 1 do
  begin
    dy := Max(0, (y / bh - 0.35) / 0.65);
    p := B.ScanLine[y];
    for x := 0 to bw - 1 do
    begin
      if p^.alpha > 0 then
      begin
        f := Sqrt(fx[x] + dy * dy) - 0.66;
        if f > 0 then f := 1 - Sqr(f / 0.34) else f := 1;
        f := Min(f, y / (bh * 0.06));
        if f < 1 then p^.alpha := Round(p^.alpha * EnsureRange(f, 0, 1));
      end;
      Inc(p);
    end;
  end;
  B.InvalidateBitmap;
end;

{ TAnimeWorker }

constructor TAnimeWorker.Create;
begin
  FGo := RTLEventCreate;
  inherited Create(False);
end;

destructor TAnimeWorker.Destroy;
begin
  Terminate;
  RTLEventSetEvent(FGo);
  WaitFor;
  RTLEventDestroy(FGo);
  Back.Free;
  inherited Destroy;
end;

procedure TAnimeWorker.Start;
begin
  Busy := True;
  Done := False;
  RTLEventSetEvent(FGo);
end;

procedure TAnimeWorker.Execute;
begin
  while True do
  begin
    RTLEventWaitFor(FGo);
    if Terminated then Break;
    try
      if (Back = nil) or (Back.Width <> W) or (Back.Height <> H) then
      begin
        FreeAndNil(Back);
        Back := TBGRABitmap.Create(W, H);
      end;
      Back.Fill(BGRAPixelTransparent);
      DrawChibi(Back, Char, OX, OY, S, Pose, T);
      if Feather = 1 then FeatherEdges(Back);
      Done := True;
    except
      Done := False;
    end;
    Busy := False;
  end;
end;

{ TAnimeDirector }

constructor TAnimeDirector.Create;
var
  i: Integer;
begin
  inherited Create;
  FKind := -1;
  SizeMul := 1;
  RenderScale := 0.63;
  Opacity := 90;            { 50 % then 30 % fainter = 35 % opaque }
  for i := 0 to 1 do L[i] := Default(TCharLayer);
end;

destructor TAnimeDirector.Destroy;
var
  i: Integer;
begin
  for i := 0 to 1 do FreeAndNil(FWork[i]);
  FreeFrames;
  for i := 0 to 1 do L[i].Bmp.Free;
  FPortrait.Free;
  inherited Destroy;
end;

procedure TAnimeDirector.FreeFrames;
var
  i: Integer;
begin
  for i := 0 to High(FFrames) do FFrames[i].Free;
  FFrames := nil;
end;

procedure TAnimeDirector.LoadFrames(const APath: string);
var
  sr: TSearchRec;
  names: TStringList;
  i: Integer;

  procedure Add(const F: string);
  var
    b: TBGRABitmap;
  begin
    try
      b := TBGRABitmap.Create(F);
      if b.Height > 600 then BGRAReplace(b, b.Resample(Round(b.Width * 600 / b.Height), 600, rmFineResample));
      SetLength(FFrames, Length(FFrames) + 1);
      FFrames[High(FFrames)] := b;
    except
    end;
  end;

begin
  FreeFrames;
  if APath = '' then Exit;
  if DirectoryExists(APath) then
  begin
    names := TStringList.Create;
    try
      if FindFirst(IncludeTrailingPathDelimiter(APath) + '*.*', faAnyFile, sr) = 0 then
      begin
        repeat
          if (sr.Attr and faDirectory = 0) and
             ((LowerCase(ExtractFileExt(sr.Name)) = '.png') or (LowerCase(ExtractFileExt(sr.Name)) = '.jpg')) then
            names.Add(IncludeTrailingPathDelimiter(APath) + sr.Name);
        until FindNext(sr) <> 0;
        FindClose(sr);
      end;
      names.Sort;
      for i := 0 to Min(names.Count, 240) - 1 do Add(names[i]);
    finally
      names.Free;
    end;
  end
  else if FileExists(APath) then
    Add(APath);
end;

function TAnimeDirector.UserFrame: TBGRABitmap;
begin
  if Length(FFrames) = 0 then Exit(nil);
  Result := FFrames[Trunc(FTime * 12) mod Length(FFrames)];
end;

procedure TAnimeDirector.Setup(AKind: Integer; const AFileOrDir: string);
begin
  if (AKind = FKind) and (AFileOrDir = FPath) then Exit;
  FKind := AKind;
  FPath := AFileOrDir;
  FreeFrames;
  if AKind = AN_IMAGE then
  begin
    LoadFrames(AFileOrDir);
    if Length(FFrames) = 0 then FKind := AN_PARTY;
  end;
  FShotIdx := -1;
  FShotDur := 0;
  FGap := 0.8;
  L[0].Visible := False;
  L[1].Visible := False;
  EchoMix := 0;
end;

function TAnimeDirector.Active: Boolean;
begin
  Result := (FKind > 0) and L[0].Visible;
end;

function TAnimeDirector.Shown: Boolean;
begin
  Result := L[0].Visible and (L[0].Bmp <> nil) and (L[0].BmpShot = FShotIdx);
end;

function TAnimeDirector.CloseUpOn: Boolean;
begin
  Result := (FShotDur > 0) and (FShot in [skPop, skSide]) and L[0].Visible;
end;

procedure TAnimeDirector.NextShot;
begin
  Inc(FShotIdx);
  FDir := 1 - 2 * Ord(Random < 0.5);
  case FShotIdx mod 4 of
    0: FShot := skPeek;
    1: FShot := skHop;
    2: FShot := skPop;
  else
    FShot := skSide;
  end;
  if FShot = skPop then FShotDur := 2.4 else FShotDur := 2.6;
  FShotT := 0;
  if FKind = AN_PARTY then L[0].Char := AN_MIMI + FShotIdx mod 4
  else L[0].Char := FKind;
  FPose := DefaultChibiPose(L[0].Char);
  case FShot of
    skPeek: FNominal := 360;
    skHop: FNominal := 280;
    skPop: FNominal := 520;
  else
    FNominal := 760;
  end;
  FDrawClock := 0;          { start drawing the new shot right away }
  FPortraitClock := 0;      { cut-in portrait follows the character }
end;

procedure TAnimeDirector.RenderLayer(I: Integer);
var
  w, h: Integer;
  s, ox, oy, sc: Single;
  src, tmp: TBGRABitmap;
begin
  if FKind = AN_IMAGE then
  begin
    src := UserFrame;
    if src = nil then Exit;
    if (L[I].Bmp = nil) or (L[I].Bmp.Width <> src.Width) or (L[I].Bmp.Height <> src.Height) then
    begin
      FreeAndNil(L[I].Bmp);
      L[I].Bmp := TBGRABitmap.Create(src.Width, src.Height);
    end;
    L[I].Bmp.PutImage(0, 0, src, dmSet);
    L[I].BmpShot := FShotIdx;
    Exit;
  end;
  w := 600; h := 600;
  if FShot = skSide then begin s := 1050; ox := 300; oy := 300 - 0.39 * s; end
  else begin s := 560; ox := 300; oy := 20; end;
  sc := EnsureRange(FNominal * SizeMul * Max(0.2, RenderScale) / h, 0.2, 1);
  w := Max(16, Round(w * sc)); h := Max(16, Round(h * sc));
  s := s * sc; ox := ox * sc; oy := oy * sc;
  if FWork[I] = nil then FWork[I] := TAnimeWorker.Create;
  if FWork[I].Busy then Exit;
  if FWork[I].Done then
  begin
    tmp := L[I].Bmp;
    L[I].Bmp := FWork[I].Back;
    L[I].BmpShot := FWork[I].ShotIdx;
    FWork[I].Back := tmp;
    FWork[I].Done := False;
  end;
  FWork[I].ShotIdx := FShotIdx;
  FWork[I].W := w; FWork[I].H := h;
  FWork[I].OX := ox; FWork[I].OY := oy; FWork[I].S := s;
  FWork[I].Char := L[I].Char;
  FWork[I].Pose := FPose;
  FWork[I].T := FTime;
  FWork[I].Feather := Ord(FShot = skSide);
  FWork[I].Start;
end;

procedure TAnimeDirector.FlushWorkers;
var
  I: Integer;
  tmp: TBGRABitmap;
begin
  for I := 0 to 1 do
    if (FWork[I] <> nil) and not FWork[I].Busy and FWork[I].Done then
    begin
      tmp := L[I].Bmp;
      L[I].Bmp := FWork[I].Back;
      L[I].BmpShot := FWork[I].ShotIdx;
      FWork[I].Back := tmp;
      FWork[I].Done := False;
    end;
end;

procedure TAnimeDirector.Place(I: Integer; X, Y, W, H: Single);
begin
  L[I].CX := X; L[I].CY := Y;
  L[I].W := W * SizeMul; L[I].H := H * SizeMul;
  L[I].Rot := 0;
  L[I].Alpha := 1;
  L[I].Visible := True;
end;

function EaseOutBack(t: Single): Single;
const
  C1 = 1.70158; C3 = C1 + 1;
begin
  t := EnsureRange(t, 0, 1);
  Result := 1 + C3 * Power(t - 1, 3) + C1 * Sqr(t - 1);
end;

function EaseOutElastic(t: Single): Single;
begin
  t := EnsureRange(t, 0, 1);
  if t <= 0 then Exit(0);
  if t >= 1 then Exit(1);
  Result := Power(2, -10 * t) * Sin((t * 10 - 0.75) * (2 * Pi / 3)) + 1;
end;

function EaseIn(t: Single): Single;
begin
  t := EnsureRange(t, 0, 1);
  Result := t * t * t;
end;

procedure TAnimeDirector.Step(dt, AFieldW, AFieldH: Single);
var
  t, x, y, sz, sx, sy, ph, g, up, aspect: Single;
  i: Integer;
begin
  FTime := FTime + dt;
  FFieldW := AFieldW; FFieldH := AFieldH;
  if Flash > 0 then Flash := Max(0, Flash - dt * 2.5);
  if FPoofT > 0 then FPoofT := Max(0, FPoofT - dt);
  if FKind <= 0 then Exit;
  if FShotDur <= 0 then
  begin
    FGap := FGap - dt;
    L[0].Visible := False;
    if FGap > 0 then Exit;
    NextShot;
  end;
  FShotT := FShotT + dt;
  t := FShotT / FShotDur;
  if t >= 1 then
  begin
    FShotDur := 0;
    FGap := 1.0 + Random * 1.4;
    L[0].Visible := False;
    Exit;
  end;
  aspect := 1;
  if (FKind = AN_IMAGE) and (UserFrame <> nil) then aspect := UserFrame.Width / Max(1, UserFrame.Height);
  FPose.Blink := 1;
  if Frac(FTime / 2.7) > 0.95 then FPose.Blink := 0.05;
  if (Excited > 0.7) and (FPose.Expr = exCat) then FPose.Expr := exHappy;
  sx := 1; sy := 1;
  case FShot of
    skPeek:
      begin
        sz := 360;
        x := FFieldW * 0.5 + FDir * FFieldW * 0.26;
        if t < 0.22 then up := EaseOutBack(t / 0.22)
        else if t > 0.8 then up := 1 - EaseIn((t - 0.8) / 0.2)
        else up := 1;
        y := FFieldH + sz * 0.5 - up * sz * 0.72;
        if (t > 0.18) and (t < 0.3) then
        begin
          g := Sin((t - 0.18) / 0.12 * Pi);
          sx := 1 + 0.12 * g; sy := 1 - 0.12 * g;
        end;
        if FPose.Hand <> chNone then FPose.HandUp := EnsureRange((t - 0.25) / 0.1, 0, 1) * Ord(t < 0.78)
        else FPose.HandUp := 0;
        if (FPose.Hand = chNone) and (t > 0.3) then FPose.Expr := exHappy;
        Place(0, x, y, sz * aspect * sx, sz * sy);
      end;
    skHop:
      begin
        sz := 280;
        x := FFieldW * 0.5 - FDir * (FFieldW * 0.5 + sz) + FDir * (FFieldW + 2 * sz) * t;
        ph := Frac(t * 4);
        y := FFieldH * 0.7 - Sin(ph * Pi) * 230;
        g := Max(0, 1 - Min(ph, 1 - ph) / 0.1);
        sx := 1 + 0.18 * g; sy := 1 - 0.2 * g;
        y := y + sz * 0.1 * g;
        if Frac(t * 2) > 0.5 then FPose.Expr := exXD else FPose.Expr := exHappy;
        if FPose.Hand = chNone then FPose.Hand := chWave;
        FPose.HandUp := 0.6 * (1 - g);
        Place(0, x, y, sz * aspect * sx, sz * sy);
      end;
    skPop:
      begin
        sz := 520;
        FPose.Frame := FKind <> AN_IMAGE;
        FPose.Expr := exWink;
        FPose.Hand := chPeace;
        FPose.HandUp := EnsureRange((t - 0.2) / 0.1, 0, 1);
        if t < 0.3 then g := EaseOutElastic(t / 0.3)
        else if t > 0.82 then
        begin
          g := 1 - EaseIn((t - 0.82) / 0.18);
          if FPoofT <= 0 then
          begin
            FPoofT := 0.6; FPoofX := FFieldW * 0.5; FPoofY := FFieldH * 0.34; FPoofR := sz * 0.4;
          end;
        end
        else g := 1 + 0.02 * Sin(FTime * 6);
        Place(0, FFieldW * 0.5, FFieldH * 0.34, sz * aspect * Max(0.01, g), sz * Max(0.01, g));
      end;
    skSide:
      begin
        sz := 760;
        if t < 0.2 then g := EaseOutBack(t / 0.2)
        else if t > 0.82 then g := 1 - EaseIn((t - 0.82) / 0.18)
        else g := 1;
        x := FFieldW * 0.5 + FDir * (FFieldW * 0.5 + sz * 0.5 - g * sz * 0.62);
        y := FFieldH * 0.3 + Sin(FTime * 2.5) * 8;
        if FPose.Expr in [exWink, exXD] then FPose.Expr := exSparkle;
        if (t > 0.5) and (t < 0.56) then FPose.Blink := 0.05;
        FPose.Hand := chNone;
        Place(0, x, y, sz * aspect, sz);
      end;
  end;
  FDrawClock := FDrawClock - dt;
  if (FDrawClock <= 0) and (AnimeDbg and 2 = 0) then
  begin
    FDrawClock := 1 / 24;
    RenderLayer(0);
  end;
  FlushWorkers;
  FPortraitClock := FPortraitClock - dt;
  if (FPortraitClock <= 0) and (AnimeDbg and 4 = 0) then
  begin
    FPortraitClock := 0.5;
    FreeAndNil(FPortrait);
    if FKind = AN_IMAGE then
    begin
      if UserFrame <> nil then
        FPortrait := UserFrame.GetPart(Rect(0, 0, UserFrame.Width, UserFrame.Height * 3 div 4)) as TBGRABitmap;
    end
    else
    begin
      FPortrait := TBGRABitmap.Create(300, 300);
      i := L[0].Char;
      if i <= 0 then i := AN_MIMI;
      DrawChibi(FPortrait, i, 150, 150 - 0.39 * 520, 520, DefaultChibiPose(i), FTime);
    end;
  end;
end;

procedure TAnimeDirector.DrawOverlay(Bmp: TBGRABitmap; K: Single);
var
  i, g: Integer;
  r: TRect;
  a, rr, sx, sy, sz: Single;
  pts: array of TPointF;
  c: TBGRAPixel;
begin
  if AnimeDbg and 1 <> 0 then Exit;
  if L[0].Visible and (L[0].Bmp <> nil) and (L[0].BmpShot = FShotIdx) then
  begin
    r := Rect(Round((L[0].CX - L[0].W / 2) * K), Round((L[0].CY - L[0].H / 2) * K),
      Round((L[0].CX + L[0].W / 2) * K), Round((L[0].CY + L[0].H / 2) * K));
    if (r.Width = L[0].Bmp.Width) and (r.Height = L[0].Bmp.Height) then
      Bmp.PutImage(r.Left, r.Top, L[0].Bmp, dmDrawWithTransparency, Opacity)
    else if (r.Width > 1) and (r.Height > 1) then
      Bmp.StretchPutImage(r, L[0].Bmp, dmDrawWithTransparency, Opacity);
  end;
  if FPoofT > 0 then
  begin
    a := FPoofT / 0.6;
    SetLength(pts, 8);
    for g := 0 to 11 do
    begin
      rr := FPoofR * (1.2 - a) * 1.4;
      sx := FPoofX + Cos(g * Pi / 6) * rr;
      sy := FPoofY + Sin(g * Pi / 6) * rr;
      sz := (10 + 8 * (g mod 3)) * a;
      for i := 0 to 7 do
        if i mod 2 = 0 then pts[i] := PointF((sx + Cos(i * Pi / 4) * sz) * K, (sy + Sin(i * Pi / 4) * sz) * K)
        else pts[i] := PointF((sx + Cos(i * Pi / 4) * sz * 0.3) * K, (sy + Sin(i * Pi / 4) * sz * 0.3) * K);
      case g mod 3 of
        0: c := BGRA(255, 230, 120, Round(255 * a));
        1: c := BGRA(255, 150, 200, Round(255 * a));
      else
        c := BGRA(255, 255, 255, Round(255 * a));
      end;
      Bmp.FillPolyAntialias(pts, c);
    end;
  end;
end;

end.

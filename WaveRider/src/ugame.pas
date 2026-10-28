{ WAVE RIDER - game logic (data driven).

  The player rides a light orb over the flowing dotted surface. Every object,
  level, screen effect, sound and the music come from TGameData, so the
  WaveRider Studio editors change the game without touching code.

  States
    Menu -> Levels -> Ready (3-2-1) -> Playing <-> Paused -> Menu (run kept: CONTINUE)
                                     -> Complete / GameOver
  Simulation (editors)
    SimLevel, SimObject, SimScreen + Autopilot / Invincible }
unit uGame;

{$mode objfpc}{$H+}
{$Q-}{$R-}

interface

uses
  Classes, SysUtils, Math, IniFiles, BGRABitmap, BGRABitmapTypes, BGRAGraphics,
  uWaveTypes, uWaveEngine, uGameData, uGfx, uParams, uLightFx, uAnime;

type
  TGameState = (gsMenu, gsLevels, gsOptions, gsLight, gsReady, gsPlaying, gsPaused, gsComplete, gsGameOver);
  TGameAction = (gaUp, gaDown, gaLeft, gaRight, gaConfirm, gaBack, gaPause);
  TSimMode = (smNone, smLevel, smObject, smScreen);

  TMenuItem = record
    Caption, Value: string;
    Id: Integer;
    Enabled: Boolean;
  end;

  TEntity = record
    Def: Integer;
    X, Y, BX, BY, Age, Phase, R, Angle: Single;
    VX, VY: Single;            { measured velocity (bot prediction) }
    Heat: Single;              { prism light exposure }
    Pulled: Boolean;           { caught by the diamond light, flying to the ship }
    PullV: Single;
  end;

  TRingFx = record
    X, Y, Age, Speed, Width, Strength, Decay: Single;
  end;

  TParticle = record
    X, Y, VX, VY, Life, MaxLife, Size: Single;
    Col: TBGRAPixel;
  end;

  TPopup = record
    Text: string;
    X, Y, Life, MaxLife: Single;
    Col: TBGRAPixel;
    Size: Integer;
  end;

  TMixEntry = record
    Obj: Integer;
    Weight: Single;
  end;
  TMix = array of TMixEntry;

  TTimedFx = record
    T, Dur: Single;
    Def: Integer;
  end;

  TLightEvent = record
    Kind: Integer;
    X, Y, Age, Life, Scale: Single;
  end;

  { TWaveGame }

  TWaveGame = class
  private
    FData: TGameData;
    FIniFile: string;
    FTime: Single;
    FEnt: array of TEntity;
    FEntCount: Integer;
    FRings: array of TRingFx;
    FRingCount: Integer;
    FParts: array of TParticle;
    FPartCount: Integer;
    FPops: array of TPopup;
    FPopCount: Integer;
    FTrail: array[0..19] of TPointF;
    FTrailTimer: Single;
    FAmbient: array of TParticle;
    { level runtime }
    FLevel: Integer;
    FCollectMix, FHazardMix, FBonusMix: TMix;
    FAccCollect, FAccHazard, FAccBonus: Single;
    FFx: array[EF_SHIELD..EF_DIAMOND] of TTimedFx;
    FSuspended: Boolean;
    FSlow: Single;
    FIri: Single;
    FFlash: Single;
    FSweep: Single;
    FMuffle: Single;
    FBanner: string;
    FBannerTime: Single;
    FBannerCol: TBGRAPixel;
    FNewBest: Boolean;
    FStarsEarned: Integer;
    FReadyT: Single;
    FReadyShown: Integer;
    FMenuScroll: Single;
    FMenuPhase: Single;
    { menu }
    FItems: array of TMenuItem;
    FSel: Integer;
    FLevelSel: Integer;
    FMouseRef: TPointF;
    { progress }
    FUnlocked: Integer;
    FBest: array of Integer;
    FStars: array of Integer;
    { sim }
    FSimObj: Integer;
    FSimTimer: Single;
    FText: TTextCache;
    FGlow: TGlowCache;
    FDots: TDotText;
    { light fx }
    FLayer: TLightLayer;
    FBeam, FTmp: TLightScene;
    FLightEv: array[0..2] of TLightEvent;
    procedure AddLightEvent(AX, AY: Single);
    procedure DrawSceneLight(Bmp: TBGRABitmap; AKind: Integer; CX, CY, AScale, AIntensity, AGlass, K: Single;
      ABeamLen: Single = 0);
    procedure DrawScreenLight(Bmp: TBGRABitmap; const F: TScreenFx; K: Single);
    procedure DrawLightLab(Bmp: TBGRABitmap; const F: TScreenFx; K: Single);
    function LightDef(AKind: Integer): TLightDef;
    procedure UpdateBeam;
  private
    { watch mode: a Super Hard bot plays every level until game over }
    FShow: Boolean;
    FShowTimer, FShowTotal, FShowBest: Single;
    FShowCleared, FShowLives: Integer;
    FBotX, FBotY: Single;
    FBotThink: Single;
    procedure ShowStartLevel(AIndex: Integer);
    procedure UpdateBot(dt: Single);
    procedure UpdateShow(dt: Single);
    procedure DrawShowHud(Bmp: TBGRABitmap; K: Single);
    function HardMul(AKind: Integer): Single;
  private
    { diffraction grating weapon }
    FPower: Single;            { collected grating power, unlimited }
    FCharging: Boolean;
    FCharge, FChargeTime, FChargeBlip: Single;
    FSavedPower: Single;       { player pool kept aside while the bot plays }
    FShot: TLightScene;
    FShotAge, FShotLife, FShotCharge, FShotX, FShotY: Single;
    FShotActive: Boolean;
    procedure UpdateGrating(dt: Single);
    procedure FireGrating;
    procedure BuildShot;
    procedure DrawGrating(Bmp: TBGRABitmap; K: Single);
    procedure CancelCharge;
    procedure BotGrating;
  private
    { dispersion prism sentinel }
    FPrismOn: Boolean;
    FPrismX, FPrismY, FPrismAng, FPrismSpin, FPrismPhi, FPrismSize: Single;
    FCurX, FCurY, FCurVX, FCurVY, FPredX, FPredY, FAimX, FAimY: Single;
    FPrismTarget: Integer;
    FPrismSolved: Boolean;
    procedure UpdatePrism(dt: Single);
  private
    { diamond light bonus }
    FDia: TLightScene;
    FDiaAng, FDiaX, FDiaY: Single;
    procedure UpdateDiamond(dt: Single);
    procedure DrawDiamond(Bmp: TBGRABitmap; K: Single);
  private
    { Newton's prisms guardian (combo > x3) }
    FNew: TLightScene;
    FNewOn: Boolean;
    FNewX, FNewY, FNewAng, FNewSpin, FNewT, FNewMaxT, FNewHurt, FNewAge: Single;
    FNewHP: Integer;
    procedure NewtonCombo(AOld, ANew: Integer);
    procedure UpdateNewton(dt: Single);
    procedure DrawNewton(Bmp: TBGRABitmap; K: Single);
    function NewtonSize: Single;
    procedure DrawPrismSentinel(Bmp: TBGRABitmap; K: Single);
  private
    { anime levels }
    FAnime: TAnimeDirector;
    FCutIn, FExcite: Single;
    FCutText: string;
    FCutLayer: TBGRABitmap;
    procedure CutIn(const AText: string);
    procedure DrawCutIn(Bmp: TBGRABitmap; K: Single);
    procedure DrawCutInBand(Bmp: TBGRABitmap; K: Single);
    procedure DrawLevelCard(Bmp: TBGRABitmap; K, AAlpha: Single);
    procedure DrawSpeedLines(Bmp: TBGRABitmap; CX, CY, AAlpha: Single; ACount: Integer);
    function ShowButtonAt(const P: TPointF): Integer;
    procedure LoadProgress;
    procedure SaveProgress;
    function Lv: TLevelDef;
    function ObjOk(I: Integer): Boolean;
    procedure ParseMix(const S: string; out M: TMix);
    function PickMix(const M: TMix): Integer;
    procedure AddEntity(ADef: Integer; AX, AY: Single; APhase: Single = -1);
    procedure RemoveEntity(I: Integer);
    procedure AddRing(AX, AY, ASpeed, AWidth, AStrength, ADecay: Single);
    procedure Burst(AX, AY: Single; ACount: Integer; ASpeed, ASize: Single; AMode: Integer; const ACol: TBGRAPixel);
    procedure Popup(const S: string; AX, AY: Single; const ACol: TBGRAPixel; ASize: Integer = 30);
    procedure Banner(const S: string; const ACol: TBGRAPixel; ATime: Single = 1.6);
    procedure Snd(const AName: string; AX: Single = -1; AVol: Single = 1; APitch: Single = 1);
    procedure BeginLevel(AIndex: Integer);
    procedure Spawn(dt: Single);
    procedure SpawnFromMix(const M: TMix; ARole: Integer);
    procedure UpdatePlay(dt: Single);
    procedure UpdateFx(dt, AScroll: Single);
    procedure UpdateAutopilot;
    procedure UpdateMusic(dt: Single);
    procedure Collide(I: Integer);
    procedure ApplyEffect(I: Integer);
    procedure Hit(AFrom: Integer);
    procedure ClearHazards(AScoreEach: Integer);
    procedure LevelComplete;
    procedure GameOver;
    procedure EnterState(AState: TGameState);
    procedure BuildMenu;
    procedure MenuActivate(AId: Integer; ADir: Integer = 0);
    function ItemAt(const P: TPointF): Integer;
    function ScreenFor(AState: TGameState): TScreenId;
    function Fx(AId: TScreenId): TScreenFx;
    function ComboIntensity: Single;
    function ObjColor(const D: TObjDef; ATime, APhase: Single): TBGRAPixel;
    procedure DrawEntity(Bmp: TBGRABitmap; const E: TEntity; K: Single);
    procedure DrawPixelArt(Bmp: TBGRABitmap; const D: TObjDef; CX, CY, Cell: Single);
    procedure DrawShip(Bmp: TBGRABitmap; K: Single);
    procedure DrawMenu(Bmp: TBGRABitmap; const F: TScreenFx; K: Single);
    procedure DrawHudPlay(Bmp: TBGRABitmap; K: Single);
    procedure DrawLevelList(Bmp: TBGRABitmap; const F: TScreenFx; K: Single);
    procedure DrawStarsRow(Bmp: TBGRABitmap; CX, CY, Size: Single; AEarned: Integer; AAnim: Single);
    procedure DrawAmbient(Bmp: TBGRABitmap; K: Single; ACount: Integer);
  public
    State: TGameState;
    Score, Lives, Combo, MaxCombo: Integer;
    ShipX, ShipY, ShipVX, ShipVY: Single;
    TargetX, TargetY: Single;
    UseMouse: Boolean;
    KeyLeft, KeyRight, KeyUp, KeyDown: Boolean;
    ScrollY, ScrollSpeed, PlayTime, Invuln, Phase: Single;
    Shake: Single;
    FieldW, FieldH: Single;
    Config: TWaveConfig;
    MusicVolume, SfxVolume: Single;
    Fullscreen: Boolean;
    RequestQuit, RequestFullscreen: Boolean;
    SoundOn: Boolean;
    { light fx: which optic the beam bonus uses, ambient flashes on/off }
    LightMode: Integer;
    AmbientLight: Boolean;
    LightLabFocus: Integer;     { editor: highlight a light kind in the Light lab }
    { simulation }
    SimMode: TSimMode;
    Autopilot, Invincible: Boolean;
    procedure StartShow;
    procedure StopShow;
    function IsShow: Boolean;
    { mouse cursor the window should show: 0 hidden (playing), 1 arrow, 2 hand (over a clickable item) }
    function CursorKind: Integer;
    { grating weapon input: left mouse / Space }
    procedure FireDown;
    procedure FireUp;
    procedure DebugFire(ACharge: Single);     { editors: fire a shot without input }
    property GratingPower: Single read FPower write FPower;
  public
    PrismFrames, PrismSolvedFrames, PrismKills, DiamondCatches, NewtonKills, NewtonSpawns: Integer;   { statistics (tests) }
    constructor Create(AData: TGameData; const AIniFile: string);
    destructor Destroy; override;
    procedure SetField(ABmpW, ABmpH: Integer);
    procedure MouseAt(AX, AY: Single; AW, AH: Integer);
    procedure Click(AX, AY: Single; AW, AH: Integer);
    procedure Action(A: TGameAction);
    procedure Update(dt: Single);
    procedure ApplyToEngine(E: TWaveEngine);
    procedure DrawWorld(Bmp: TBGRABitmap);
    procedure DrawHud(Bmp: TBGRABitmap);
    function PixelSize: Integer;
    function PosterizeLevels: Integer;
    procedure StartLevel(AIndex: Integer);
    procedure GoMenu;
    procedure DataChanged;            { editors: clear sprite caches }
    procedure ResetProgress;
    { simulation API }
    procedure SimLevel(AIndex: Integer);
    procedure SimObject(AObj, AStyleLevel: Integer);
    procedure SimScreen(AScreen: TScreenId);
    function NearestTarget(out AX, AY: Single): Boolean;
    function StateName: string;
    { editor helpers }
    procedure DrawObjectPreview(Bmp: TBGRABitmap; ADef: Integer; CX, CY, K: Single);
    procedure SpawnNearShip(ADef: Integer);
    procedure TickTime(dt: Single);
    property Data: TGameData read FData;
    property Level: Integer read FLevel;
    property Suspended: Boolean read FSuspended;
    property EntityCount: Integer read FEntCount;
    function AnimeShown: Boolean;
    function AnimeVisible: Boolean;
  end;

implementation

uses
  uAudio;

const
  SHIP_R = 16;
  MAX_COMBO = 9;
  MI_CONTINUE = 1; MI_PLAY = 2; MI_ENDLESS = 3; MI_OPTIONS = 4; MI_QUIT = 5;
  MI_RESUME = 10; MI_RESTART = 11; MI_MAINMENU = 12; MI_RETRY = 13; MI_NEXT = 14; MI_LEVELSEL = 15;
  MI_BACK = 20;
  MI_MUSIC = 30; MI_SFX = 31; MI_FULL = 32; MI_RESETPROG = 33; MI_BEAMFX = 34; MI_AMBIENT = 35;
  CUTIN_OPACITY = 90;           { combo popups: 50 % then 30 % fainter = 35 % opaque }
  MI_LIGHT = 6; MI_LKIND = 200; MI_WATCH = 7;
  SHOW_SPEED = 1.3; SHOW_HAZARD = 1.6; SHOW_COLLECT = 1.2;
  MI_LEVEL = 100;

{ TWaveGame }

constructor TWaveGame.Create(AData: TGameData; const AIniFile: string);
var
  i: Integer;
begin
  inherited Create;
  FData := AData;
  FIniFile := AIniFile;
  FText := TTextCache.Create;
  FGlow := TGlowCache.Create;
  FDots := TDotText.Create;
  FLayer := TLightLayer.Create;
  FBeam := TLightScene.Create;
  FTmp := TLightScene.Create;
  FShot := TLightScene.Create;
  FDia := TLightScene.Create;
  FNew := TLightScene.Create;
  FAnime := TAnimeDirector.Create;
  AmbientLight := True;
  LightLabFocus := -1;
  SetLength(FEnt, 64);
  SetLength(FRings, 32);
  SetLength(FParts, 900);
  SetLength(FPops, 32);
  SetLength(FAmbient, 300);
  for i := 0 to High(FAmbient) do
  begin
    FAmbient[i].X := Random * REF_WIDTH;
    FAmbient[i].Y := Random * REF_HEIGHT;
    FAmbient[i].VY := -(10 + Random * 40);
    FAmbient[i].VX := (Random - 0.5) * 10;
    FAmbient[i].Size := 1.5 + Random * 2.5;
    FAmbient[i].Life := Random;
  end;
  FieldW := REF_WIDTH;
  FieldH := REF_HEIGHT;
  ShipX := FieldW / 2;
  ShipY := FieldH * 0.78;
  MusicVolume := 0.8;
  SfxVolume := 0.9;
  SoundOn := True;
  FSimObj := -1;
  FSlow := 1;
  LoadProgress;
  Config := PresetConfig(0);
  EnterState(gsMenu);
end;

destructor TWaveGame.Destroy;
begin
  { keep the grating power the player collected (an unfinished charge goes back to the pool) }
  if FShow then StopShow;
  CancelCharge;
  SaveProgress;
  FText.Free;
  FGlow.Free;
  FDots.Free;
  FLayer.Free;
  FBeam.Free;
  FTmp.Free;
  FShot.Free;
  FDia.Free;
  FNew.Free;
  FAnime.Free;
  FCutLayer.Free;
  inherited Destroy;
end;

procedure TWaveGame.DataChanged;
var
  i, e: Integer;
begin
  { objects may have been deleted / reordered by an editor }
  i := FEntCount - 1;
  while i >= 0 do
  begin
    if not ObjOk(FEnt[i].Def) then RemoveEntity(i);
    Dec(i);
  end;
  for e := Low(FFx) to High(FFx) do
    if not ObjOk(FFx[e].Def) then FFx[e] := Default(TTimedFx);
  if not ObjOk(FSimObj) then FSimObj := -1;
  FText.Clear;
  FDots.Clear;
  FGlow.Clear;
  FAnime.Setup(-1, '');
  if FLevel > High(FData.Levels) then FLevel := 0;
  SetLength(FBest, Length(FData.Levels));
  SetLength(FStars, Length(FData.Levels));
  BuildMenu;
end;

{ ---------------- progress ---------------- }

procedure TWaveGame.LoadProgress;
var
  ini: TIniFile;
  i: Integer;
begin
  SetLength(FBest, Length(FData.Levels));
  SetLength(FStars, Length(FData.Levels));
  FUnlocked := 1;
  if FIniFile = '' then Exit;
  ini := TIniFile.Create(FIniFile);
  try
    FUnlocked := ini.ReadInteger('Progress', 'Unlocked', 1);
    for i := 0 to High(FBest) do
    begin
      FBest[i] := ini.ReadInteger('Progress', 'Best' + IntToStr(i), 0);
      FStars[i] := ini.ReadInteger('Progress', 'Stars' + IntToStr(i), 0);
    end;
    MusicVolume := ini.ReadInteger('Options', 'Music', 80) / 100;
    SfxVolume := ini.ReadInteger('Options', 'Sfx', 90) / 100;
    Fullscreen := ini.ReadBool('Options', 'Fullscreen', False);
    LightMode := EnsureRange(ini.ReadInteger('Options', 'LightFx', 0), 0, 3);
    LightMode := LK_PRISM;
    FPower := Max(0, InvToFloat(ini.ReadString('Progress', 'GratingPower', '0'), 0));
    AmbientLight := ini.ReadBool('Options', 'AmbientLight', True);
  finally
    ini.Free;
  end;
end;

procedure TWaveGame.SaveProgress;
var
  ini: TIniFile;
  i: Integer;
begin
  if (FIniFile = '') or (SimMode <> smNone) or FShow then Exit;
  try
    ini := TIniFile.Create(FIniFile);
    try
      ini.WriteInteger('Progress', 'Unlocked', FUnlocked);
      for i := 0 to High(FBest) do
      begin
        ini.WriteInteger('Progress', 'Best' + IntToStr(i), FBest[i]);
        ini.WriteInteger('Progress', 'Stars' + IntToStr(i), FStars[i]);
      end;
      ini.WriteInteger('Options', 'Music', Round(MusicVolume * 100));
      ini.WriteInteger('Options', 'Sfx', Round(SfxVolume * 100));
      ini.WriteBool('Options', 'Fullscreen', Fullscreen);
      ini.WriteInteger('Options', 'LightFx', LightMode);
      ini.WriteBool('Options', 'AmbientLight', AmbientLight);
      ini.WriteString('Progress', 'GratingPower', FloatToInv(FPower + FCharge, 2));
    finally
      ini.Free;
    end;
  except
    { read-only folder }
  end;
end;

procedure TWaveGame.ResetProgress;
var
  i: Integer;
begin
  FUnlocked := 1;
  for i := 0 to High(FBest) do begin FBest[i] := 0; FStars[i] := 0; end;
  SaveProgress;
  BuildMenu;
end;

{ ---------------- helpers ---------------- }

function TWaveGame.Lv: TLevelDef;
begin
  if (FLevel >= 0) and (FLevel <= High(FData.Levels)) then Result := FData.Levels[FLevel]
  else Result := DefaultLevel;
end;

function TWaveGame.ObjOk(I: Integer): Boolean;
begin
  Result := (I >= 0) and (I <= High(FData.Objects));
end;

function TWaveGame.Fx(AId: TScreenId): TScreenFx;
begin
  Result := FData.Screens[AId];
end;

function TWaveGame.ScreenFor(AState: TGameState): TScreenId;
begin
  case AState of
    gsMenu: Result := scMain;
    gsLevels: Result := scLevels;
    gsOptions: Result := scOptions;
    gsLight: Result := scLight;
    gsReady: Result := scReady;
    gsPaused: Result := scPause;
    gsComplete: Result := scComplete;
    gsGameOver: Result := scGameOver;
  else
    Result := scHud;
  end;
end;

function TWaveGame.StateName: string;
const
  N: array[TGameState] of string = ('Menu', 'Levels', 'Options', 'Light lab', 'Ready', 'Playing', 'Paused', 'Complete', 'GameOver');
begin
  Result := N[State];
end;

procedure TWaveGame.ParseMix(const S: string; out M: TMix);
var
  sl: TStringList;
  i, p, idx: Integer;
  name: string;
  w: Single;
begin
  M := nil;
  sl := TStringList.Create;
  try
    sl.Delimiter := ' ';
    sl.StrictDelimiter := False;
    sl.DelimitedText := StringReplace(S, ',', ' ', [rfReplaceAll]);
    for i := 0 to sl.Count - 1 do
    begin
      p := Pos(':', sl[i]);
      if p > 0 then
      begin
        name := Copy(sl[i], 1, p - 1);
        w := InvToFloat(Copy(sl[i], p + 1, 20), 1);
      end
      else
      begin
        name := sl[i];
        w := 1;
      end;
      idx := FData.FindObject(name);
      if (idx >= 0) and (w > 0) then
      begin
        SetLength(M, Length(M) + 1);
        M[High(M)].Obj := idx;
        M[High(M)].Weight := w;
      end;
    end;
  finally
    sl.Free;
  end;
end;

function TWaveGame.PickMix(const M: TMix): Integer;
var
  total, r: Single;
  i: Integer;
begin
  Result := -1;
  if Length(M) = 0 then Exit;
  total := 0;
  for i := 0 to High(M) do total := total + M[i].Weight;
  r := Random * total;
  for i := 0 to High(M) do
  begin
    r := r - M[i].Weight;
    if r <= 0 then Exit(M[i].Obj);
  end;
  Result := M[High(M)].Obj;
end;

procedure TWaveGame.Snd(const AName: string; AX: Single; AVol: Single; APitch: Single);
var
  pan: Single;
begin
  if (not SoundOn) or (Audio = nil) or (AName = '') then Exit;
  if AX < 0 then pan := 0 else pan := (AX / Max(1, FieldW) * 2 - 1) * 0.6;
  Audio.PlaySfx(AName, AVol, pan, APitch);
end;

procedure TWaveGame.AddEntity(ADef: Integer; AX, AY: Single; APhase: Single);
begin
  if not ObjOk(ADef) then Exit;
  if FEntCount >= Length(FEnt) then SetLength(FEnt, Length(FEnt) * 2);
  FEnt[FEntCount] := Default(TEntity);
  FEnt[FEntCount].Def := ADef;
  FEnt[FEntCount].X := AX; FEnt[FEntCount].BX := AX;
  FEnt[FEntCount].Y := AY; FEnt[FEntCount].BY := AY;
  if APhase < 0 then FEnt[FEntCount].Phase := Random * 2 * Pi else FEnt[FEntCount].Phase := APhase;
  FEnt[FEntCount].R := FData.Objects[ADef].Radius;
  Inc(FEntCount);
end;

procedure TWaveGame.RemoveEntity(I: Integer);
begin
  Dec(FEntCount);
  FEnt[I] := FEnt[FEntCount];
end;

procedure TWaveGame.AddRing(AX, AY, ASpeed, AWidth, AStrength, ADecay: Single);
begin
  if (ASpeed <= 0) or (AStrength = 0) then Exit;
  if FRingCount >= Length(FRings) then
  begin
    Move(FRings[1], FRings[0], (FRingCount - 1) * SizeOf(TRingFx));
    Dec(FRingCount);
  end;
  FRings[FRingCount].X := AX; FRings[FRingCount].Y := AY; FRings[FRingCount].Age := 0;
  FRings[FRingCount].Speed := ASpeed; FRings[FRingCount].Width := AWidth;
  FRings[FRingCount].Strength := AStrength; FRings[FRingCount].Decay := ADecay;
  Inc(FRingCount);
end;

procedure TWaveGame.Burst(AX, AY: Single; ACount: Integer; ASpeed, ASize: Single; AMode: Integer; const ACol: TBGRAPixel);
var
  i: Integer;
  a, sp: Single;
begin
  for i := 1 to ACount do
  begin
    if FPartCount >= Length(FParts) then Exit;
    a := Random * 2 * Pi;
    sp := ASpeed * (0.3 + Random * 0.7);
    FParts[FPartCount].X := AX; FParts[FPartCount].Y := AY;
    FParts[FPartCount].VX := Cos(a) * sp; FParts[FPartCount].VY := Sin(a) * sp;
    FParts[FPartCount].MaxLife := 0.4 + Random * 0.6;
    FParts[FPartCount].Life := FParts[FPartCount].MaxLife;
    FParts[FPartCount].Size := ASize * (0.6 + Random * 0.8);
    FParts[FPartCount].Col := ColorForMode(AMode, ACol, FTime * 0.3 + Random * 0.6);
    Inc(FPartCount);
  end;
end;

procedure TWaveGame.Popup(const S: string; AX, AY: Single; const ACol: TBGRAPixel; ASize: Integer);
var
  i: Integer;
begin
  if FPopCount >= Length(FPops) then
  begin
    for i := 0 to FPopCount - 2 do FPops[i] := FPops[i + 1];
    Dec(FPopCount);
  end;
  FPops[FPopCount].Text := S;
  FPops[FPopCount].X := AX; FPops[FPopCount].Y := AY;
  FPops[FPopCount].MaxLife := 0.9; FPops[FPopCount].Life := 0.9;
  FPops[FPopCount].Col := ACol;
  FPops[FPopCount].Size := ASize;
  Inc(FPopCount);
end;

procedure TWaveGame.Banner(const S: string; const ACol: TBGRAPixel; ATime: Single);
begin
  FBanner := S;
  FBannerCol := ACol;
  FBannerTime := ATime;
end;

function TWaveGame.ComboIntensity: Single;
begin
  Result := EnsureRange((Combo - 1) / (MAX_COMBO - 1), 0, 1);
end;

function TWaveGame.ObjColor(const D: TObjDef; ATime, APhase: Single): TBGRAPixel;
begin
  Result := ColorForMode(D.ColorMode, D.Color1, ATime * 0.25 + APhase / (2 * Pi));
end;

{ ---------------- level flow ---------------- }

procedure TWaveGame.BeginLevel(AIndex: Integer);
var
  e: Integer;
begin
  FLevel := EnsureRange(AIndex, 0, Max(0, High(FData.Levels)));
  ParseMix(Lv.CollectMix, FCollectMix);
  ParseMix(Lv.HazardMix, FHazardMix);
  ParseMix(Lv.BonusMix, FBonusMix);
  FEntCount := 0;
  FRingCount := 0;
  FPartCount := 0;
  FPopCount := 0;
  FAccCollect := 0.5; FAccHazard := -1.5; FAccBonus := -3;
  for e := Low(FFx) to High(FFx) do FFx[e] := Default(TTimedFx);
  for e := 0 to High(FLightEv) do FLightEv[e].Life := 0;
  FBeam.SegCount := 0;
  CancelCharge;
  FShotActive := False;
  FPrismOn := False;
  FCutIn := 0;
  FAnime.Setup(Lv.Anime, FData.DataDir + 'anime' + PathDelim + Lv.AnimeImage);
  FAnime.SizeMul := Lv.AnimeScale / 0.72;
  FNewOn := False;
  Score := 0;
  Lives := Lv.Lives;
  Combo := 1;
  MaxCombo := 1;
  PlayTime := 0;
  Invuln := 1.0;
  ScrollSpeed := Lv.SpeedStart;
  FSlow := 1;
  FNewBest := False;
  FStarsEarned := 0;
  ShipX := FieldW / 2;
  ShipY := FieldH * 0.78;
  ShipVX := 0; ShipVY := 0;
  TargetX := ShipX; TargetY := ShipY;
  FSuspended := False;
  FSimObj := -1;
  if Assigned(Audio) and SoundOn then
  begin
    Audio.Lock;
    try
      Audio.Music.SeekSection(Lv.MusicSection);
    finally
      Audio.Unlock;
    end;
  end;
  AddRing(ShipX, ShipY, 700, 40, 0.9, 1.4);
end;

procedure TWaveGame.StartLevel(AIndex: Integer);
begin
  SimMode := smNone;
  Autopilot := False;
  Invincible := False;
  BeginLevel(AIndex);
  FReadyT := 2.4;
  FReadyShown := -1;
  EnterState(gsReady);
end;

procedure TWaveGame.GoMenu;
begin
  EnterState(gsMenu);
end;

procedure TWaveGame.EnterState(AState: TGameState);
begin
  if AState <> gsPlaying then CancelCharge;
  State := AState;
  FSel := 0;
  if AState = gsLevels then FSel := EnsureRange(FLevelSel, 0, Max(0, High(FData.Levels)));
  BuildMenu;
  while (FSel < High(FItems)) and not FItems[FSel].Enabled do Inc(FSel);
end;

procedure TWaveGame.LevelComplete;
var
  l: TLevelDef;
begin
  l := Lv;
  FStarsEarned := 0;
  if Score >= l.Star1 then FStarsEarned := 1;
  if Score >= l.Star2 then FStarsEarned := 2;
  if Score >= l.Star3 then FStarsEarned := 3;
  if (FLevel <= High(FBest)) and not FShow then
  begin
    if Score > FBest[FLevel] then begin FBest[FLevel] := Score; FNewBest := True; end;
    FStars[FLevel] := Max(FStars[FLevel], FStarsEarned);
  end;
  if not FShow then FUnlocked := Max(FUnlocked, Min(Length(FData.Levels), FLevel + 2));
  if FShow then
  begin
    FShowTotal := FShowTotal + Score;
    Inc(FShowCleared);
    FShowLives := Min(6, Lives + 1);        { a cleared level gives the bot one life back }
    FShowTimer := 0;
  end;
  SaveProgress;
  Snd('complete');
  FSweep := 1;
  AddRing(ShipX, ShipY, 900, 80, 1.0, 0.9);
  Burst(ShipX, ShipY, 120, 700, 3, CM_RAINBOW, BGRAWhite);
  FMenuPhase := 0;
  EnterState(gsComplete);
end;

procedure TWaveGame.GameOver;
begin
  if (FLevel <= High(FBest)) and (Score > FBest[FLevel]) and not FShow then
  begin
    FBest[FLevel] := Score;
    FNewBest := True;
  end;
  if FShow then
  begin
    FShowTotal := FShowTotal + Score;
    FShowTimer := 0;
  end;
  SaveProgress;
  Snd('gameover');
  AddRing(ShipX, ShipY, 500, 70, -1.6, 0.8);
  Burst(ShipX, ShipY, 120, 700, 3, CM_RAINBOW, BGRAWhite);
  FSuspended := False;
  EnterState(gsGameOver);
end;

procedure TWaveGame.Hit(AFrom: Integer);
var
  d: TObjDef;
begin
  d := FData.Objects[FEnt[AFrom].Def];
  AddRing(FEnt[AFrom].X, FEnt[AFrom].Y, d.RingSpeed, d.RingWidth, d.RingStrength, d.RingDecay);
  Burst(ShipX, ShipY, Max(10, d.Particles * 2), 500, d.ParticleSize, d.ColorMode, ObjColor(d, FTime, 0));
  Shake := Max(Shake, d.Shake);
  FFlash := Max(FFlash, d.Flash);
  RemoveEntity(AFrom);
  if FFx[EF_SHIELD].T > 0 then
  begin
    Snd('block', ShipX);
    Popup('BLOCKED', ShipX, ShipY - 40, BGRA(120, 230, 255), 26);
    Exit;
  end;
  Snd(d.Sfx, ShipX, 1, d.SfxPitch);
  Combo := 1;
  Invuln := 2.0;
  AddRing(ShipX, ShipY, 650, 55, -1.3, 1.3);
  if Invincible then Exit;
  Dec(Lives);
  if Lives <= 0 then GameOver;
end;

procedure TWaveGame.ClearHazards(AScoreEach: Integer);
var
  j: Integer;
  d: TObjDef;
begin
  j := FEntCount - 1;
  while j >= 0 do
  begin
    if not ObjOk(FEnt[j].Def) then begin Dec(j); Continue; end;
    d := FData.Objects[FEnt[j].Def];
    if d.Role = RL_HAZARD then
    begin
      Inc(Score, AScoreEach);
      AddRing(FEnt[j].X, FEnt[j].Y, 400, 30, 0.8, 2.0);
      Burst(FEnt[j].X, FEnt[j].Y, 18, 300, 3, d.ColorMode, ObjColor(d, FTime, FEnt[j].Phase));
      RemoveEntity(j);
    end;
    Dec(j);
  end;
end;

procedure TWaveGame.ApplyEffect(I: Integer);
var
  d: TObjDef;
  pts, mult, oldCombo: Integer;
  x, y: Single;
  c: TBGRAPixel;
begin
  d := FData.Objects[FEnt[I].Def];
  x := FEnt[I].X; y := FEnt[I].Y;
  c := ObjColor(d, FTime, FEnt[I].Phase);
  oldCombo := Combo;
  RemoveEntity(I);
  if d.Role = RL_COLLECT then
  begin
    Combo := Min(MAX_COMBO, Combo + 1);
    MaxCombo := Max(MaxCombo, Combo);
  end;
  if FFx[EF_FEVER].T > 0 then Combo := MAX_COMBO;
  mult := 1;
  if (FFx[EF_DOUBLE].T > 0) and ObjOk(FFx[EF_DOUBLE].Def) then mult := Max(1, Round(FData.Objects[FFx[EF_DOUBLE].Def].Power));
  if d.Role = RL_COLLECT then pts := d.Score * Combo * mult else pts := d.Score * mult;

  case d.Effect of
    EF_CLEAR: ClearHazards(25);
    EF_NOVA: ClearHazards(40);
    EF_LIFE: Lives := Min(6, Lives + 1);
    EF_GRATING:
      begin
        FPower := FPower + Max(0.1, d.Power);
        if FPower < 1.05 then Banner('HOLD LEFT MOUSE TO CHARGE', IriPaletteColor(3, FTime * 0.2, 1), 2.2);
      end;
    EF_SHIELD, EF_MAGNET, EF_SLOWMO, EF_DOUBLE, EF_FEVER, EF_BEAM, EF_DIAMOND:
      begin
        FFx[d.Effect].T := d.Duration;
        FFx[d.Effect].Dur := Max(0.1, d.Duration);
        FFx[d.Effect].Def := FData.FindObject(d.Name);
        if d.Effect = EF_DIAMOND then
        begin
          FDiaX := x; FDiaY := y;
        end;
        if (d.Effect = EF_BEAM) and (LightMode = LK_PRISM) then
        begin
          FFx[EF_BEAM].T := Max(10, d.Duration * 2);
          FFx[EF_BEAM].Dur := FFx[EF_BEAM].T;
          if not FPrismOn then
          begin
            FPrismX := ShipX; FPrismY := ShipY - 220;
            FPrismPhi := Pi / 2;
          end;
        end;
        if d.Effect = EF_FEVER then
        begin
          Combo := MAX_COMBO;
          MaxCombo := MAX_COMBO;
        end;
      end;
  end;
  Inc(Score, pts);
  if pts > 0 then Popup('+' + IntToStr(pts), x, y - 20, c, IfThen(pts >= 100, 34, 26));
  if d.Role = RL_BONUS then
  begin
    Banner(d.Caption, c);
    CutIn(d.Caption + '!');
    AddLightEvent(x, y);
  end;
  AddRing(x, y, d.RingSpeed, d.RingWidth, d.RingStrength, d.RingDecay);
  Burst(x, y, d.Particles, d.ParticleSpeed, d.ParticleSize, d.ColorMode, c);
  Shake := Max(Shake, d.Shake);
  FFlash := Max(FFlash, d.Flash);
  FSweep := Max(FSweep, d.MusicSweep);
  if (d.Role = RL_COLLECT) and (Combo >= 6) then Snd('collect_hi', x, 0.9, d.SfxPitch * (1 + (Combo - 6) * 0.04))
  else Snd(d.Sfx, x, 1, d.SfxPitch * (1 + (Combo - 1) * 0.03));
  NewtonCombo(oldCombo, Combo);
  if (Combo <> oldCombo) and (Combo in [3, 5, 7, 9]) then
  begin
    Snd('combo');
    Banner('COMBO x' + IntToStr(Combo), HueToColor(FTime * 0.5));
    CutIn('COMBO x' + IntToStr(Combo) + '!');
    AddLightEvent(ShipX, ShipY - 200);
    FSweep := Max(FSweep, 0.5 + Combo * 0.05);
    AddRing(ShipX, ShipY, 900, 50, 0.5 + Combo * 0.05, 1.4);
  end;
end;

procedure TWaveGame.Collide(I: Integer);
var
  d: TObjDef;
  dist: Single;
begin
  d := FData.Objects[FEnt[I].Def];
  dist := Sqrt(Sqr(FEnt[I].X - ShipX) + Sqr(FEnt[I].Y - ShipY));
  if d.Role = RL_HAZARD then
  begin
    if (dist < SHIP_R + FEnt[I].R * 0.8) and ((Invuln <= 0) or (FFx[EF_SHIELD].T > 0)) then Hit(I);
  end
  else if dist < SHIP_R + FEnt[I].R + 6 then
    ApplyEffect(I);
end;

procedure TWaveGame.SpawnFromMix(const M: TMix; ARole: Integer);
var
  o, i, n: Integer;
  x: Single;
  d: TObjDef;
begin
  o := PickMix(M);
  if not ObjOk(o) then Exit;
  d := FData.Objects[o];
  x := 50 + Random * (FieldW - 100);
  if (ARole = RL_COLLECT) and (Random < Lv.ChainChance) then
  begin
    n := 4 + Random(3);
    x := 80 + Random * (FieldW - 160);
    for i := 0 to n - 1 do
      AddEntity(o, EnsureRange(x + Sin(i * 0.9) * 70, 40, FieldW - 40), -40 - i * 70, i * 0.5);
  end
  else if d.Motion = MO_ORBIT then
  begin
    AddEntity(o, x, -70, 0);
    AddEntity(o, x, -70, Pi);
  end
  else
    AddEntity(o, x, -60);
end;

procedure TWaveGame.Spawn(dt: Single);
var
  p, ramp: Single;
  l: TLevelDef;
begin
  l := Lv;
  if l.Duration > 0 then p := Min(1, PlayTime / l.Duration) else p := Min(1, PlayTime / 240);
  ramp := 1 + (l.RateRamp - 1) * p;
  FAccCollect := FAccCollect + l.CollectRate * ramp * dt * HardMul(1);
  FAccHazard := FAccHazard + l.HazardRate * ramp * dt * HardMul(2);
  FAccBonus := FAccBonus + l.BonusRate * (0.8 + 0.4 * p) * dt * HardMul(1);
  while FAccCollect >= 1 do begin FAccCollect := FAccCollect - 1; SpawnFromMix(FCollectMix, RL_COLLECT); end;
  while FAccHazard >= 1 do begin FAccHazard := FAccHazard - 1; SpawnFromMix(FHazardMix, RL_HAZARD); end;
  while FAccBonus >= 1 do begin FAccBonus := FAccBonus - 1; SpawnFromMix(FBonusMix, RL_BONUS); end;
end;

function TWaveGame.NearestTarget(out AX, AY: Single): Boolean;
var
  i: Integer;
  dd, best: Single;
  d: TObjDef;
begin
  Result := False;
  best := 1e9;
  AX := FieldW / 2; AY := FieldH * 0.75;
  for i := 0 to FEntCount - 1 do
  begin
    if not ObjOk(FEnt[i].Def) then Continue;
    d := FData.Objects[FEnt[i].Def];
    if (d.Role = RL_HAZARD) and (SimMode <> smObject) then Continue;
    if (FEnt[i].Y < 0) or (FEnt[i].Y > ShipY + 40) then Continue;
    dd := Sqr(FEnt[i].X - ShipX) + Sqr(FEnt[i].Y - ShipY) * 0.3;
    if d.Role = RL_BONUS then dd := dd * 0.5;
    if dd < best then
    begin
      best := dd;
      AX := FEnt[i].X; AY := FEnt[i].Y;
      Result := True;
    end;
  end;
end;

procedure TWaveGame.UpdateAutopilot;
var
  tx, ty, dx: Single;
  i: Integer;
begin
  UseMouse := True;
  if NearestTarget(tx, ty) then
  begin
    TargetX := tx;
    TargetY := Max(ty, FieldH * 0.45);
  end
  else
  begin
    TargetX := FieldW / 2 + Sin(FTime * 0.7) * FieldW * 0.25;
    TargetY := FieldH * 0.75;
  end;
  if SimMode = smObject then Exit;
  for i := 0 to FEntCount - 1 do
    if ObjOk(FEnt[i].Def) and (FData.Objects[FEnt[i].Def].Role = RL_HAZARD) then
      if (FEnt[i].Y > ShipY - 300) and (FEnt[i].Y < ShipY + 40) then
      begin
        dx := ShipX - FEnt[i].X;
        if Abs(dx) < FEnt[i].R + 70 then
          if dx >= 0 then TargetX := Min(FieldW - 30, FEnt[i].X + FEnt[i].R + 110)
          else TargetX := Max(30, FEnt[i].X - FEnt[i].R - 110);
      end;
end;

procedure TWaveGame.UpdatePlay(dt: Single);
var
  i, e: Integer;
  ax, ay, wdt, p, dx, dy, dist, pull, vy, ox, oy: Single;
  l: TLevelDef;
  d: TObjDef;
begin
  l := Lv;
  if (FFx[EF_SLOWMO].T > 0) and ObjOk(FFx[EF_SLOWMO].Def) then
    FSlow := FSlow + (EnsureRange(FData.Objects[FFx[EF_SLOWMO].Def].Power, 0.1, 2) - FSlow) * Min(1, dt * 4)
  else
    FSlow := FSlow + (1 - FSlow) * Min(1, dt * 3);
  wdt := dt * FSlow;
  PlayTime := PlayTime + wdt;
  if l.Duration > 0 then p := Min(1, PlayTime / l.Duration) else p := Min(1, PlayTime / 240);
  ScrollSpeed := (l.SpeedStart + (l.SpeedEnd - l.SpeedStart) * p) * HardMul(0);
  ScrollY := ScrollY + ScrollSpeed * wdt;
  Phase := Phase + wdt * (0.1 + ScrollSpeed / 3000);

  { ship }
  if FShow then UpdateBot(dt)
  else if Autopilot then UpdateAutopilot;
  if (KeyLeft or KeyRight or KeyUp or KeyDown) and not FShow then UseMouse := False;
  if UseMouse then
  begin
    ShipVX := (TargetX - ShipX) * Min(1, dt * 14) / Max(dt, 1e-4);
    ShipVY := (TargetY - ShipY) * Min(1, dt * 14) / Max(dt, 1e-4);
  end
  else
  begin
    ax := 0; ay := 0;
    if KeyLeft then ax := ax - 1;
    if KeyRight then ax := ax + 1;
    if KeyUp then ay := ay - 1;
    if KeyDown then ay := ay + 1;
    ShipVX := (ShipVX + ax * 5200 * dt) * Power(0.0008, dt);
    ShipVY := (ShipVY + ay * 5200 * dt) * Power(0.0008, dt);
    ShipVX := EnsureRange(ShipVX, -950, 950);
    ShipVY := EnsureRange(ShipVY, -950, 950);
  end;
  ShipX := EnsureRange(ShipX + ShipVX * dt, 24, FieldW - 24);
  ShipY := EnsureRange(ShipY + ShipVY * dt, FieldH * 0.22, FieldH - 50);
  if Invuln > 0 then Invuln := Invuln - dt;

  { timed effects (real time) }
  for e := Low(FFx) to High(FFx) do
    if FFx[e].T > 0 then
    begin
      FFx[e].T := FFx[e].T - dt;
      if (FFx[e].T <= 0) and ObjOk(FFx[e].Def) then
        Popup(FData.Objects[FFx[e].Def].Caption + ' OFF', ShipX, ShipY - 50, BGRA(170, 170, 180), 20);
    end;
  if FFx[EF_FEVER].T > 0 then Combo := MAX_COMBO;

  { spawning }
  if SimMode = smObject then
  begin
    FSimTimer := FSimTimer - wdt;
    if (FSimTimer <= 0) and ObjOk(FSimObj) then
    begin
      FSimTimer := 1.1;
      if FData.Objects[FSimObj].Motion = MO_ORBIT then
      begin
        dx := FieldW / 2 + (Random - 0.5) * 200;
        AddEntity(FSimObj, dx, -70, 0);
        AddEntity(FSimObj, dx, -70, Pi);
      end
      else
        AddEntity(FSimObj, FieldW / 2 + (Random - 0.5) * 240, -60);
    end;
  end
  else
    Spawn(wdt);

  { entities }
  i := FEntCount - 1;
  while i >= 0 do
  begin
    if i >= FEntCount then begin i := FEntCount - 1; Continue; end;
    if not ObjOk(FEnt[i].Def) then begin RemoveEntity(i); Dec(i); Continue; end;
    d := FData.Objects[FEnt[i].Def];
    FEnt[i].Age := FEnt[i].Age + wdt;
    ox := FEnt[i].X; oy := FEnt[i].Y;
    FEnt[i].Angle := FEnt[i].Angle + d.Spin * wdt;
    if FEnt[i].Pulled then
    begin
      dx := ShipX - FEnt[i].X; dy := ShipY - FEnt[i].Y;
      dist := Sqrt(dx * dx + dy * dy);
      FEnt[i].PullV := Min(2200, FEnt[i].PullV + 3200 * dt);
      if dist > 1 then
      begin
        pull := Min(dist, FEnt[i].PullV * dt);
        FEnt[i].X := FEnt[i].X + dx / dist * pull;
        FEnt[i].Y := FEnt[i].Y + dy / dist * pull;
      end;
      FEnt[i].BX := FEnt[i].X; FEnt[i].BY := FEnt[i].Y;
    end
    else
    begin
    vy := ScrollSpeed * d.Speed;
    FEnt[i].BY := FEnt[i].BY + vy * wdt;
    case d.Motion of
      MO_SINE, MO_DRIFT:
        begin
          FEnt[i].X := FEnt[i].BX + Sin(FEnt[i].Age * d.MotionFreq + FEnt[i].Phase) * d.MotionAmp;
          FEnt[i].Y := FEnt[i].BY;
        end;
      MO_ZIGZAG:
        begin
          p := Frac(FEnt[i].Age * d.MotionFreq * 0.5 + FEnt[i].Phase / (2 * Pi));
          FEnt[i].X := EnsureRange(FEnt[i].BX + (Abs(p * 4 - 2) - 1) * d.MotionAmp, 20, FieldW - 20);
          FEnt[i].Y := FEnt[i].BY;
        end;
      MO_HOMING:
        begin
          if FEnt[i].Y < ShipY then
          begin
            dx := ShipX - FEnt[i].BX;
            FEnt[i].BX := FEnt[i].BX + EnsureRange(dx, -d.Power * wdt, d.Power * wdt);
          end;
          FEnt[i].X := FEnt[i].BX;
          FEnt[i].Y := FEnt[i].BY;
        end;
      MO_ORBIT:
        begin
          FEnt[i].X := FEnt[i].BX + Cos(FEnt[i].Age * d.MotionFreq + FEnt[i].Phase) * d.MotionAmp;
          FEnt[i].Y := FEnt[i].BY + Sin(FEnt[i].Age * d.MotionFreq + FEnt[i].Phase) * d.MotionAmp;
        end;
    else
      begin
        FEnt[i].X := FEnt[i].BX;
        FEnt[i].Y := FEnt[i].BY;
      end;
    end;
    end;
    if (FFx[EF_MAGNET].T > 0) and (d.Role = RL_COLLECT) and ObjOk(FFx[EF_MAGNET].Def) then
    begin
      dx := ShipX - FEnt[i].X; dy := ShipY - FEnt[i].Y;
      dist := Sqrt(dx * dx + dy * dy);
      if (dist < FData.Objects[FFx[EF_MAGNET].Def].Power) and (dist > 1) then
      begin
        pull := Min(0.5, 900 * wdt / dist);
        FEnt[i].BX := FEnt[i].BX + dx * pull;
        FEnt[i].BY := FEnt[i].BY + dy * pull;
        FEnt[i].X := FEnt[i].X + dx * pull;
        FEnt[i].Y := FEnt[i].Y + dy * pull;
      end;
    end;
    if wdt > 1e-5 then
    begin
      FEnt[i].VX := (FEnt[i].X - ox) / wdt;
      FEnt[i].VY := (FEnt[i].Y - oy) / wdt;
    end;
    if FEnt[i].Y > FieldH + 140 then
    begin
      if (d.Role = RL_COLLECT) and (SimMode <> smObject) then Combo := Max(1, Combo - 2);
      RemoveEntity(i);
    end
    else
    begin
      Collide(i);
      if State <> gsPlaying then Break;
    end;
    Dec(i);
  end;

  UpdateBeam;
  UpdateGrating(dt);
  UpdatePrism(dt);
  UpdateDiamond(dt);
  UpdateNewton(dt);

  if (State = gsPlaying) and (l.Duration > 0) and (PlayTime >= l.Duration) then
  begin
    if SimMode = smNone then LevelComplete
    else if SimMode = smLevel then BeginLevel(FLevel);   { simulation loops the level }
  end;
end;

procedure TWaveGame.UpdateFx(dt, AScroll: Single);
var
  i: Integer;
begin
  FTrailTimer := FTrailTimer + dt;
  if FTrailTimer > 0.016 then
  begin
    FTrailTimer := 0;
    Move(FTrail[0], FTrail[1], (Length(FTrail) - 1) * SizeOf(TPointF));
    FTrail[0] := PointF(ShipX, ShipY);
  end;
  for i := 0 to High(FTrail) do
    FTrail[i].y := FTrail[i].y + AScroll * dt;

  i := FRingCount - 1;
  while i >= 0 do
  begin
    FRings[i].Age := FRings[i].Age + dt;
    FRings[i].Y := FRings[i].Y + AScroll * dt * 0.5;
    if Abs(FRings[i].Strength) * Exp(-FRings[i].Age * FRings[i].Decay) < 0.02 then
    begin
      Dec(FRingCount);
      FRings[i] := FRings[FRingCount];
    end;
    Dec(i);
  end;

  i := FPartCount - 1;
  while i >= 0 do
  begin
    FParts[i].Life := FParts[i].Life - dt;
    FParts[i].X := FParts[i].X + FParts[i].VX * dt;
    FParts[i].Y := FParts[i].Y + (FParts[i].VY + AScroll * 0.6) * dt;
    FParts[i].VX := FParts[i].VX * Power(0.05, dt);
    FParts[i].VY := FParts[i].VY * Power(0.05, dt);
    if FParts[i].Life <= 0 then
    begin
      Dec(FPartCount);
      FParts[i] := FParts[FPartCount];
    end;
    Dec(i);
  end;

  i := FPopCount - 1;
  while i >= 0 do
  begin
    FPops[i].Life := FPops[i].Life - dt;
    FPops[i].Y := FPops[i].Y - 60 * dt;
    if FPops[i].Life <= 0 then
    begin
      Dec(FPopCount);
      FPops[i] := FPops[FPopCount];
    end;
    Dec(i);
  end;

  for i := 0 to High(FAmbient) do
  begin
    FAmbient[i].X := FAmbient[i].X + FAmbient[i].VX * dt;
    FAmbient[i].Y := FAmbient[i].Y + FAmbient[i].VY * dt;
    if FAmbient[i].Y < -10 then
    begin
      FAmbient[i].Y := FieldH + 10;
      FAmbient[i].X := Random * FieldW;
    end;
  end;

  for i := 0 to High(FLightEv) do
    if FLightEv[i].Life > 0 then
    begin
      FLightEv[i].Age := FLightEv[i].Age + dt;
      FLightEv[i].Y := FLightEv[i].Y + AScroll * dt * 0.3;
      if FLightEv[i].Age >= FLightEv[i].Life then FLightEv[i].Life := 0;
    end;
  if Shake > 0 then Shake := Max(0, Shake - dt * 2.5);
  if FFlash > 0 then FFlash := Max(0, FFlash - dt * 2);
  if FBannerTime > 0 then FBannerTime := FBannerTime - dt;
  if FSweep > 0 then FSweep := Max(0, FSweep - dt * 0.9);
  if FCutIn > 0 then FCutIn := Max(0, FCutIn - dt);
end;

procedure TWaveGame.UpdateMusic(dt: Single);
var
  inten, fever, muffle, ts: Single;
begin
  if (Audio = nil) or not SoundOn then Exit;
  case State of
    gsPlaying, gsReady: inten := ComboIntensity * 0.85 + Lv.Difficulty * 0.04;
    gsPaused: inten := ComboIntensity * 0.5;
    gsComplete: inten := 0.7;
  else
    inten := 0.05;
  end;
  if FFx[EF_FEVER].T > 0 then fever := 1 else fever := 0;
  if State = gsPaused then muffle := 1
  else if State = gsGameOver then muffle := 0.45
  else muffle := 0;
  if (FFx[EF_SLOWMO].T > 0) and (State = gsPlaying) then ts := 0.82 else ts := 1;
  FMuffle := FMuffle + (muffle - FMuffle) * Min(1, dt * 5);
  Audio.Music.Intensity := Audio.Music.Intensity + (inten - Audio.Music.Intensity) * Min(1, dt * 2);
  Audio.Music.Fever := Audio.Music.Fever + (fever - Audio.Music.Fever) * Min(1, dt * 4);
  Audio.Music.Sweep := FSweep;
  Audio.Music.Muffle := FMuffle;
  Audio.Music.TimeScale := Audio.Music.TimeScale + (ts - Audio.Music.TimeScale) * Min(1, dt * 3);
  Audio.MusicVolume := MusicVolume;
  Audio.SfxVolume := SfxVolume;
end;

procedure TWaveGame.Update(dt: Single);
var
  iriTarget, sc: Single;
  n: Integer;
begin
  FTime := FTime + dt;
  FMenuPhase := FMenuPhase + dt;
  sc := 0;
  case State of
    gsMenu, gsLevels, gsOptions, gsLight:
      begin
        sc := Fx(ScreenFor(State)).BgSpeed;
        FMenuScroll := FMenuScroll + sc * dt;
        Phase := Phase + dt * 0.12;
      end;
    gsReady:
      begin
        FReadyT := FReadyT - dt;
        n := Ceil(FReadyT / 0.6);
        if n <> FReadyShown then
        begin
          FReadyShown := n;
          if n >= 1 then Snd('ready', -1, 0.8, 1 + (4 - n) * 0.08) else Snd('menu_select');
        end;
        sc := ScrollSpeed * 0.3;
        ScrollY := ScrollY + sc * dt;
        Phase := Phase + dt * 0.08;
        if FShow then UpdateBot(dt)
        else if Autopilot then UpdateAutopilot;
        if UseMouse then
        begin
          ShipX := ShipX + (EnsureRange(TargetX, 24, FieldW - 24) - ShipX) * Min(1, dt * 10);
          ShipY := ShipY + (EnsureRange(TargetY, FieldH * 0.22, FieldH - 50) - ShipY) * Min(1, dt * 10);
        end;
        if FReadyT <= 0 then
        begin
          if SimMode = smScreen then begin FReadyT := 2.4; FReadyShown := -1; end
          else EnterState(gsPlaying);
        end;
      end;
    gsPlaying:
      begin
        UpdatePlay(dt);
        sc := ScrollSpeed * FSlow;
      end;
    gsComplete, gsGameOver:
      begin
        ScrollSpeed := ScrollSpeed + (120 - ScrollSpeed) * Min(1, dt * 2);
        sc := ScrollSpeed;
        ScrollY := ScrollY + sc * dt;
        Phase := Phase + dt * 0.1;
      end;
  end;
  if State <> gsPaused then UpdateFx(dt, sc);
  if (Lv.Anime > 0) and (State in [gsReady, gsPlaying, gsComplete, gsGameOver]) then
    FAnime.Step(dt, FieldW, FieldH);
  if FShow then UpdateShow(dt);

  case State of
    gsPlaying, gsReady, gsPaused: iriTarget := Min(1, Lv.IriBase + ComboIntensity * (1 - Lv.IriBase));
    gsComplete: iriTarget := 1;
    gsGameOver: iriTarget := 0;
  else
    iriTarget := Fx(ScreenFor(State)).BgIri;
  end;
  if FFx[EF_FEVER].T > 0 then iriTarget := 1;
  FIri := FIri + (iriTarget - FIri) * Min(1, dt * 3);
  UpdateMusic(dt);
end;

{ ---------------- engine bridge ---------------- }

procedure TWaveGame.ApplyToEngine(E: TWaveEngine);
var
  img: TBGRABitmap;
  hh, ww: Single;
  i, n: Integer;
  age: Single;
  l: TLevelDef;
  f: TScreenFx;
  d: TObjDef;
  inGame: Boolean;
begin
  inGame := State in [gsReady, gsPlaying, gsPaused, gsComplete, gsGameOver];
  if inGame then
  begin
    l := Lv;
    Config := PresetConfig(EnsureRange(l.MeshPreset, 0, High(PresetNames)));
    if l.Lines > 0 then Config.Values[wpLines] := l.Lines;
    if l.Amplitude > 0 then Config.Values[wpAmplitude] := l.Amplitude;
    Config.BgColor := l.BgColor;
    Config.DotColor := l.DotColor;
    Config.Values[wpVignette] := l.Vignette;
    if l.IriPalette >= 5 then Config.Values[wpIriAmount] := 0
    else
    begin
      Config.Values[wpIriAmount] := FIri;
      Config.Values[wpIriPalette] := l.IriPalette;
    end;
    Config.Values[wpIriSpeed] := 1 + Combo * 0.6;
    E.ScrollY := ScrollY;
    { anime character drawn by the dots, with a slow camera drift }
    E.Image := nil;
    if l.Anime > 0 then
    begin
      FExcite := FExcite + (Max(ComboIntensity, Min(1, FCutIn)) - FExcite) * 0.1;
      FAnime.Excited := FExcite;
      { the crisp character is drawn by DrawWorld; the dots echo layer 0
        (and take over completely when a Reveal cut dissolves into the mesh) }
      img := FAnime.L[0].Bmp;
      if (img <> nil) and FAnime.L[0].Visible and (FAnime.EchoMix > 0.01) and (Abs(FAnime.L[0].Rot) < 0.3) and (AnimeDbg and 8 = 0) then
      begin
        hh := FAnime.L[0].H;
        ww := FAnime.L[0].W;
        E.Image := img;
        E.ImageW := ww; E.ImageH := hh;
        E.ImageX := FAnime.L[0].CX - ww / 2;
        E.ImageY := FAnime.L[0].CY - hh / 2;
        E.ImageMix := l.AnimeMix * FAnime.EchoMix;
        E.ImageBgDim := 0.45 * FAnime.EchoMix;
      end;
    end;
  end
  else
  begin
    f := Fx(ScreenFor(State));
    Config := PresetConfig(EnsureRange(f.BgPreset, 0, High(PresetNames)));
    Config.Values[wpIriAmount] := FIri;
    Config.Values[wpVignette] := Max(Config.Values[wpVignette], 0.35);
    E.ScrollY := FMenuScroll;
    E.Image := nil;
  end;
  Config.Values[wpDriftX] := 0.25;
  Config.Values[wpDriftY] := 0;
  Config.ShowFPS := False;

  SetLength(E.Wells, FEntCount + 2);
  n := 0;
  if inGame and (State <> gsGameOver) then
  begin
    E.Wells[n].X := ShipX; E.Wells[n].Y := ShipY; E.Wells[n].Radius := 55;
    E.Wells[n].Height := 0.55; E.Wells[n].Darken := -0.9;
    Inc(n);
    if FFx[EF_SHIELD].T > 0 then
    begin
      E.Wells[n].X := ShipX; E.Wells[n].Y := ShipY; E.Wells[n].Radius := 90;
      E.Wells[n].Height := 0.25; E.Wells[n].Darken := -0.6;
      Inc(n);
    end;
  end;
  if inGame then
    for i := 0 to FEntCount - 1 do
    begin
      if not ObjOk(FEnt[i].Def) then Continue;
      d := FData.Objects[FEnt[i].Def];
      if d.WellRadius <= 0 then Continue;
      E.Wells[n].X := FEnt[i].X; E.Wells[n].Y := FEnt[i].Y;
      E.Wells[n].Radius := d.WellRadius; E.Wells[n].Height := d.WellHeight; E.Wells[n].Darken := d.WellDarken;
      Inc(n);
    end;
  SetLength(E.Wells, n);

  SetLength(E.Rings, FRingCount);
  for i := 0 to FRingCount - 1 do
  begin
    age := FRings[i].Age;
    E.Rings[i].X := FRings[i].X;
    E.Rings[i].Y := FRings[i].Y;
    E.Rings[i].R := age * FRings[i].Speed;
    E.Rings[i].Width := FRings[i].Width;
    E.Rings[i].Strength := FRings[i].Strength * Exp(-age * FRings[i].Decay);
  end;
end;

function TWaveGame.PixelSize: Integer;
begin
  if (State in [gsReady, gsPlaying, gsPaused, gsComplete, gsGameOver]) and Lv.Pixel then
    Result := Max(2, Lv.PixelSize)
  else
    Result := 0;
end;

function TWaveGame.PosterizeLevels: Integer;
begin
  if PixelSize > 0 then Result := Lv.Posterize else Result := 0;
end;

procedure TWaveGame.SetField(ABmpW, ABmpH: Integer);
begin
  FieldH := REF_HEIGHT;
  FieldW := ABmpW / (ABmpH / REF_HEIGHT);
end;

{ ---------------- menus ---------------- }

procedure TWaveGame.BuildMenu;

  procedure Add(const ACaption: string; AId: Integer; AEnabled: Boolean = True; const AValue: string = '');
  begin
    SetLength(FItems, Length(FItems) + 1);
    FItems[High(FItems)].Caption := ACaption;
    FItems[High(FItems)].Id := AId;
    FItems[High(FItems)].Enabled := AEnabled;
    FItems[High(FItems)].Value := AValue;
  end;

var
  i: Integer;
begin
  FItems := nil;
  case State of
    gsMenu:
      begin
        if FSuspended then Add('CONTINUE', MI_CONTINUE);
        Add('PLAY', MI_PLAY);
        Add('ENDLESS', MI_ENDLESS);
        Add('WATCH BOT', MI_WATCH);
        Add('LIGHT LAB', MI_LIGHT);
        Add('OPTIONS', MI_OPTIONS);
        Add('QUIT', MI_QUIT);
      end;
    gsLevels:
      begin
        for i := 0 to High(FData.Levels) do
          Add(FData.Levels[i].Name, MI_LEVEL + i, (i < FUnlocked) or (SimMode <> smNone));
        Add('BACK', MI_BACK);
      end;
    gsOptions:
      begin
        Add('MUSIC', MI_MUSIC, True, IntToStr(Round(MusicVolume * 100)) + '%');
        Add('SOUND FX', MI_SFX, True, IntToStr(Round(SfxVolume * 100)) + '%');
        Add('FULLSCREEN', MI_FULL, True, BoolToStr(Fullscreen, 'ON', 'OFF'));
        Add('BEAM LIGHT', MI_BEAMFX, True, UpperCase(EnumName(LIGHT_KINDS, LightMode)));
        Add('AMBIENT LIGHT', MI_AMBIENT, True, BoolToStr(AmbientLight, 'ON', 'OFF'));
        Add('RESET PROGRESS', MI_RESETPROG);
        Add('BACK', MI_BACK);
      end;
    gsLight:
      begin
        for i := 0 to 3 do Add(UpperCase(EnumName(LIGHT_KINDS, i)), MI_LKIND + i, i = LK_PRISM);
        Add('AMBIENT LIGHT', MI_AMBIENT, True, BoolToStr(AmbientLight, 'ON', 'OFF'));
        Add('BACK', MI_BACK);
      end;
    gsPaused:
      begin
        Add('RESUME', MI_RESUME);
        if not FShow then Add('RESTART LEVEL', MI_RESTART);
        Add('MAIN MENU', MI_MAINMENU);
      end;
    gsGameOver:
      if not FShow then
      begin
        Add('RETRY', MI_RETRY);
        Add('LEVEL SELECT', MI_LEVELSEL);
        Add('MAIN MENU', MI_MAINMENU);
      end;
    gsComplete:
      if not FShow then
      begin
        Add('NEXT LEVEL', MI_NEXT, FLevel < High(FData.Levels));
        Add('RETRY', MI_RETRY);
        Add('MAIN MENU', MI_MAINMENU);
      end;
  end;
  if FSel > High(FItems) then FSel := Max(0, High(FItems));
end;

procedure TWaveGame.MenuActivate(AId: Integer; ADir: Integer);
var
  st: Integer;
begin
  case AId of
    MI_CONTINUE:
      begin
        FReadyT := 1.8;
        FReadyShown := -1;
        EnterState(gsReady);
      end;
    MI_PLAY:
      begin
        FLevelSel := Max(0, Min(FUnlocked - 1, High(FData.Levels)));
        EnterState(gsLevels);
      end;
    MI_ENDLESS: StartLevel(High(FData.Levels));
    MI_WATCH: StartShow;
    MI_OPTIONS: EnterState(gsOptions);
    MI_LIGHT:
      begin
        EnterState(gsLight);
        FSel := LightMode;
      end;
    MI_BEAMFX:
      begin
        if ADir = 0 then ADir := 1;
        LightMode := (LightMode + ADir + 4) mod 4;
        LightMode := LK_PRISM;
        st := FSel; BuildMenu; FSel := st;
        SaveProgress;
      end;
    MI_AMBIENT:
      begin
        AmbientLight := not AmbientLight;
        st := FSel; BuildMenu; FSel := st;
        SaveProgress;
      end;
    MI_QUIT: RequestQuit := True;
    MI_RESUME:
      begin
        FReadyT := 1.2;
        FReadyShown := -1;
        EnterState(gsReady);
      end;
    MI_RESTART, MI_RETRY: StartLevel(FLevel);
    MI_MAINMENU:
      begin
        if FShow then
        begin
          StopShow;
          Exit;
        end;
        FSuspended := (State = gsPaused) and (SimMode = smNone);
        if Assigned(Audio) and SoundOn and not FSuspended then
        begin
          Audio.Lock;
          try Audio.Music.SeekSection(0); finally Audio.Unlock; end;
        end;
        EnterState(gsMenu);
      end;
    MI_NEXT: StartLevel(Min(FLevel + 1, High(FData.Levels)));
    MI_LEVELSEL:
      begin
        FLevelSel := FLevel;
        EnterState(gsLevels);
      end;
    MI_BACK: EnterState(gsMenu);
    MI_MUSIC:
      begin
        if ADir = 0 then ADir := 1;
        MusicVolume := MusicVolume + ADir * 0.1;
        if MusicVolume > 1.001 then MusicVolume := 0;
        MusicVolume := EnsureRange(MusicVolume, 0, 1);
        st := FSel; BuildMenu; FSel := st;
        SaveProgress;
      end;
    MI_SFX:
      begin
        if ADir = 0 then ADir := 1;
        SfxVolume := SfxVolume + ADir * 0.1;
        if SfxVolume > 1.001 then SfxVolume := 0;
        SfxVolume := EnsureRange(SfxVolume, 0, 1);
        if Assigned(Audio) then Audio.SfxVolume := SfxVolume;
        st := FSel; BuildMenu; FSel := st;
        Snd('collect');
        SaveProgress;
      end;
    MI_FULL:
      begin
        Fullscreen := not Fullscreen;
        RequestFullscreen := True;
        st := FSel; BuildMenu; FSel := st;
        SaveProgress;
      end;
    MI_RESETPROG:
      begin
        ResetProgress;
        Banner('PROGRESS RESET', BGRA(255, 120, 120));
      end;
  else
    if AId = MI_LKIND + LK_PRISM then
    begin
      LightMode := AId - MI_LKIND;
      SaveProgress;
      Banner('BEAM LIGHT: ' + UpperCase(EnumName(LIGHT_KINDS, LightMode)), IriPaletteColor(3, FTime * 0.2, 1));
      Snd('beam', -1, 0.7);
    end
    else if AId >= MI_LEVEL then
    begin
      FLevelSel := AId - MI_LEVEL;
      StartLevel(FLevelSel);
    end;
  end;
end;

function TWaveGame.ItemAt(const P: TPointF): Integer;
var
  f: TScreenFx;
  i: Integer;
  y0, iy, hw: Single;
begin
  Result := -1;
  if Length(FItems) = 0 then Exit;
  f := Fx(ScreenFor(State));
  if State = gsLight then
  begin
    { four light bands, then the two menu rows }
    for i := 0 to 3 do
      if (P.y >= (0.1 + i * 0.19) * FieldH) and (P.y < (0.1 + (i + 1) * 0.19) * FieldH) then Exit(i);
    y0 := f.MenuY * FieldH;
    for i := 4 to High(FItems) do
    begin
      iy := y0 + (i - 4) * f.MenuSpacing;
      if (P.y >= iy - f.MenuSpacing * 0.2) and (P.y < iy + f.MenuSpacing * 0.8) then Exit(i);
    end;
    Exit;
  end;
  y0 := f.MenuY * FieldH;
  for i := 0 to High(FItems) do
  begin
    iy := y0 + i * f.MenuSpacing;
    if (P.y >= iy - f.MenuSpacing * 0.2) and (P.y < iy + f.MenuSpacing * 0.8) then
    begin
      { centred menus: only the text (plus a margin) is clickable; the level list uses the full row }
      if State <> gsLevels then
      begin
        hw := (Length(FItems[i].Caption) + Length(FItems[i].Value) + 6 * Ord(FItems[i].Value <> '')) *
          f.MenuSize * 0.33 + 50;
        if Abs(P.x - FieldW / 2) > hw then Exit(-1);
      end;
      Exit(i);
    end;
  end;
end;

function TWaveGame.CursorKind: Integer;
var
  it: Integer;
begin
  if (State in [gsPlaying, gsReady]) and not FShow then Exit(0);
  if FShow and (State <> gsPaused) then
  begin
    if ShowButtonAt(FMouseRef) >= 0 then Exit(2) else Exit(1);
  end;
  it := ItemAt(FMouseRef);
  if (it >= 0) and (it <= High(FItems)) and FItems[it].Enabled and not (FShow and (State <> gsPaused)) then
    Result := 2
  else
    Result := 1;
end;

procedure TWaveGame.MouseAt(AX, AY: Single; AW, AH: Integer);
var
  k: Single;
  it: Integer;
begin
  k := AH / REF_HEIGHT;
  FMouseRef := PointF(AX / k, AY / k);
  if FShow and (State <> gsPaused) then Exit;      { the bot has the controls }
  TargetX := FMouseRef.x;
  TargetY := FMouseRef.y;
  if State in [gsPlaying, gsReady] then
  begin
    UseMouse := True;
    Exit;
  end;
  it := ItemAt(FMouseRef);
  if (it >= 0) and (it <> FSel) and FItems[it].Enabled then
  begin
    FSel := it;
    Snd('menu_move', -1, 0.6);
  end;
end;

procedure TWaveGame.Click(AX, AY: Single; AW, AH: Integer);
var
  it: Integer;
begin
  if FShow and (State <> gsPaused) then
  begin
    { bot show: only the on-screen PAUSE / EXIT buttons react to clicks }
    MouseAt(AX, AY, AW, AH);
    case ShowButtonAt(FMouseRef) of
      0: Action(gaPause);
      1: begin Snd('menu_select'); StopShow; end;
    end;
    Exit;
  end;
  MouseAt(AX, AY, AW, AH);
  if State = gsPlaying then
  begin
    FireDown;
    Exit;
  end;
  if State = gsReady then Exit;
  it := ItemAt(FMouseRef);
  if (it >= 0) and FItems[it].Enabled then
  begin
    FSel := it;
    Snd('menu_select');
    { value items: left half of the row = decrease, right half = increase }
    if FItems[it].Id in [MI_MUSIC, MI_SFX, MI_BEAMFX] then
      MenuActivate(FItems[it].Id, IfThen(FMouseRef.x < FieldW / 2, -1, 1))
    else
      MenuActivate(FItems[it].Id, 0);
  end;
end;

procedure TWaveGame.Action(A: TGameAction);
var
  old: Integer;
begin
  if FShow and (State <> gsPaused) then
  begin
    { Esc / Enter / Backspace leave the show, P (or losing focus) pauses it }
    if A = gaPause then
    begin
      if State in [gsPlaying, gsReady] then
      begin
        EnterState(gsPaused);
        Snd('pause');
      end;
    end
    else if A in [gaBack, gaConfirm] then
      StopShow;
    Exit;
  end;
  if State = gsPlaying then
  begin
    if A in [gaPause, gaBack] then
    begin
      EnterState(gsPaused);
      Snd('pause');
    end;
    Exit;
  end;
  if State = gsReady then Exit;
  if Length(FItems) = 0 then Exit;
  old := FSel;
  case A of
    gaUp:
      repeat
        FSel := (FSel - 1 + Length(FItems)) mod Length(FItems);
      until FItems[FSel].Enabled or (FSel = old);
    gaDown:
      repeat
        FSel := (FSel + 1) mod Length(FItems);
      until FItems[FSel].Enabled or (FSel = old);
    gaLeft, gaRight:
      if FItems[FSel].Id in [MI_MUSIC, MI_SFX, MI_BEAMFX] then
        MenuActivate(FItems[FSel].Id, IfThen(A = gaLeft, -1, 1));
    gaConfirm:
      if FItems[FSel].Enabled then
      begin
        Snd('menu_select');
        MenuActivate(FItems[FSel].Id, 0);
        Exit;
      end;
    gaBack, gaPause:
      case State of
        gsPaused: MenuActivate(MI_RESUME);
        gsLevels, gsOptions, gsLight: EnterState(gsMenu);
        gsComplete, gsGameOver: MenuActivate(MI_MAINMENU);
      end;
  end;
  if FSel <> old then Snd('menu_move', -1, 0.6);
end;

{ ---------------- simulation ---------------- }

procedure TWaveGame.SimLevel(AIndex: Integer);
begin
  SimMode := smLevel;
  Autopilot := True;
  Invincible := True;
  BeginLevel(AIndex);
  EnterState(gsPlaying);
end;

procedure TWaveGame.SimObject(AObj, AStyleLevel: Integer);
begin
  SimMode := smObject;
  Autopilot := True;
  Invincible := True;
  BeginLevel(AStyleLevel);
  FSimObj := AObj;
  FSimTimer := 0.2;
  EnterState(gsPlaying);
end;

procedure TWaveGame.SimScreen(AScreen: TScreenId);
begin
  Autopilot := True;
  Invincible := True;
  case AScreen of
    scMain: begin SimMode := smScreen; EnterState(gsMenu); end;
    scLevels: begin SimMode := smScreen; EnterState(gsLevels); end;
    scOptions: begin SimMode := smScreen; EnterState(gsOptions); end;
    scLight: begin SimMode := smScreen; EnterState(gsLight); end;
    scHud: SimLevel(1);
    scReady:
      begin
        SimLevel(1);
        FReadyT := 2.4; FReadyShown := -1;
        EnterState(gsReady);
      end;
    scPause, scGameOver, scComplete:
      begin
        SimLevel(1);
        Score := 4321; Combo := 5; MaxCombo := 7; FStarsEarned := 2; FNewBest := True;
        case AScreen of
          scPause: EnterState(gsPaused);
          scGameOver: EnterState(gsGameOver);
        else
          EnterState(gsComplete);
        end;
      end;
  end;
  SimMode := smScreen;
end;

{ ---------------- editor helpers ---------------- }

procedure TWaveGame.DrawObjectPreview(Bmp: TBGRABitmap; ADef: Integer; CX, CY, K: Single);
var
  e: TEntity;
begin
  if not ObjOk(ADef) then Exit;
  e := Default(TEntity);
  e.Def := ADef;
  e.X := CX / K; e.Y := CY / K;
  e.R := FData.Objects[ADef].Radius;
  e.Age := FTime;
  e.Angle := FTime * FData.Objects[ADef].Spin;
  FLayer.Start(Bmp.Width, Bmp.Height);
  DrawEntity(Bmp, e, K);
  FLayer.Composite(Bmp);
end;

procedure TWaveGame.SpawnNearShip(ADef: Integer);
begin
  if State <> gsPlaying then Exit;
  AddEntity(ADef, EnsureRange(ShipX + (Random - 0.5) * 120, 40, FieldW - 40), ShipY - 420);
end;

procedure TWaveGame.TickTime(dt: Single);
begin
  FTime := FTime + dt;
end;

{ ---------------- drawing ---------------- }

procedure TWaveGame.DrawPixelArt(Bmp: TBGRABitmap; const D: TObjDef; CX, CY, Cell: Single);
var
  rows: TStringList;
  r, c, w, h, x0, y0, cs: Integer;
  ch: Char;
  col, c1: TBGRAPixel;
begin
  if D.PixelArt = '' then Exit;
  c1 := ObjColor(D, FTime, 0);
  rows := TStringList.Create;
  try
    rows.Delimiter := '/';
    rows.StrictDelimiter := True;
    rows.DelimitedText := D.PixelArt;
    h := rows.Count;
    w := 0;
    for r := 0 to h - 1 do w := Max(w, Length(rows[r]));
    cs := Max(1, Round(Cell));
    x0 := Round(CX - w * cs / 2);
    y0 := Round(CY - h * cs / 2);
    for r := 0 to h - 1 do
      for c := 1 to Length(rows[r]) do
      begin
        ch := rows[r][c];
        case ch of
          '1': col := c1;
          '2': col := D.Color2;
          'W', 'w': col := BGRAWhite;
          'K', 'k': col := BGRA(0, 0, 0);
        else
          Continue;
        end;
        Bmp.FillRect(x0 + (c - 1) * cs, y0 + r * cs, x0 + c * cs, y0 + (r + 1) * cs, col, dmSet);
      end;
  finally
    rows.Free;
  end;
end;

procedure TWaveGame.DrawEntity(Bmp: TBGRABitmap; const E: TEntity; K: Single);
var
  d: TObjDef;
  x, y, r, pulse, a, ang, rr: Single;
  c: TBGRAPixel;
  pts: array of TPointF;
  i, n: Integer;
begin
  d := FData.Objects[E.Def];
  x := E.X * K; y := E.Y * K; r := E.R * K;
  c := ObjColor(d, FTime, E.Phase);
  pulse := 1 + 0.15 * Sin(E.Age * d.PulseRate + E.Phase);
  if d.GlowSize > 0 then
    FGlow.Draw(Bmp, x, y, Round(d.GlowSize * K * pulse), c, Round(EnsureRange(d.GlowAlpha, 0, 2) * 120));
  case d.Style of
    ST_ORB:
      begin
        Bmp.EllipseAntialias(x, y, r * pulse, r * pulse, BGRA(c.red, c.green, c.blue, 230), Max(1, 1.6 * K));
        Bmp.FillEllipseAntialias(x, y, Max(1.5, 4 * K), Max(1.5, 4 * K), BGRAWhite);
      end;
    ST_RING:
      begin
        a := Frac(E.Age * 1.2);
        Bmp.EllipseAntialias(x, y, r * (1 + a * 1.4), r * (1 + a * 1.4), BGRA(255, 255, 255, Round(200 * (1 - a))), Max(1, 2 * K));
        Bmp.FillEllipseAntialias(x, y, r, r, BGRA(c.red div 4, c.green div 4, c.blue div 4, 200));
        Bmp.EllipseAntialias(x, y, r, r, c, Max(1, 2.5 * K));
        if d.Letter <> '' then
          FText.Draw(Bmp, x, y - r * 0.72, d.Letter, Max(8, Round(r * 1.25)), BGRAWhite, taCenter);
      end;
    ST_VOID:
      begin
        Bmp.FillEllipseAntialias(x, y, r * 1.6, r * 1.6, BGRA(0, 0, 0, 120));
        Bmp.FillEllipseAntialias(x, y, r, r, BGRA(0, 0, 0, 245));
        Bmp.EllipseAntialias(x, y, r, r, BGRA(c.red, c.green, c.blue, 170), Max(1, 1.4 * K));
        a := E.Age * 1.5;
        Bmp.EllipseAntialias(x + Cos(a) * r * 0.15, y + Sin(a) * r * 0.15, r * 1.25, r * 1.25,
          BGRA(255, 255, 255, 40), Max(1, K));
      end;
    ST_DIAMOND, ST_STAR:
      begin
        if d.Style = ST_DIAMOND then n := 3 else n := 10;   { 'Triangle' style: a prism, not a diamond }
        SetLength(pts, n);
        for i := 0 to n - 1 do
        begin
          ang := E.Angle + i * 2 * Pi / n - Pi / 2;
          if (d.Style = ST_STAR) and (i mod 2 = 1) then rr := r * 0.45 * pulse else rr := r * 1.15 * pulse;
          pts[i] := PointF(x + Cos(ang) * rr, y + Sin(ang) * rr);
        end;
        Bmp.FillPolyAntialias(pts, BGRA(c.red, c.green, c.blue, 200));
        Bmp.DrawPolygonAntialias(pts, BGRAWhite, Max(1, 1.5 * K));
        if d.Letter <> '' then
          FText.Draw(Bmp, x, y - r * 0.6, d.Letter, Max(8, Round(r * 1.0)), BGRAWhite, taCenter);
      end;
    ST_PIXEL:
      DrawPixelArt(Bmp, d, x, y, d.PixelScale * K);
    ST_GRATING:
      begin
        { a tiny grating chip: dark slab, bright rulings and a sliding rainbow glint }
        Bmp.FillRectAntialias(x - r, y - r * 0.7, x + r, y + r * 0.7, BGRA(20, 22, 34, 230));
        for i := 0 to 6 do
          Bmp.DrawLineAntialias(x - r * 0.8 + i * r * 0.27, y - r * 0.6, x - r * 0.8 + i * r * 0.27, y + r * 0.6,
            BGRA(220, 230, 255, 200), Max(0.7, 0.9 * K));
        a := Frac(E.Age * 0.6 + E.Phase);
        Bmp.DrawLineAntialias(x - r + a * 2 * r, y - r * 0.7, x - r + a * 2 * r + r * 0.3, y + r * 0.7,
          IriPaletteColor(0, FTime * 0.5 + E.Phase, 1), Max(1, 2 * K));
        Bmp.RectangleAntialias(x - r, y - r * 0.7, x + r, y + r * 0.7, c, Max(1, 1.4 * K));
      end;
    ST_PRISM, ST_GEM:
      begin
        { a tiny traced optic: white beam in, spectrum out }
        if d.Style = ST_PRISM then n := LK_PRISM else n := LK_DIAMOND;
        DrawSceneLight(Bmp, n, E.X, E.Y, E.R * 1.25, 0.8, 1, K, E.R * 7);
        if d.Letter <> '' then
          FText.Draw(Bmp, x, y + r * 0.9, d.Letter, Max(8, Round(r * 0.9)), BGRAWhite, taCenter);
      end;
    ST_COMET:
      begin
        for i := 8 downto 1 do
        begin
          a := 1 - i / 9;
          Bmp.FillEllipseAntialias(x, y - i * r * 0.9, r * a, r * a, BGRA(c.red, c.green, c.blue, Round(160 * a)));
        end;
        Bmp.FillEllipseAntialias(x, y, r * 0.8, r * 0.8, BGRAWhite);
      end;
  end;
end;

procedure TWaveGame.DrawShip(Bmp: TBGRABitmap; K: Single);
var
  i, sz: Integer;
  a, x, y, rr: Single;
  c: TBGRAPixel;
  fever: Boolean;
begin
  fever := FFx[EF_FEVER].T > 0;
  for i := High(FTrail) downto 1 do
  begin
    a := 1 - i / Length(FTrail);
    if fever then c := HueToColor(FTime * 2 + i * 0.05, Round(230 * a))
    else c := HueToColor(FTime * 0.5 + i * 0.03, Round(200 * a));
    sz := Max(1, Round((2 + 3 * a) * K * IfThen(fever, 1.6, 1.0)));
    Bmp.FillRect(Round(FTrail[i].x * K) - sz div 2, Round(FTrail[i].y * K) - sz div 2,
      Round(FTrail[i].x * K) + sz - sz div 2, Round(FTrail[i].y * K) + sz - sz div 2, c, dmDrawWithTransparency);
  end;
  x := ShipX * K; y := ShipY * K;
  if (FFx[EF_MAGNET].T > 0) and ObjOk(FFx[EF_MAGNET].Def) then
  begin
    rr := FData.Objects[FFx[EF_MAGNET].Def].Power * K;
    for i := 0 to 23 do
    begin
      a := i * 2 * Pi / 24 + FTime * 1.5;
      Bmp.FillRect(Round(x + Cos(a) * rr) - 1, Round(y + Sin(a) * rr) - 1,
        Round(x + Cos(a) * rr) + 2, Round(y + Sin(a) * rr) + 2, BGRA(255, 90, 230, 140), dmDrawWithTransparency);
    end;
  end;
  if (Invuln > 0) and (Frac(Invuln * 8) >= 0.5) and (State = gsPlaying) then Exit;
  FGlow.Draw(Bmp, x, y, Round(48 * K), BGRA(200, 215, 255), 130);
  Bmp.EllipseAntialias(x, y, SHIP_R * K, SHIP_R * K, HueToColor(FTime * 0.5), Max(1, 2.2 * K));
  Bmp.EllipseAntialias(x, y, SHIP_R * 1.5 * K, SHIP_R * 1.5 * K, BGRA(255, 255, 255, 60), Max(1, K));
  Bmp.FillEllipseAntialias(x, y, 6.5 * K, 6.5 * K, BGRAWhite);
  if FFx[EF_SHIELD].T > 0 then
  begin
    a := 0.6 + 0.4 * Sin(FTime * 10);
    if FFx[EF_SHIELD].T < 2 then a := a * IfThen(Frac(FTime * 6) < 0.5, 1.0, 0.3);
    Bmp.EllipseAntialias(x, y, 34 * K, 34 * K, BGRA(110, 230, 255, Round(220 * a)), Max(1, 3 * K));
    Bmp.FillEllipseAntialias(x, y, 34 * K, 34 * K, BGRA(110, 230, 255, Round(35 * a)));
  end;
end;

procedure TWaveGame.DrawWorld(Bmp: TBGRABitmap);
var
  k, a: Single;
  i, sz: Integer;
  c: TBGRAPixel;
begin
  if not (State in [gsReady, gsPlaying, gsPaused, gsComplete, gsGameOver]) then Exit;
  k := Bmp.Height / REF_HEIGHT;
  if Lv.Anime > 0 then
  begin
    FAnime.RenderScale := k;
    FAnime.DrawOverlay(Bmp, k);
  end;
  FLayer.Start(Bmp.Width, Bmp.Height);
  { optics lit behind the level }
  if False then
    DrawSceneLight(Bmp, Lv.LightScene - 1, Lv.LightX * FieldW, Lv.LightY * FieldH, Lv.LightScale,
      Lv.LightIntensity, 0.7, k);
  { ambient light flashes (bonus pickups, combo milestones) }
  for i := 0 to High(FLightEv) do
    if FLightEv[i].Life > 0 then
    begin
      a := 1 - FLightEv[i].Age / FLightEv[i].Life;
      if a > 0 then
        DrawSceneLight(Bmp, FLightEv[i].Kind, FLightEv[i].X, FLightEv[i].Y, FLightEv[i].Scale,
          Min(1, a * 1.6) * 0.9, a, k, 520);
    end;
  for i := 0 to FPartCount - 1 do
  begin
    a := FParts[i].Life / FParts[i].MaxLife;
    c := FParts[i].Col;
    c.alpha := Round(255 * a);
    sz := Max(1, Round(FParts[i].Size * k));
    Bmp.FillRect(Round(FParts[i].X * k), Round(FParts[i].Y * k), Round(FParts[i].X * k) + sz,
      Round(FParts[i].Y * k) + sz, c, dmDrawWithTransparency);
  end;
  for i := 0 to FEntCount - 1 do
    if ObjOk(FEnt[i].Def) then DrawEntity(Bmp, FEnt[i], k);
  { light beam bonus }
  if FPrismOn and (State in [gsPlaying, gsPaused, gsReady]) then DrawPrismSentinel(Bmp, k);
  if (FFx[EF_BEAM].T > 0) and (FBeam.SegCount > 0) and (State in [gsPlaying, gsPaused, gsReady])
    and (LightMode <> LK_PRISM) then
  begin
    FBeam.DrawGlass(Bmp, k, 1, FTime);
    FBeam.DrawLight(FLayer, k, Min(1, FFx[EF_BEAM].T * 2));
  end;
  if State in [gsReady, gsPlaying, gsPaused] then DrawShip(Bmp, k);
  DrawGrating(Bmp, k);
  DrawDiamond(Bmp, k);
  DrawNewton(Bmp, k);
  FLayer.Composite(Bmp);
end;

function TWaveGame.LightDef(AKind: Integer): TLightDef;
begin
  Result := FData.Light[EnsureRange(AKind, 0, 3)];
end;

procedure TWaveGame.DrawSceneLight(Bmp: TBGRABitmap; AKind: Integer; CX, CY, AScale, AIntensity, AGlass, K: Single;
  ABeamLen: Single);
var
  d: TLightDef;
begin
  d := LightDef(AKind);
  if ABeamLen > 0 then
  begin
    d.Swing := 0;                                { sprites stay still, no swaying }
  end;
  if ABeamLen > 0 then
  begin
    { small sprites: short beams, no stray reflections }
    d.BeamLength := ABeamLen;
    d.Reflect := 0;
    d.Bands := Min(d.Bands, 8);
  end;
  BuildKindScene(FTmp, EnsureRange(AKind, 0, 3), d, CX, CY, AScale, FTime);
  FTmp.DrawGlass(Bmp, K, AGlass, FTime);
  FTmp.DrawLight(FLayer, K, AIntensity);
end;

procedure TWaveGame.DrawScreenLight(Bmp: TBGRABitmap; const F: TScreenFx; K: Single);
begin
  Exit;
  FLayer.Start(Bmp.Width, Bmp.Height);
  DrawSceneLight(Bmp, F.LightFx - 1, F.LightX * FieldW, F.LightY * FieldH, F.LightSize, F.LightIntensity, 0.8, K);
  FLayer.Composite(Bmp);
end;

procedure TWaveGame.AddLightEvent(AX, AY: Single);
var
  i, best: Integer;
begin
  Exit;     { every optic has a gameplay role now: no decorative flashes }
  best := 0;
  for i := 0 to High(FLightEv) do
    if FLightEv[i].Life <= 0 then begin best := i; Break; end
    else if FLightEv[i].Age > FLightEv[best].Age then best := i;
  FLightEv[best].Kind := LightMode;
  FLightEv[best].Kind := LK_NEWTON;           { never a diamond: that is the Diamond Light bonus }
  FLightEv[best].X := EnsureRange(AX, FieldW * 0.45, FieldW * 0.75);
  FLightEv[best].Y := EnsureRange(AY, FieldH * 0.12, FieldH * 0.8);
  FLightEv[best].Age := 0;
  FLightEv[best].Life := 1.4;
  FLightEv[best].Scale := 64;
end;

{ ---------------- watch mode (bot show) ---------------- }

function TWaveGame.IsShow: Boolean;
begin
  Result := FShow;
end;

function TWaveGame.HardMul(AKind: Integer): Single;
begin
  if not FShow then Exit(1);
  case AKind of
    0: Result := SHOW_SPEED;
    2: Result := SHOW_HAZARD;
  else
    Result := SHOW_COLLECT;
  end;
  { endless finale: keeps getting harder so the show reaches its end }
  if (Lv.Duration <= 0) and (AKind <> 1) then
    Result := Result * Min(IfThen(AKind = 0, 1.7, 3.0), 1 + Max(0, PlayTime - 60) / 150);
end;

procedure TWaveGame.StartShow;
begin
  FSavedPower := FPower + FCharge;
  CancelCharge;
  FPower := 0;
  FShow := True;
  FShowTotal := 0;
  FShowCleared := 0;
  FShowLives := -1;
  FSuspended := False;
  ShowStartLevel(0);
end;

procedure TWaveGame.StopShow;
begin
  FShow := False;
  FCharging := False;
  FCharge := 0;
  FShotActive := False;
  FPower := FSavedPower;
  Autopilot := False;
  Invincible := False;
  if FShowTotal > FShowBest then FShowBest := FShowTotal;
  if Assigned(uAudio.Audio) and SoundOn then
  begin
    uAudio.Audio.Lock;
    try uAudio.Audio.Music.SeekSection(0); finally uAudio.Audio.Unlock; end;
  end;
  EnterState(gsMenu);
end;

procedure TWaveGame.ShowStartLevel(AIndex: Integer);
begin
  SimMode := smNone;
  Autopilot := False;
  Invincible := False;
  BeginLevel(AIndex);
  if FShowLives > 0 then Lives := FShowLives;
  FBotX := ShipX; FBotY := ShipY;
  FBotThink := 0;
  FReadyT := 2.4;
  FReadyShown := -1;
  FShowTimer := 0;
  Banner(Format('BOT  -  LEVEL %d / %d', [AIndex + 1, Length(FData.Levels)]), IriPaletteColor(3, FTime * 0.2, 1), 2.4);
  EnterState(gsReady);
end;

procedure TWaveGame.UpdateShow(dt: Single);
begin
  case State of
    gsComplete:
      begin
        FShowTimer := FShowTimer + dt;
        if FShowTimer > 3.5 then
        begin
          if FLevel < High(FData.Levels) then ShowStartLevel(FLevel + 1)
          else StopShow;
        end;
      end;
    gsGameOver:
      begin
        FShowTimer := FShowTimer + dt;
        if FShowTimer > 7 then StopShow;
      end;
  end;
end;

{ Super Hard bot: every 1/30 s it scores candidate positions (11 columns x 5
  rows) by predicting where every object will be over the next second from
  its measured velocity. Danger from hazards dominates, then bonuses,
  collectibles, and a small travel / jitter cost. }
procedure TWaveGame.UpdateBot(dt: Single);
const
  COLS = 11; ROWS = 5;
  HORIZON = 1.0; STEP = 0.1;
var
  ci, ri, i, n: Integer;
  cx, cy, cost, best, bx, by, t, px, py, sx, sy, d, rr, travel, reach, val, ax, ay, bx2, by2, u: Single;
  dd: TObjDef;
  shielded: Boolean;
begin
  UseMouse := True;
  FBotThink := FBotThink - dt;
  if FBotThink > 0 then
  begin
    TargetX := FBotX; TargetY := FBotY;
    Exit;
  end;
  FBotThink := 1 / 30;
  BotGrating;
  shielded := (FFx[EF_SHIELD].T > 0.5) or (Invuln > 0.4);
  best := 1e18; bx := ShipX; by := ShipY;
  for ri := 0 to ROWS - 1 do
    for ci := 0 to COLS - 1 do
    begin
      cx := 30 + ci * (FieldW - 60) / (COLS - 1);
      cy := FieldH * (0.5 + ri * 0.09);
      travel := Sqrt(Sqr(cx - ShipX) + Sqr(cy - ShipY));
      reach := Max(0.05, travel / 1400);           { the ship needs this long to get there }
      cost := travel * 0.15 + Sqrt(Sqr(cx - FBotX) + Sqr(cy - FBotY)) * 0.05 + Abs(cy - FieldH * 0.72) * 0.08;
      for i := 0 to FEntCount - 1 do
      begin
        if not ObjOk(FEnt[i].Def) then Continue;
        dd := FData.Objects[FEnt[i].Def];
        if dd.Role = RL_HAZARD then
        begin
          if shielded then Continue;
          rr := SHIP_R + FEnt[i].R * 0.8 + 26;
          n := 0;
          t := 0;
          while t <= HORIZON do
          begin
            { relative position (hazard - ship) at t and t + STEP; the ship moves
              along the straight path to the candidate. Closest approach over the
              whole step, so fast comets cannot slip between two samples. }
            sx := ShipX + (cx - ShipX) * Min(1, t / reach);
            sy := ShipY + (cy - ShipY) * Min(1, t / reach);
            px := FEnt[i].X + FEnt[i].VX * t;
            py := FEnt[i].Y + FEnt[i].VY * t;
            if dd.Motion = MO_HOMING then px := px + (sx - px) * Min(1, t * 0.8);
            ax := px - sx; ay := py - sy;
            sx := ShipX + (cx - ShipX) * Min(1, (t + STEP) / reach);
            sy := ShipY + (cy - ShipY) * Min(1, (t + STEP) / reach);
            px := FEnt[i].X + FEnt[i].VX * (t + STEP);
            py := FEnt[i].Y + FEnt[i].VY * (t + STEP);
            if dd.Motion = MO_HOMING then px := px + (sx - px) * Min(1, (t + STEP) * 0.8);
            bx2 := px - sx - ax; by2 := py - sy - ay;
            u := bx2 * bx2 + by2 * by2;
            if u > 1e-6 then u := EnsureRange(-(ax * bx2 + ay * by2) / u, 0, 1) else u := 0;
            d := Sqrt(Sqr(ax + bx2 * u) + Sqr(ay + by2 * u));
            if dd.Motion = MO_ORBIT then d := d - dd.MotionAmp * 0.35;   { curved path: keep extra room }
            if d < rr then
              cost := cost + 4000 * (1.2 - t / HORIZON) * (1 + (rr - d) / rr)
            else if d < rr * 2.2 then
              cost := cost + 120 * (rr * 2.2 - d) / rr * (1.2 - t / HORIZON);
            t := t + STEP;
            Inc(n);
          end;
        end
        else
        begin
          { pickups: value at the predicted meeting point }
          if FEnt[i].Y < -40 then Continue;
          t := EnsureRange(reach + 0.1, 0.1, HORIZON);
          px := FEnt[i].X + FEnt[i].VX * t;
          py := FEnt[i].Y + FEnt[i].VY * t;
          if py > cy + 60 then Continue;          { already passed }
          d := Sqrt(Sqr(px - cx) + Sqr(py - cy) * 0.35);
          if dd.Role = RL_BONUS then val := 900 else val := 220 + dd.Score * 2;
          cost := cost - val / (1 + d / 60);
        end;
      end;
      if cost < best then
      begin
        best := cost;
        bx := cx; by := cy;
      end;
    end;
  FBotX := bx; FBotY := by;
  TargetX := bx; TargetY := by;
end;

function TWaveGame.ShowButtonAt(const P: TPointF): Integer;
var
  i: Integer;
begin
  Result := -1;
  if not FShow or (State = gsPaused) then Exit;
  for i := 0 to 1 do
    if (Abs(P.x - (0.32 + i * 0.36) * FieldW) <= 78) and (Abs(P.y - (REF_HEIGHT - 108)) <= 19) then
    begin
      if (i = 0) and not (State in [gsPlaying, gsReady]) then Continue;
      Exit(i);
    end;
end;

{ ---------------- anime cut-ins ---------------- }

function TWaveGame.AnimeShown: Boolean;
begin
  Result := FAnime.Shown;
end;

function TWaveGame.AnimeVisible: Boolean;
begin
  Result := FAnime.L[0].Visible;
end;

procedure TWaveGame.CutIn(const AText: string);
begin
  if (Lv.Anime <= 0) or not Lv.AnimeCutIn then Exit;
  if FAnime.CloseUpOn then Exit;                 { a character is already on screen }
  if FCutIn > 0.5 then Exit;                     { a running cut-in is not restarted }
  FCutIn := 1.35;
  FCutText := AText;
end;

procedure TWaveGame.DrawSpeedLines(Bmp: TBGRABitmap; CX, CY, AAlpha: Single; ACount: Integer);
var
  i: Integer;
  a, r0, r1, wd, sd: Single;
  pts: array of TPointF;
begin
  SetLength(pts, 3);
  for i := 0 to ACount - 1 do
  begin
    sd := Frac(Abs(Sin(i * 12.9898 + Trunc(FTime * 14) * 0.37)) * 43758.5453);
    a := i * 2 * Pi / ACount + sd * 0.12;
    r0 := Bmp.Height * (0.18 + 0.12 * sd);
    r1 := Bmp.Height * 1.1;
    wd := 0.006 + 0.01 * sd;
    pts[0] := PointF(CX + Cos(a) * r0, CY + Sin(a) * r0);
    pts[1] := PointF(CX + Cos(a - wd) * r1, CY + Sin(a - wd) * r1);
    pts[2] := PointF(CX + Cos(a + wd) * r1, CY + Sin(a + wd) * r1);
    Bmp.FillPolyAntialias(pts, BGRA(255, 255, 255, Round(255 * AAlpha * (0.4 + 0.6 * sd))));
  end;
end;

{ level name card shown while the level starts (Ready countdown + first second) }
procedure TWaveGame.DrawLevelCard(Bmp: TBGRABitmap; K, AAlpha: Single);
var
  w, h, y: Single;
  l: TLevelDef;
  f: TScreenFx;
  a: Byte;
  s: string;
begin
  if (AAlpha <= 0.01) or (FLevel > High(FData.Levels)) then Exit;
  l := Lv;
  f := Fx(scMain);
  w := Bmp.Width; h := Bmp.Height;
  y := h * 0.55;
  a := Round(255 * EnsureRange(AAlpha, 0, 1));
  BlendRect(Bmp, 0, Round(y - 14 * K), Round(w), Round(y + 150 * K), BGRA(0, 0, 0), Round(110 * AAlpha));
  if l.Duration > 0 then s := Format('LEVEL %d', [FLevel + 1]) else s := 'ENDLESS';
  s := s + '   -   ' + UpperCase(EnumName(DIFF_NAMES, l.Difficulty));
  FText.Draw(Bmp, w / 2, y, s, Round(20 * K), BGRA(200, 200, 215, a), taCenter, False);
  FDots.Draw(Bmp, UpperCase(l.Name), w / 2, y + 30 * K, Min(64, 900 / Max(6, Length(l.Name))), f, K, FTime, a);
  if l.Subtitle <> '' then
    FText.Draw(Bmp, w / 2, y + 112 * K, l.Subtitle, Round(22 * K), BGRA(230, 230, 240, a), taCenter, False);
end;

{ the combo / bonus cut-in is drawn into its own layer and blended at 50 % }
procedure TWaveGame.DrawCutIn(Bmp: TBGRABitmap; K: Single);
begin
  if FCutIn <= 0 then Exit;
  if (FCutLayer = nil) or (FCutLayer.Width <> Bmp.Width) or (FCutLayer.Height <> Bmp.Height) then
  begin
    FreeAndNil(FCutLayer);
    FCutLayer := TBGRABitmap.Create(Bmp.Width, Bmp.Height);
  end;
  FCutLayer.Fill(BGRAPixelTransparent);
  DrawCutInBand(FCutLayer, K);
  Bmp.PutImage(0, 0, FCutLayer, dmDrawWithTransparency, CUTIN_OPACITY);
end;

procedure TWaveGame.DrawCutInBand(Bmp: TBGRABitmap; K: Single);
const
  DUR = 1.35;
var
  p, e, w, h, y0, bh, sk, ox, ph, pw: Single;
  pts: array of TPointF;
  i: Integer;
  c: TBGRAPixel;
  r: TRect;
  por: TBGRABitmap;
begin
  if FCutIn <= 0 then Exit;
  w := Bmp.Width; h := Bmp.Height;
  p := 1 - FCutIn / DUR;
  { slide in from the right, hold, leave to the left }
  if p < 0.14 then ox := Sqr(1 - p / 0.14) * w * 1.1
  else if p > 0.84 then ox := -Sqr((p - 0.84) / 0.16) * w * 1.2
  else ox := 0;
  y0 := h * 0.25; bh := h * 0.14; sk := w * 0.08;
  DrawSpeedLines(Bmp, w / 2 + ox * 0.3, y0 + bh / 2, 0.45 * Min(1, (1 - p) * 4), 48);
  SetLength(pts, 4);
  pts[0] := PointF(ox - 10 + sk, y0); pts[1] := PointF(ox + w + 10 + sk, y0);
  pts[2] := PointF(ox + w + 10 - sk, y0 + bh); pts[3] := PointF(ox - 10 - sk, y0 + bh);
  Bmp.FillPolyAntialias(pts, BGRA(10, 10, 26, 225));
  for i := 0 to 7 do
  begin
    c := IriPaletteColor(0, i * 0.12 + FTime * 0.4, 1);
    c.alpha := 70;
    pts[0] := PointF(ox + w * (0.35 + i * 0.09) + sk, y0); pts[1] := PointF(ox + w * (0.39 + i * 0.09) + sk, y0);
    pts[2] := PointF(ox + w * (0.39 + i * 0.09) - sk, y0 + bh); pts[3] := PointF(ox + w * (0.35 + i * 0.09) - sk, y0 + bh);
    Bmp.FillPolyAntialias(pts, c);
  end;
  Bmp.DrawLineAntialias(ox - 10 + sk, y0, ox + w + sk, y0, BGRAWhite, Max(1, 3 * K));
  Bmp.DrawLineAntialias(ox - 10 - sk, y0 + bh, ox + w - sk, y0 + bh, BGRAWhite, Max(1, 3 * K));
  por := FAnime.Portrait;
  if por <> nil then
  begin
    ph := bh * 1.35;
    pw := ph * por.Width / Max(1, por.Height);
    r := Rect(Round(ox + w * 0.05), Round(y0 + bh - ph), Round(ox + w * 0.05 + pw), Round(y0 + bh));
    Bmp.StretchPutImage(r, por, dmDrawWithTransparency);
  end;
  FText.Draw(Bmp, ox + w * 0.68, y0 + bh * 0.22, FCutText, Round(Min(52 * K, w * 0.07)),
    IriPaletteColor(3, FTime * 0.6, 1), taCenter);
end;

procedure TWaveGame.DrawShowHud(Bmp: TBGRABitmap; K: Single);
var
  i: Integer;
  bx, by: Single;
  hot: Boolean;
  w, h, rest: Single;
  c: TBGRAPixel;
  s: string;
begin
  w := Bmp.Width; h := Bmp.Height;
  c := IriPaletteColor(3, FTime * 0.25, 1);
  BlendRect(Bmp, 0, Round(h - 74 * K), Round(w), Round(h), BGRA(0, 0, 0), 120);
  FText.Draw(Bmp, w / 2, h - 70 * K, 'WATCH MODE  -  BOT  -  SUPER HARD', Round(20 * K), c, taCenter);
  s := Format('level %d / %d     cleared %d     total %d', [FLevel + 1, Length(FData.Levels), FShowCleared,
    Round(FShowTotal + IfThen(State in [gsComplete, gsGameOver], 0, Score))]);
  FText.Draw(Bmp, w / 2, h - 44 * K, s, Round(17 * K), BGRA(210, 210, 220), taCenter, False);
  FText.Draw(Bmp, w / 2, h - 22 * K, 'P / Space / right click: pause     Esc / Enter: exit', Round(14 * K), BGRA(140, 140, 150), taCenter, False);
  { clickable buttons }
  for i := 0 to 1 do
  begin
    if (i = 0) and not (State in [gsPlaying, gsReady]) then Continue;
    bx := (0.32 + i * 0.36) * FieldW * K;
    by := (REF_HEIGHT - 108) * K;
    hot := ShowButtonAt(FMouseRef) = i;
    if hot then c := IriPaletteColor(3, FTime * 0.3, 1) else c := BGRA(200, 200, 215);
    BlendRect(Bmp, Round(bx - 78 * K), Round(by - 19 * K), Round(bx + 78 * K), Round(by + 19 * K), BGRA(0, 0, 0), 150);
    Bmp.RectangleAntialias(bx - 78 * K, by - 19 * K, bx + 78 * K, by + 19 * K, c, Max(1, 1.5 * K));
    if i = 0 then s := 'PAUSE' else s := 'EXIT';
    FText.Draw(Bmp, bx, by - 13 * K, s, Round(20 * K), c, taCenter);
  end;
  if State = gsComplete then
  begin
    if FLevel < High(FData.Levels) then
      s := Format('NEXT LEVEL IN %d', [Max(0, Ceil(3.5 - FShowTimer))])
    else
      s := 'ALL LEVELS CLEARED';
    FText.Draw(Bmp, w / 2, h * 0.74, s, Round(30 * K), c, taCenter);
  end
  else if State = gsGameOver then
  begin
    rest := Max(0, 7 - FShowTimer);
    FText.Draw(Bmp, w / 2, h * 0.72, Format('BOT RUN TOTAL  %d', [Round(FShowTotal)]), Round(34 * K), c, taCenter);
    FText.Draw(Bmp, w / 2, h * 0.72 + 44 * K, Format('levels cleared %d     back to menu in %d', [FShowCleared, Ceil(rest)]),
      Round(18 * K), BGRA(200, 200, 210), taCenter, False);
  end;
end;

{ ---------------- diffraction grating weapon ---------------- }

procedure TWaveGame.CancelCharge;
begin
  if FCharging or (FCharge > 0) then FPower := FPower + FCharge;
  FCharge := 0;
  FCharging := False;
end;

procedure TWaveGame.FireDown;
begin
  if State <> gsPlaying then Exit;
  if FCharging then Exit;
  if FPower < 0.5 then
  begin
    Popup('NO GRATING POWER', ShipX, ShipY - 60, BGRA(170, 170, 180), 18);
    Exit;
  end;
  FCharging := True;
  FCharge := 0;
  FChargeTime := 0;
  FChargeBlip := 0;
end;

procedure TWaveGame.FireUp;
begin
  if not FCharging then Exit;
  FCharging := False;
  if (State <> gsPlaying) or (FCharge < 0.5) then
  begin
    FPower := FPower + FCharge;
    FCharge := 0;
    Exit;
  end;
  FireGrating;
end;

procedure TWaveGame.DebugFire(ACharge: Single);
begin
  if State <> gsPlaying then Exit;
  FCharge := ACharge;
  FireGrating;
end;

procedure TWaveGame.FireGrating;
var
  q: Single;
begin
  FShotCharge := FCharge;
  FCharge := 0;
  FShotX := ShipX;
  FShotY := ShipY;
  FShotAge := 0;
  q := Sqrt(FShotCharge);
  FShotLife := 0.75 + Min(1.0, q * 0.08);
  FShotActive := True;
  BuildShot;
  Snd('grate_fire', ShipX, Min(1.3, 0.6 + q * 0.08), Max(0.6, 1.2 - q * 0.03));
  Shake := Max(Shake, Min(1.2, 0.2 + q * 0.08));
  FFlash := Max(FFlash, Min(0.5, 0.1 + q * 0.03));
  FSweep := Max(FSweep, Min(1, 0.4 + q * 0.06));
  AddRing(ShipX, ShipY, 700 + q * 120, 40 + q * 4, Min(1.4, 0.4 + q * 0.08), 1.2);
end;

{ White light comes from below the ship (the charged tail), passes a grating
  lying across the ship and splits into diffraction orders:
     sin(theta_m) = m * lambda * pitch
  More stored power = more orders, longer, wider rays. }
procedure TWaveGame.BuildShot;
var
  d: TLightDef;
  q, reach, grow, tail: Single;
  orders: Integer;
begin
  q := Sqrt(Max(0.5, FShotCharge));
  d := LightDef(LK_GRATING);
  orders := EnsureRange(1 + Trunc(q / 2), 1, 7);
  reach := 380 + 150 * q;
  grow := Min(1, FShotAge / 0.18);                 { rays shoot outwards }
  tail := Min(600, 30 + 30 * q);
  d.BeamLength := Max(20, reach * grow);
  d.BeamWidth := d.BeamWidth * Min(4, 1 + q * 0.3);
  d.Glow := d.Glow * Min(2.5, 1 + q * 0.12);
  d.Intensity := d.Intensity * Min(2.2, 0.9 + q * 0.1);
  d.Bands := Max(d.Bands, 12);
  d.Reflect := 0;
  FShot.Clear;
  FShot.AddGrating(FShotX, FShotY - 6, 60 + q * 8, Pi / 2, d.Pitch * 1.6 / orders, orders);
  FShot.Shoot(FShotX, FShotY + tail, -Pi / 2, d);
end;

procedure TWaveGame.UpdateGrating(dt: Single);
var
  take, rate, q: Single;
  i: Integer;
  dd: TObjDef;
begin
  { charging: the stored power is drawn into white light }
  if FCharging then
  begin
    FChargeTime := FChargeTime + dt;
    rate := 4 + 3 * Sqrt(FPower + FCharge);         { more power = faster charge }
    take := Min(FPower, rate * dt);
    FPower := FPower - take;
    FCharge := FCharge + take;
    FChargeBlip := FChargeBlip - dt;
    if (FChargeBlip <= 0) and (take > 0) then
    begin
      FChargeBlip := 0.12;
      Snd('charge', ShipX, 0.5, Min(2.5, 0.8 + Sqrt(FCharge) * 0.08));
    end;
  end;
  { firing: rays grow, burn hazards, then fade }
  if FShotActive then
  begin
    FShotAge := FShotAge + dt;
    FShotY := FShotY + ScrollSpeed * dt * 0.15;
    if FShotAge >= FShotLife then
    begin
      FShotActive := False;
      FShot.SegCount := 0;
      Exit;
    end;
    BuildShot;
    if FShotAge < FShotLife * 0.8 then
    begin
      q := Sqrt(Max(0.5, FShotCharge));
      i := FEntCount - 1;
      while i >= 0 do
      begin
        if i >= FEntCount then begin i := FEntCount - 1; Continue; end;
        if ObjOk(FEnt[i].Def) and (FEnt[i].Y > -30) then
        begin
          dd := FData.Objects[FEnt[i].Def];
          if (dd.Role = RL_HAZARD) and FShot.HitsCircle(FEnt[i].X, FEnt[i].Y, FEnt[i].R + 4 + q * 1.5) then
          begin
            Inc(Score, 50);
            Popup('+50', FEnt[i].X, FEnt[i].Y, IriPaletteColor(0, FTime + i * 0.13, 1), 22);
            AddRing(FEnt[i].X, FEnt[i].Y, 420, 30, 0.8, 2.0);
            Burst(FEnt[i].X, FEnt[i].Y, 22, 380, 3, CM_RAINBOW, BGRAWhite);
            Snd('block', FEnt[i].X, 0.6, 1.5);
            RemoveEntity(i);
          end;
        end;
        Dec(i);
      end;
    end;
  end;
end;

procedure TWaveGame.DrawGrating(Bmp: TBGRABitmap; K: Single);
var
  q, r, tail, a, ang, rr, f: Single;
  i: Integer;
begin
  { charging orb + growing white tail }
  if FCharging and (State = gsPlaying) then
  begin
    q := Sqrt(FCharge);
    r := Min(90, 8 + 5 * q);
    tail := Min(600, 30 + 30 * q);
    FLayer.Line(ShipX * K, ShipY * K, ShipX * K, (ShipY + tail) * K, 0.8, 0.8, 0.85,
      Max(0.8, (1.5 + q * 0.35) * K), 1.4);
    FLayer.Dot(ShipX * K, ShipY * K, r * K, 0.9, 0.9, 0.95);
    FGlow.Draw(Bmp, ShipX * K, ShipY * K, Round(r * 2.2 * K), BGRA(235, 240, 255), 160);
    { power being sucked in from the stored pool }
    for i := 0 to 17 do
    begin
      f := Frac(FChargeTime * 1.3 + i / 18);
      ang := i * 2.4 + FChargeTime * 3;
      rr := (r + 120) * (1 - f) + r * f;
      a := f;
      Bmp.FillRect(Round((ShipX + Cos(ang) * rr) * K) - 1, Round((ShipY + Sin(ang) * rr) * K) - 1,
        Round((ShipX + Cos(ang) * rr) * K) + 2, Round((ShipY + Sin(ang) * rr) * K) + 2,
        BGRA(230, 235, 255, Round(220 * a)), dmDrawWithTransparency);
    end;
  end;
  { diffraction rays }
  if FShotActive and (FShot.SegCount > 0) then
  begin
    a := 1;
    if FShotAge > FShotLife * 0.55 then a := Max(0, 1 - (FShotAge - FShotLife * 0.55) / (FShotLife * 0.45));
    FShot.DrawGlass(Bmp, K, a, FTime);
    FShot.DrawLight(FLayer, K, a);
  end;
end;

procedure TWaveGame.BotGrating;
var
  i, n: Integer;
  want: Single;
begin
  if State <> gsPlaying then Exit;
  n := 0;
  for i := 0 to FEntCount - 1 do
    if ObjOk(FEnt[i].Def) and (FData.Objects[FEnt[i].Def].Role = RL_HAZARD) and
       (FEnt[i].Y < ShipY - 40) and (FEnt[i].Y > ShipY - 650) and (Abs(FEnt[i].X - ShipX) < 320) then Inc(n);
  if not FCharging then
  begin
    if (FPower >= 4) and (n >= 3) and not FShotActive then FireDown;
  end
  else
  begin
    want := Min(FPower + FCharge, 30);
    if (FCharge >= want) or (FChargeTime > 1.4) then FireUp;
  end;
end;

{ ---------------- dispersion prism sentinel ----------------
  * rotates slowly with a random wander of its angular velocity
  * drifts very slowly after the cursor (keeps a little above it)
  * reads the cursor velocity and predicts where it will be in ~0.9 s
  * picks the hazard closest to that path and solves, by tracing a mid-spectrum
    ray through the actual glass (Snell + total internal reflection), the
    incidence angle of the white light that makes the refracted colours point
    at that hazard; the white lamp swings around the prism to that angle }
procedure TWaveGame.UpdatePrism(dt: Single);
const
  LEAD = 0.9;
var
  def: TLightDef;
  i, j, best: Integer;
  cx, cy, rawx, rawy, ax, ay, bx, by, l2, t, px, py, d, sc, bestSc, R, phi, dphi, bestPhi, err, bestErr,
  ox, oy, ex, ey, tx, ty, dirx, diry: Single;
  dd: TObjDef;
begin
  FPrismOn := (State in [gsPlaying, gsReady, gsPaused]) and (FFx[EF_BEAM].T > 0) and (LightMode = LK_PRISM);
  if not FPrismOn then Exit;
  if State <> gsPlaying then Exit;
  def := LightDef(LK_PRISM);
  def.Dispersion := Max(def.Dispersion, 0.08) * 2.5;   { a wide, readable fan of colours }
  def.Bands := Max(def.Bands, 16);
  def.BeamWidth := def.BeamWidth * 1.3;
  FPrismSize := def.Size * 0.75;

  { cursor (mouse target, or the ship when steering with keys) and its smoothed velocity }
  if UseMouse then begin cx := TargetX; cy := TargetY; end else begin cx := ShipX; cy := ShipY; end;
  if dt > 1e-4 then
  begin
    rawx := (cx - FCurX) / dt; rawy := (cy - FCurY) / dt;
    if Abs(rawx) + Abs(rawy) > 6000 then begin rawx := 0; rawy := 0; end;   { first frame / teleport }
    FCurVX := FCurVX + (rawx - FCurVX) * Min(1, dt * 5);
    FCurVY := FCurVY + (rawy - FCurVY) * Min(1, dt * 5);
  end;
  FCurX := cx; FCurY := cy;
  FPredX := EnsureRange(cx + FCurVX * LEAD, 20, FieldW - 20);
  FPredY := EnsureRange(cy + FCurVY * LEAD, 40, FieldH - 40);

  { random slow rotation }
  FPrismSpin := EnsureRange(FPrismSpin * Power(0.6, dt) + (Random - 0.5) * 1.6 * dt, -0.45, 0.45);
  FPrismAng := FPrismAng + FPrismSpin * dt;
  { very slow follow, staying above the cursor }
  FPrismX := FPrismX + (cx - FPrismX) * Min(1, dt * 0.35);
  FPrismY := FPrismY + (cy - 230 - FPrismY) * Min(1, dt * 0.35);
  FPrismX := EnsureRange(FPrismX, 60, FieldW - 60);
  FPrismY := EnsureRange(FPrismY, 120, FieldH - 160);

  { target: the hazard nearest to the predicted path cursor -> prediction (extended ahead) }
  ax := cx; ay := cy;
  bx := FPredX; by := FPredY - 260;            { hazards fall onto the path from above }
  l2 := Sqr(bx - ax) + Sqr(by - ay);
  best := -1; bestSc := 1e9;
  for i := 0 to FEntCount - 1 do
  begin
    if not ObjOk(FEnt[i].Def) then Continue;
    dd := FData.Objects[FEnt[i].Def];
    if dd.Role <> RL_HAZARD then Continue;
    if (FEnt[i].Y < -20) or (FEnt[i].Y > cy + 60) then Continue;
    px := FEnt[i].X + FEnt[i].VX * 0.4;
    py := FEnt[i].Y + FEnt[i].VY * 0.4;
    if l2 > 1 then t := EnsureRange(((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / l2, 0, 1) else t := 0;
    d := Sqrt(Sqr(ax + (bx - ax) * t - px) + Sqr(ay + (by - ay) * t - py));
    if d > 200 then Continue;
    sc := d + t * 120;                          { closer to the path and sooner = more urgent }
    if sc < bestSc then begin bestSc := sc; best := i; end;
  end;
  FPrismTarget := best;
  if best >= 0 then
  begin
    FAimX := FEnt[best].X + FEnt[best].VX * 0.25;
    FAimY := FEnt[best].Y + FEnt[best].VY * 0.25;
  end
  else
  begin
    FAimX := FPredX; FAimY := FPredY - 160;    { light the road ahead of the cursor }
  end;

  { solve the incidence angle: trace the mid-spectrum ray for 120 directions }
  FBeam.Clear;
  FBeam.AddPrism(FPrismX, FPrismY, FPrismSize, FPrismAng, def.Index, def.Dispersion);
  R := FPrismSize * 1.8;
  bestErr := 1e9; bestPhi := FPrismPhi;
  for j := 0 to 119 do
  begin
    phi := j * 2 * Pi / 120;                    { travel direction of the white light }
    dirx := Cos(phi); diry := Sin(phi);
    ox := FPrismX - dirx * R; oy := FPrismY - diry * R;
    if FBeam.ProbeExit(ox, oy, dirx, diry, def.Index, tx, ty, ex, ey) then
    begin
      d := Sqrt(Sqr(FAimX - tx) + Sqr(FAimY - ty));
      if d < 1 then Continue;
      err := 1 - (ex * (FAimX - tx) + ey * (FAimY - ty)) / d;
      { a small preference for staying where the lamp is: smooth motion }
      dphi := Abs(ArcTan2(Sin(phi - FPrismPhi), Cos(phi - FPrismPhi)));
      err := err + dphi * 0.004;
      if err < bestErr then begin bestErr := err; bestPhi := phi; end;
    end;
  end;
  FPrismSolved := bestErr < 0.02;
  Inc(PrismFrames);
  if FPrismSolved then Inc(PrismSolvedFrames);
  { the lamp swings around the prism toward the solution }
  dphi := ArcTan2(Sin(bestPhi - FPrismPhi), Cos(bestPhi - FPrismPhi));
  FPrismPhi := FPrismPhi + EnsureRange(dphi, -3.2 * dt, 3.2 * dt);

  def.BeamLength := 1500;
  def.Reflect := Min(def.Reflect, 0.04);
  def.Swing := 0;
  FBeam.Shoot(FPrismX - Cos(FPrismPhi) * R, FPrismY - Sin(FPrismPhi) * R, FPrismPhi, def);

  { rays burn hazards after a short exposure }
  i := FEntCount - 1;
  while i >= 0 do
  begin
    if i >= FEntCount then begin i := FEntCount - 1; Continue; end;
    if ObjOk(FEnt[i].Def) and (FData.Objects[FEnt[i].Def].Role = RL_HAZARD) and (FEnt[i].Y > -20) then
    begin
      if FBeam.HitsCircle(FEnt[i].X, FEnt[i].Y, FEnt[i].R + 3) then
      begin
        FEnt[i].Heat := FEnt[i].Heat + dt;
        if FEnt[i].Heat >= 0.22 then
        begin
          Inc(Score, 40);
          Inc(PrismKills);
          Popup('+40', FEnt[i].X, FEnt[i].Y, IriPaletteColor(0, FTime + i * 0.17, 1), 22);
          AddRing(FEnt[i].X, FEnt[i].Y, 420, 30, 0.8, 2.0);
          Burst(FEnt[i].X, FEnt[i].Y, 24, 380, 3, CM_RAINBOW, BGRAWhite);
          Snd('block', FEnt[i].X, 0.6, 1.6);
          RemoveEntity(i);
        end;
      end
      else
        FEnt[i].Heat := Max(0, FEnt[i].Heat - dt);
    end;
    Dec(i);
  end;
end;

procedure TWaveGame.DrawPrismSentinel(Bmp: TBGRABitmap; K: Single);
var
  a, R, lx, ly, t: Single;
  i, n: Integer;
  c: TBGRAPixel;
begin
  a := Min(1, FFx[EF_BEAM].T * 1.5);
  if FBeam.SegCount = 0 then Exit;
  { predicted path of the cursor: dotted line + ghost ring }
  n := 14;
  for i := 0 to n do
  begin
    t := i / n;
    lx := FCurX + (FPredX - FCurX) * t;
    ly := FCurY + (FPredY - FCurY) * t;
    Bmp.FillRect(Round(lx * K) - 1, Round(ly * K) - 1, Round(lx * K) + 2, Round(ly * K) + 2,
      BGRA(255, 255, 255, Round(90 * a)), dmDrawWithTransparency);
  end;
  Bmp.EllipseAntialias(FPredX * K, FPredY * K, 14 * K, 14 * K, BGRA(255, 255, 255, Round(80 * a)), Max(1, K));
  { lock-on marker }
  if (FPrismTarget >= 0) and (FPrismTarget < FEntCount) then
  begin
    c := IriPaletteColor(0, FTime * 0.8, 1);
    c.alpha := Round(200 * a);
    R := FEnt[FPrismTarget].R + 10 + 3 * Sin(FTime * 12);
    Bmp.EllipseAntialias(FEnt[FPrismTarget].X * K, FEnt[FPrismTarget].Y * K, R * K, R * K, c, Max(1, 1.6 * K));
  end;
  { white lamp that swings around the prism }
  R := FPrismSize * 1.8;
  lx := FPrismX - Cos(FPrismPhi) * R; ly := FPrismY - Sin(FPrismPhi) * R;
  FGlow.Draw(Bmp, lx * K, ly * K, Round(26 * K), BGRA(240, 245, 255), Round(200 * a));
  Bmp.FillEllipseAntialias(lx * K, ly * K, 4.5 * K, 4.5 * K, BGRA(255, 255, 255, Round(255 * a)));
  FBeam.DrawGlass(Bmp, K, a, FTime);
  FBeam.DrawLight(FLayer, K, a);
end;

{ ---------------- diamond light bonus ----------------
  For 5 s a brilliant-cut diamond (n = 2.42, strong dispersion) hovers above
  the ship and turns slowly. White light from the ship enters through the
  culet; total internal reflection throws spectral "fire" all around.
  Every score item a ray touches is caught and pulled to the ship along a
  rainbow tractor beam, then collected (normal score x combo). }
procedure TWaveGame.UpdateDiamond(dt: Single);
var
  def: TLightDef;
  i: Integer;
  t: Single;
begin
  if (FFx[EF_DIAMOND].T <= 0) or (State <> gsPlaying) then
  begin
    if FFx[EF_DIAMOND].T <= 0 then FDia.SegCount := 0;
    Exit;
  end;
  t := FFx[EF_DIAMOND].T;
  FDiaAng := FDiaAng + dt * 1.15;
  FDiaX := FDiaX + (ShipX - FDiaX) * Min(1, dt * 6);
  FDiaY := FDiaY + (ShipY - 170 - FDiaY) * Min(1, dt * 6);
  def := LightDef(LK_DIAMOND);
  def.Index := Max(def.Index, 2.2);
  def.Dispersion := Max(def.Dispersion, 0.3);
  def.MaxBounce := Max(def.MaxBounce, 9);
  def.Reflect := Max(def.Reflect, 0.25);
  def.Bands := Max(def.Bands, 12);
  def.BeamLength := 1100;
  def.Swing := 0;
  def.Intensity := def.Intensity * Min(1, t * 2);
  FDia.Clear;
  FDia.AddDiamond(FDiaX, FDiaY, 78, FDiaAng, def.Index, def.Dispersion);
  { the lamp is the ship: a slightly wobbling white beam into the bottom of the stone }
  FDia.Shoot(ShipX, ShipY - 20, ArcTan2(FDiaY + 20 - (ShipY - 20), FDiaX + 8 * Sin(FTime * 3.1) - ShipX), def);
  { catch score items touched by the fire }
  for i := 0 to FEntCount - 1 do
    if ObjOk(FEnt[i].Def) and not FEnt[i].Pulled and (FData.Objects[FEnt[i].Def].Role = RL_COLLECT)
      and (FEnt[i].Y > -30) and FDia.HitsCircle(FEnt[i].X, FEnt[i].Y, FEnt[i].R + 10) then
    begin
      FEnt[i].Pulled := True;
      FEnt[i].PullV := 300;
      Inc(DiamondCatches);
      Snd('charge', FEnt[i].X, 0.45, 1.8 + Random * 0.4);
    end;
end;

procedure TWaveGame.DrawDiamond(Bmp: TBGRABitmap; K: Single);
var
  i: Integer;
  a: Single;
  r, g, b: Single;
begin
  { rainbow tractor beams of caught items (also after the bonus ends) }
  for i := 0 to FEntCount - 1 do
    if FEnt[i].Pulled then
    begin
      SpectrumRGB(Frac(FTime * 0.8 + i * 0.13), r, g, b);
      FLayer.Line(FEnt[i].X * K, FEnt[i].Y * K, ShipX * K, ShipY * K, r * 0.6, g * 0.6, b * 0.6,
        Max(0.8, 1.6 * K), 1.2);
      FLayer.Dot(FEnt[i].X * K, FEnt[i].Y * K, 9 * K, r * 0.7, g * 0.7, b * 0.7);
    end;
  if (FFx[EF_DIAMOND].T <= 0) or (FDia.SegCount = 0) or not (State in [gsPlaying, gsPaused]) then Exit;
  a := Min(1, FFx[EF_DIAMOND].T * 2);
  FGlow.Draw(Bmp, FDiaX * K, FDiaY * K, Round(70 * K), BGRA(235, 240, 255), Round(110 * a));
  FDia.DrawGlass(Bmp, K, a, FTime);
  FDia.DrawLight(FLayer, K, a);
end;

{ ---------------- Newton's prisms guardian ----------------
  * appears when the combo passes x3 (only one at a time)
  * each further combo step: +1 strength (bigger) and +1.5 s (max 12 s)
  * rotates slowly, drifts slowly after the cursor, a little ahead of it
  * rams hazards instead of the player: the hazard is destroyed, the
    guardian loses 1 strength and shrinks; at 0 it shatters
  * fades away by itself when its time (7 s) runs out }
function TWaveGame.NewtonSize: Single;
begin
  Result := 34 + 8 * Min(FNewHP, 8);
end;

procedure TWaveGame.NewtonCombo(AOld, ANew: Integer);
begin
  if (ANew <= 3) or (ANew <= AOld) or (State <> gsPlaying) then Exit;
  if not FNewOn then
  begin
    if AOld > 3 then Exit;                       { appears when the combo crosses x3 }
    FNewOn := True;
    Inc(NewtonSpawns);
    FNewHP := 2;
    FNewT := 7;
    FNewMaxT := 7;
    FNewAge := 0;
    FNewX := ShipX; FNewY := ShipY - 140;
    FNewAng := Random * 2 * Pi;
    FNewSpin := 0.5;
    Banner('NEWTON''S PRISMS', IriPaletteColor(0, FTime * 0.3, 1), 1.4);
    Snd('shield', ShipX, 0.8, 1.2);
    AddRing(FNewX, FNewY, 600, 40, 0.6, 1.5);
  end
  else
  begin
    FNewHP := Min(8, FNewHP + 1);
    FNewT := Max(0, Min(FNewT + 1.5, 12 - FNewAge));   { never more than 12 s in total }
    FNewMaxT := Max(FNewMaxT, FNewT);
    Popup('GUARD +1', FNewX, FNewY - 60, IriPaletteColor(0, FTime, 1), 20);
    AddRing(FNewX, FNewY, 500, 30, 0.4, 2);
  end;
end;

procedure TWaveGame.UpdateNewton(dt: Single);
var
  i: Integer;
  cx, cy, rad, d: Single;
  def: TLightDef;
  dd: TObjDef;
begin
  if not FNewOn or (State <> gsPlaying) then Exit;
  FNewT := FNewT - dt;
  FNewAge := FNewAge + dt;
  if FNewHurt > 0 then FNewHurt := Max(0, FNewHurt - dt * 3);
  if FNewT <= 0 then
  begin
    FNewOn := False;
    Burst(FNewX, FNewY, 30, 260, 3, CM_RAINBOW, BGRAWhite);
    Exit;
  end;
  { slow rotation (random wander) and slow follow, staying a bit ahead of the cursor }
  FNewSpin := EnsureRange(FNewSpin + (Random - 0.5) * 0.8 * dt, 0.25, 0.7);
  FNewAng := FNewAng + FNewSpin * dt;
  if UseMouse then begin cx := TargetX; cy := TargetY; end else begin cx := ShipX; cy := ShipY; end;
  cy := cy - 130;
  FNewX := FNewX + (cx - FNewX) * Min(1, dt * 0.9);
  FNewY := FNewY + (cy - FNewY) * Min(1, dt * 0.9);
  FNewX := EnsureRange(FNewX, 40, FieldW - 40);
  FNewY := EnsureRange(FNewY, 60, FieldH - 80);
  { build the two prisms (rotated as a whole) and their light }
  def := LightDef(LK_NEWTON);
  def.Swing := 0;
  def.Tilt := RadToDeg(FNewAng);
  def.BeamLength := 260 + 30 * FNewHP;
  def.Reflect := 0;
  def.Intensity := def.Intensity * Min(1, FNewT * 1.5);
  BuildKindScene(FNew, LK_NEWTON, def, FNewX, FNewY, NewtonSize * 0.75, 0);
  { ram hazards }
  rad := NewtonSize;
  i := FEntCount - 1;
  while i >= 0 do
  begin
    if i >= FEntCount then begin i := FEntCount - 1; Continue; end;
    if ObjOk(FEnt[i].Def) then
    begin
      dd := FData.Objects[FEnt[i].Def];
      if dd.Role = RL_HAZARD then
      begin
        d := Sqrt(Sqr(FEnt[i].X - FNewX) + Sqr(FEnt[i].Y - FNewY));
        if d < rad + FEnt[i].R * 0.8 then
        begin
          Inc(Score, 30);
          Inc(NewtonKills);
          Popup('+30', FEnt[i].X, FEnt[i].Y, IriPaletteColor(0, FTime + i * 0.2, 1), 22);
          AddRing(FEnt[i].X, FEnt[i].Y, 480, 34, 0.9, 2.0);
          Burst(FEnt[i].X, FEnt[i].Y, 26, 420, 3, CM_RAINBOW, BGRAWhite);
          Snd('block', FEnt[i].X, 0.8, 1.1);
          Shake := Max(Shake, 0.25);
          RemoveEntity(i);
          Dec(FNewHP);
          FNewHurt := 1;
          if FNewHP <= 0 then
          begin
            FNewOn := False;
            Burst(FNewX, FNewY, 60, 520, 4, CM_RAINBOW, BGRAWhite);
            AddRing(FNewX, FNewY, 700, 50, -0.8, 1.4);
            Snd('hit', FNewX, 0.6, 1.4);
            Popup('GUARDIAN BROKEN', FNewX, FNewY - 40, BGRA(255, 160, 160), 22);
            Exit;
          end;
        end;
      end;
    end;
    Dec(i);
  end;
end;

procedure TWaveGame.DrawNewton(Bmp: TBGRABitmap; K: Single);
var
  a, r: Single;
  i: Integer;
  c: TBGRAPixel;
begin
  if not FNewOn or not (State in [gsPlaying, gsPaused]) or (FNew.SegCount = 0) then Exit;
  a := Min(1, FNewT * 1.5);
  { guard aura: radius = ram range, flashes red when hit }
  r := NewtonSize;
  if FNewHurt > 0 then c := BGRA(255, 90, 90, Round(160 * FNewHurt))
  else c := BGRA(200, 220, 255, Round(55 * a));
  Bmp.EllipseAntialias(FNewX * K, FNewY * K, r * K, r * K, c, Max(1, 1.6 * K));
  FGlow.Draw(Bmp, FNewX * K, FNewY * K, Round(r * 1.4 * K), BGRA(220, 230, 255), Round(70 * a));
  FNew.DrawGlass(Bmp, K, a, FTime);
  FNew.DrawLight(FLayer, K, a);
  { strength pips + time arc }
  for i := 0 to FNewHP - 1 do
    Bmp.FillEllipseAntialias((FNewX - (FNewHP - 1) * 7 + i * 14) * K, (FNewY + r + 14) * K, 4 * K, 4 * K,
      IriPaletteColor(0, i * 0.12 + FTime * 0.2, 1));
  Bmp.Arc(FNewX * K, FNewY * K, (r + 6) * K, (r + 6) * K, -Pi / 2, -Pi / 2 + 2 * Pi * FNewT / Max(0.1, FNewMaxT),
    BGRA(255, 255, 255, Round(150 * a)), Max(1, 2 * K), False, BGRAPixelTransparent);
end;

procedure TWaveGame.UpdateBeam;
var
  i: Integer;
  d: TObjDef;
begin
  if LightMode = LK_PRISM then Exit;          { the prism is a moving sentinel: UpdatePrism }
  if FFx[EF_BEAM].T <= 0 then
  begin
    FBeam.SegCount := 0;
    Exit;
  end;
  BuildBeamScene(FBeam, LightMode, LightDef(LightMode), ShipX, ShipY, FTime);
  { the light burns hazards and collects collectibles it touches }
  i := FEntCount - 1;
  while i >= 0 do
  begin
    if i >= FEntCount then begin i := FEntCount - 1; Continue; end;
    if ObjOk(FEnt[i].Def) and (FEnt[i].Y > -20) and FBeam.HitsCircle(FEnt[i].X, FEnt[i].Y, FEnt[i].R + 4) then
    begin
      d := FData.Objects[FEnt[i].Def];
      if d.Role = RL_HAZARD then
      begin
        Inc(Score, 30);
        Popup('+30', FEnt[i].X, FEnt[i].Y, IriPaletteColor(0, FTime + i * 0.1, 1), 22);
        AddRing(FEnt[i].X, FEnt[i].Y, 420, 30, 0.8, 2.0);
        Burst(FEnt[i].X, FEnt[i].Y, 20, 360, 3, CM_RAINBOW, BGRAWhite);
        Snd('block', FEnt[i].X, 0.6, 1.4);
        RemoveEntity(i);
      end
      else if d.Role = RL_COLLECT then
        ApplyEffect(i);
    end;
    Dec(i);
  end;
end;

procedure TWaveGame.DrawAmbient(Bmp: TBGRABitmap; K: Single; ACount: Integer);
var
  i, sz: Integer;
  c: TBGRAPixel;
  tw: Single;
begin
  for i := 0 to Min(ACount, Length(FAmbient)) - 1 do
  begin
    tw := 0.5 + 0.5 * Sin(FTime * 2 + i);
    c := IriPaletteColor(1, FAmbient[i].Life + FTime * 0.05, 0.8);
    c.alpha := Round(60 + 150 * tw);
    sz := Max(1, Round(FAmbient[i].Size * K));
    Bmp.FillRect(Round(FAmbient[i].X * K), Round(FAmbient[i].Y * K), Round(FAmbient[i].X * K) + sz,
      Round(FAmbient[i].Y * K) + sz, c, dmDrawWithTransparency);
  end;
end;

procedure TWaveGame.DrawStarsRow(Bmp: TBGRABitmap; CX, CY, Size: Single; AEarned: Integer; AAnim: Single);
var
  i, j: Integer;
  x, s, ang: Single;
  pts: array of TPointF;
  c: TBGRAPixel;
begin
  SetLength(pts, 10);
  for i := 0 to 2 do
  begin
    x := CX + (i - 1) * Size * 2.4;
    s := Size;
    if i < AEarned then
    begin
      s := Size * (1 + 0.25 * Max(0, Sin(AAnim * 3 - i * 0.6)));
      c := IriPaletteColor(1, FTime * 0.2 + i * 0.2, 0.9);
    end
    else
      c := BGRA(255, 255, 255, 50);
    for j := 0 to 9 do
    begin
      ang := j * Pi / 5 - Pi / 2;
      if j mod 2 = 0 then pts[j] := PointF(x + Cos(ang) * s, CY + Sin(ang) * s)
      else pts[j] := PointF(x + Cos(ang) * s * 0.45, CY + Sin(ang) * s * 0.45);
    end;
    Bmp.FillPolyAntialias(pts, c);
    if i < AEarned then Bmp.DrawPolygonAntialias(pts, BGRAWhite, 1.5);
  end;
end;

procedure TWaveGame.DrawMenu(Bmp: TBGRABitmap; const F: TScreenFx; K: Single);
var
  i: Integer;
  y0, y, sz: Single;
  c: TBGRAPixel;
  s: string;
begin
  y0 := F.MenuY * Bmp.Height;
  for i := 0 to High(FItems) do
  begin
    y := y0 + i * F.MenuSpacing * K;
    s := FItems[i].Caption;
    if FItems[i].Value <> '' then s := s + '   < ' + FItems[i].Value + ' >';
    sz := F.MenuSize * K;
    if i = FSel then
    begin
      if F.MenuGlow > 0 then
        FGlow.Draw(Bmp, Bmp.Width / 2, y + sz * 0.6, Round(sz * 1.8), IriPaletteColor(F.Palette, FTime * 0.2, 0.7),
          Round(EnsureRange(F.MenuGlow, 0, 1.5) * 100));
      if F.MenuDotted then
        FDots.Draw(Bmp, s, Bmp.Width / 2, y - sz * 0.1, F.MenuSize * 1.05, F, K, FTime)
      else
        FText.Draw(Bmp, Bmp.Width / 2, y, s, Round(sz * 1.05), ColorForMode(F.MenuSelMode, F.MenuColor, FTime * 0.3), taCenter);
    end
    else
    begin
      c := F.MenuColor;
      if not FItems[i].Enabled then c := BGRA(c.red div 3, c.green div 3, c.blue div 3, 255);
      FText.Draw(Bmp, Bmp.Width / 2, y, s, Round(sz), c, taCenter);
    end;
  end;
end;

procedure TWaveGame.DrawLevelList(Bmp: TBGRABitmap; const F: TScreenFx; K: Single);
var
  i: Integer;
  y0, y, sz, x0, x1: Single;
  c, dc: TBGRAPixel;
  l: TLevelDef;
  s: string;
begin
  y0 := F.MenuY * Bmp.Height;
  sz := F.MenuSize * K;
  x0 := 40 * K;
  x1 := Bmp.Width - 40 * K;
  for i := 0 to High(FItems) do
  begin
    y := y0 + i * F.MenuSpacing * K;
    if FItems[i].Id = MI_BACK then
    begin
      if i = FSel then c := ColorForMode(F.MenuSelMode, F.MenuColor, FTime * 0.3) else c := F.MenuColor;
      FText.Draw(Bmp, Bmp.Width / 2, y + sz * 0.3, 'BACK', Round(sz), c, taCenter);
      Continue;
    end;
    l := FData.Levels[FItems[i].Id - MI_LEVEL];
    if i = FSel then
    begin
      BlendRect(Bmp, Round(x0 - 10 * K), Round(y - 6 * K), Round(x1 + 10 * K), Round(y + F.MenuSpacing * K - 10 * K),
        IriPaletteColor(F.Palette, FTime * 0.15, 0.6), 40);
      c := ColorForMode(F.MenuSelMode, F.MenuColor, FTime * 0.3);
    end
    else
      c := F.MenuColor;
    if not FItems[i].Enabled then c := BGRA(c.red div 3, c.green div 3, c.blue div 3, 255);
    FText.Draw(Bmp, x0, y, IntToStr(i + 1), Round(sz), BGRA(c.red, c.green, c.blue, 160), taLeftJustify);
    s := l.Name;
    if l.Pixel then s := s + '  [8-BIT]';
    FText.Draw(Bmp, x0 + sz * 1.6, y, s, Round(sz), c, taLeftJustify);
    if FItems[i].Enabled then
    begin
      DrawStarsRow(Bmp, x1 - sz * 2.0, y + sz * 0.62, sz * 0.32, FStars[FItems[i].Id - MI_LEVEL], 0);
      case EnsureRange(l.Difficulty, 0, 4) of
        0: dc := BGRA(120, 255, 140);
        1: dc := BGRA(120, 220, 255);
        2: dc := BGRA(255, 200, 80);
        3: dc := BGRA(255, 110, 90);
      else
        dc := BGRA(230, 80, 255);
      end;
      FText.Draw(Bmp, x1 - sz * 3.4, y + sz * 0.25, UpperCase(EnumName(DIFF_NAMES, l.Difficulty)), Round(sz * 0.55),
        dc, taRightJustify, True, 'Segoe UI', False);
    end
    else
      FText.Draw(Bmp, x1, y + sz * 0.2, 'LOCKED', Round(sz * 0.6), BGRA(120, 120, 130), taRightJustify);
  end;
  if (FSel >= 0) and (FSel <= High(FItems)) and (FItems[FSel].Id >= MI_LEVEL) then
  begin
    i := FItems[FSel].Id - MI_LEVEL;
    l := FData.Levels[i];
    y := Bmp.Height * 0.86;
    FText.Draw(Bmp, Bmp.Width / 2, y, l.Subtitle, Round(24 * K), F.TextColor, taCenter, False);
    if l.Duration > 0 then s := Format('%d s', [Round(l.Duration)]) else s := 'ENDLESS';
    FText.Draw(Bmp, Bmp.Width / 2, y + 36 * K, Format('%s   |   BEST %d   |   %d LIVES', [s, FBest[i], l.Lives]),
      Round(20 * K), BGRA(170, 170, 180), taCenter, False);
  end;
end;

procedure TWaveGame.DrawHudPlay(Bmp: TBGRABitmap; K: Single);
var
  f: TScreenFx;
  i, e, n, step: Integer;
  w, h, p, a, x, y: Single;
  c: TBGRAPixel;
  l: TLevelDef;
  s: string;
begin
  f := Fx(scHud);
  l := Lv;
  w := Bmp.Width; h := Bmp.Height;
  if l.Anime > 0 then
  begin
    if FFx[EF_FEVER].T > 0 then DrawSpeedLines(Bmp, w / 2, h * 0.45, 0.35, 36);
    DrawCutIn(Bmp, K);
  end;
  FText.Draw(Bmp, 18 * K, 30 * K, IntToStr(Score), Round(f.TitleSize * K), BGRAWhite, taLeftJustify);
  if Combo > 1 then
    FText.Draw(Bmp, 20 * K, 30 * K + f.TitleSize * K * 1.15, 'x' + IntToStr(Combo), Round(f.TitleSize * 0.72 * K),
      ColorForMode(CM_RAINBOW, BGRAWhite, FTime * 0.8), taLeftJustify);
  if FLevel <= High(FBest) then
    FText.Draw(Bmp, w - 18 * K, 34 * K, 'BEST ' + IntToStr(Max(FBest[FLevel], Score)), Round(f.MenuSize * K),
      f.MenuColor, taRightJustify);
  FText.Draw(Bmp, w - 18 * K, 34 * K + f.MenuSize * K * 1.35, UpperCase(l.Name), Round(f.MenuSize * 0.8 * K),
    f.TextColor, taRightJustify, False);
  n := Max(Lives, l.Lives);
  for i := 0 to Min(n, 6) - 1 do
  begin
    if i < Lives then c := BGRAWhite else c := BGRA(255, 255, 255, 50);
    Bmp.FillEllipseAntialias(w - (26 + i * 26) * K, 34 * K + f.MenuSize * K * 3.5, 8 * K, 8 * K, c);
  end;
  { level progress bar: dotted pearl }
  if l.Duration > 0 then
  begin
    p := EnsureRange(PlayTime / l.Duration, 0, 1);
    step := Max(2, Round(5 * K));
    Bmp.FillRect(0, 0, Round(w), Max(2, Round(5 * K)), BGRA(255, 255, 255, 30), dmDrawWithTransparency);
    for i := 0 to Round(w * p) div step do
    begin
      c := IriPaletteColor(1, i * 0.01 + FTime * 0.1, 0.8);
      Bmp.FillRect(i * step, 0, i * step + step - 1, Max(2, Round(5 * K)), c, dmSet);
    end;
  end;
  { grating power meter }
  if (FPower > 0) or FCharging then
  begin
    c := IriPaletteColor(3, FTime * 0.2, 1);
    if FCharging then s := Format('GRATING  %.0f   charge %.0f', [FPower, FCharge])
    else s := Format('GRATING  %.0f', [FPower]);
    FText.Draw(Bmp, w - 18 * K, h - 64 * K, s, Round(20 * K), c, taRightJustify);
    a := Min(1, Sqrt(FPower + FCharge) / 10);
    Bmp.FillRect(Round(w - 180 * K), Round(h - 36 * K), Round(w - 18 * K), Round(h - 30 * K), BGRA(255, 255, 255, 40), dmDrawWithTransparency);
    Bmp.FillRect(Round(w - 180 * K), Round(h - 36 * K), Round(w - 180 * K + 162 * K * a), Round(h - 30 * K), c, dmSet);
    if not FCharging and (FPower >= 1) and (FPower < 3) and not FShow then
      FText.Draw(Bmp, w - 18 * K, h - 90 * K, 'hold left mouse', Round(14 * K), BGRA(180, 180, 190), taRightJustify, False);
  end;
  { active timed effects }
  x := 34 * K;
  y := h - 50 * K;
  for e := Low(FFx) to High(FFx) do
    if (FFx[e].T > 0) and ObjOk(FFx[e].Def) then
    begin
      c := ObjColor(FData.Objects[FFx[e].Def], FTime, 0);
      a := FFx[e].T / FFx[e].Dur;
      Bmp.EllipseAntialias(x, y, 20 * K, 20 * K, BGRA(255, 255, 255, 50), Max(1, 3 * K));
      Bmp.Arc(x, y, 20 * K, 20 * K, Pi / 2, Pi / 2 + a * 2 * Pi, c, Max(1, 3 * K), False, BGRAPixelTransparent);
      s := FData.Objects[FFx[e].Def].Letter;
      if s = '' then s := Copy(FData.Objects[FFx[e].Def].Caption, 1, 1);
      FText.Draw(Bmp, x, y - 14 * K, s, Round(22 * K), c, taCenter);
      x := x + 52 * K;
    end;
  for i := 0 to FPopCount - 1 do
  begin
    a := FPops[i].Life / FPops[i].MaxLife;
    c := FPops[i].Col;
    c.alpha := Round(255 * Min(1, a * 1.5));
    FText.Draw(Bmp, FPops[i].X * K, FPops[i].Y * K, FPops[i].Text, Round(FPops[i].Size * K), c, taCenter);
  end;
  if FBannerTime > 0 then
  begin
    c := FBannerCol;
    c.alpha := Round(CUTIN_OPACITY * Min(1, FBannerTime));     { combo / bonus popup text: 50 % }
    FText.Draw(Bmp, w / 2, h * 0.38, FBanner, Round(48 * K), c, taCenter);
  end;
  if FShow then DrawShowHud(Bmp, K);
  if SimMode in [smLevel, smObject] then
    FText.Draw(Bmp, w / 2, h - 30 * K, 'SIMULATION  -  autopilot', Round(16 * K), BGRA(255, 255, 255, 120), taCenter, False);
end;

procedure TWaveGame.DrawHud(Bmp: TBGRABitmap);
var
  k, w, h, y: Single;
  f: TScreenFx;
  s: string;
  n: Integer;
  c: TBGRAPixel;
begin
  k := Bmp.Height / REF_HEIGHT;
  w := Bmp.Width; h := Bmp.Height;
  if FFlash > 0 then
    BlendRect(Bmp, 0, 0, Bmp.Width, Bmp.Height, BGRAWhite, Round(FFlash * 110));
  case State of
    gsLight:
      begin
        f := Fx(scLight);
        DimRect(Bmp, f.BgDim);
        DrawAmbient(Bmp, k, f.Particles);
        DrawLightLab(Bmp, f, k);
      end;
    gsMenu, gsLevels, gsOptions:
      begin
        f := Fx(ScreenFor(State));
        DimRect(Bmp, f.BgDim);
        DrawAmbient(Bmp, k, f.Particles);
        DrawScreenLight(Bmp, f, k);
        FDots.Draw(Bmp, f.Title, w / 2, f.TitleY * h, f.TitleSize, f, k, FTime);
        if f.Subtitle <> '' then
          FText.Draw(Bmp, w / 2, f.TitleY * h + f.TitleSize * k * 1.25, f.Subtitle, Round(26 * k), f.TextColor, taCenter, False);
        if State = gsLevels then DrawLevelList(Bmp, f, k) else DrawMenu(Bmp, f, k);
        if State = gsMenu then
          FText.Draw(Bmp, w / 2, h - 40 * k, 'Mouse / Arrows / WASD  -  Enter / Click  -  Esc back  -  F11 fullscreen',
            Round(15 * k), BGRA(130, 130, 140), taCenter, False);
        if FBannerTime > 0 then
        begin
          c := FBannerCol; c.alpha := Round(255 * Min(1, FBannerTime));
          FText.Draw(Bmp, w / 2, h * 0.92, FBanner, Round(28 * k), c, taCenter);
        end;
      end;
    gsReady:
      begin
        DrawHudPlay(Bmp, k);
        f := Fx(scReady);
        n := Ceil(FReadyT / 0.6);
        if n >= 4 then s := f.Title
        else if n >= 1 then s := IntToStr(n)
        else s := 'GO!';
        y := Frac(Max(0, FReadyT) / 0.6);
        FDots.Draw(Bmp, s, w / 2, f.TitleY * h, f.TitleSize * (0.9 + 0.2 * y), f, k, FTime, Round(255 * Min(1, y * 2 + 0.2)));
        DrawLevelCard(Bmp, k, 1);
      end;
    gsPlaying:
      begin
        DrawHudPlay(Bmp, k);
        { the level card fades out during the first second of play }
        if PlayTime < 1.2 then DrawLevelCard(Bmp, k, 1 - PlayTime / 1.2);
      end;
    gsPaused:
      begin
        DrawHudPlay(Bmp, k);
        f := Fx(scPause);
        DimRect(Bmp, f.BgDim);
        DrawScreenLight(Bmp, f, k);
        FDots.Draw(Bmp, f.Title, w / 2, f.TitleY * h, f.TitleSize, f, k, FTime);
        if f.Subtitle <> '' then
          FText.Draw(Bmp, w / 2, f.TitleY * h + f.TitleSize * k * 1.25, f.Subtitle, Round(24 * k), f.TextColor, taCenter, False);
        DrawMenu(Bmp, f, k);
        FText.Draw(Bmp, w / 2, h * 0.88, 'MAIN MENU keeps this run - choose CONTINUE to come back',
          Round(16 * k), BGRA(150, 150, 160), taCenter, False);
      end;
    gsGameOver, gsComplete:
      begin
        if State = gsGameOver then f := Fx(scGameOver) else f := Fx(scComplete);
        DimRect(Bmp, f.BgDim);
        DrawAmbient(Bmp, k, f.Particles);
        DrawScreenLight(Bmp, f, k);
        FDots.Draw(Bmp, f.Title, w / 2, f.TitleY * h, f.TitleSize, f, k, FTime);
        y := f.TitleY * h + f.TitleSize * k * 1.45;
        if State = gsComplete then
        begin
          DrawStarsRow(Bmp, w / 2, y + 30 * k, 26 * k, FStarsEarned, FMenuPhase);
          y := y + 70 * k;
        end;
        FText.Draw(Bmp, w / 2, y, IntToStr(Score), Round(86 * k), ColorForMode(CM_PEARL, BGRAWhite, FTime * 0.2), taCenter);
        if FLevel <= High(FBest) then
          s := Format('best %d     max combo x%d     %s', [FBest[FLevel], MaxCombo, Lv.Name])
        else
          s := '';
        FText.Draw(Bmp, w / 2, y + 108 * k, s, Round(22 * k), f.TextColor, taCenter, False);
        if FNewBest then
          FText.Draw(Bmp, w / 2, y + 146 * k, 'NEW BEST!', Round(34 * k), HueToColor(FTime * 0.9), taCenter);
        DrawMenu(Bmp, f, k);
        if FShow then DrawShowHud(Bmp, k);
      end;
  end;
end;

procedure TWaveGame.DrawLightLab(Bmp: TBGRABitmap; const F: TScreenFx; K: Single);
var
  i, focus: Integer;
  top, bh, w, h, y, cy: Single;
  c: TBGRAPixel;
  s: string;
begin
  w := Bmp.Width; h := Bmp.Height;
  FDots.Draw(Bmp, F.Title, w / 2, F.TitleY * h, F.TitleSize, F, K, FTime);
  if F.Subtitle <> '' then
    FText.Draw(Bmp, w / 2, F.TitleY * h + F.TitleSize * K * 1.2, F.Subtitle, Round(20 * K), F.TextColor, taCenter, False);
  focus := FSel;
  if LightLabFocus >= 0 then focus := LightLabFocus;
  bh := 0.19 * h;
  { glass + light of the four optics, each clipped to its own band }
  FLayer.Start(Bmp.Width, Bmp.Height);
  for i := 0 to 3 do
  begin
    top := (0.1 + i * 0.19) * h;
    if True then                                     { every optic is gameplay: cards, no showcase }
    begin
      if i = focus then
        BlendRect(Bmp, 0, Round(top), Bmp.Width, Round(top + bh - 2 * K), IriPaletteColor(3, FTime * 0.1, 0.5), 22);
      Continue;
    end;
    if i = focus then
      BlendRect(Bmp, 0, Round(top), Bmp.Width, Round(top + bh - 2 * K), IriPaletteColor(3, FTime * 0.1, 0.5), 22);
    cy := (0.1 + i * 0.19 + 0.07) * FieldH;
    BuildKindScene(FTmp, i, LightDef(i), FieldW * 0.56, cy, 60, FTime + i * 0.7);
    FTmp.DrawGlass(Bmp, K, 1, FTime);
    FLayer.SetClip(0, top, w, top + bh - 2 * K);
    if i = focus then FTmp.DrawLight(FLayer, K, 1.1) else FTmp.DrawLight(FLayer, K, 0.55);
  end;
  FLayer.NoClip;
  FLayer.Composite(Bmp);
  { labels under each optic, like a museum card }
  for i := 0 to 3 do
  begin
    top := (0.1 + i * 0.19) * h;
    y := top + bh * 0.72;
    s := EnumName(LIGHT_KINDS, i);
    if i = LK_GRATING then
    begin
      FText.Draw(Bmp, w / 2, top + bh * 0.22, 'DIFFRACTION GRATING  =  YOUR WEAPON', Round(22 * K),
        IriPaletteColor(3, FTime * 0.2, 1), taCenter);
      FText.Draw(Bmp, w / 2, top + bh * 0.42, 'collect Grating cells - hold LEFT MOUSE to charge white light',
        Round(16 * K), F.MenuColor, taCenter, False);
      FText.Draw(Bmp, w / 2, top + bh * 0.56, 'release: the grating splits it into colour rays that destroy hazards',
        Round(16 * K), F.MenuColor, taCenter, False);
      FText.Draw(Bmp, w / 2, top + bh * 0.72, Format('power stored  %.0f', [FPower]), Round(18 * K),
        BGRA(230, 230, 240), taCenter);
      Continue;
    end;
    if i = LK_NEWTON then
    begin
      FText.Draw(Bmp, w / 2, top + bh * 0.14, 'NEWTON''S PRISMS  =  GUARDIAN', Round(22 * K), IriPaletteColor(3, FTime * 0.2, 1), taCenter);
      FText.Draw(Bmp, w / 2, top + bh * 0.4, 'appears once your combo passes x3 - only one at a time',
        Round(15 * K), F.TextColor, taCenter, False);
      FText.Draw(Bmp, w / 2, top + bh * 0.53, 'it drifts after your cursor for 7 s and rams enemies for you',
        Round(15 * K), F.TextColor, taCenter, False);
      FText.Draw(Bmp, w / 2, top + bh * 0.66, 'more combo = stronger and longer, every hit weakens it',
        Round(15 * K), F.TextColor, taCenter, False);
      Continue;
    end;
    if i = LK_DIAMOND then
    begin
      FText.Draw(Bmp, w / 2, top + bh * 0.14, 'DIAMOND  =  BONUS ONLY', Round(22 * K), IriPaletteColor(3, FTime * 0.2, 1), taCenter);
      FText.Draw(Bmp, w / 2, top + bh * 0.4, 'catch the Diamond bonus: for 5 s a diamond above your ship',
        Round(15 * K), F.TextColor, taCenter, False);
      FText.Draw(Bmp, w / 2, top + bh * 0.53, 'turns your light into spectral fire that pulls every',
        Round(15 * K), F.TextColor, taCenter, False);
      FText.Draw(Bmp, w / 2, top + bh * 0.66, 'score item it touches into the ship',
        Round(15 * K), F.TextColor, taCenter, False);
      Continue;
    end;
    if i = LK_PRISM then
    begin
      if i = focus then FDots.Draw(Bmp, 'DISPERSION PRISM', w / 2, top + bh * 0.12, 28, F, K, FTime)
      else FText.Draw(Bmp, w / 2, top + bh * 0.14, 'DISPERSION PRISM', Round(22 * K), F.MenuColor, taCenter);
      FText.Draw(Bmp, w / 2, top + bh * 0.4, 'a sentinel prism follows your cursor slowly and drifts its own way',
        Round(15 * K), F.TextColor, taCenter, False);
      FText.Draw(Bmp, w / 2, top + bh * 0.53, 'it reads where you are heading and angles the white light so the',
        Round(15 * K), F.TextColor, taCenter, False);
      FText.Draw(Bmp, w / 2, top + bh * 0.66, 'refracted colour rays hit the enemy on your path first  (Spectrum bonus)',
        Round(15 * K), F.TextColor, taCenter, False);
    end
    else if i = focus then
      FDots.Draw(Bmp, s, w / 2, y - 4 * K, 30, F, K, FTime)
    else
      FText.Draw(Bmp, w / 2, y, s, Round(22 * K), F.MenuColor, taCenter, False);
    if i = LightMode then
    begin
      c := IriPaletteColor(3, FTime * 0.3, 1);
      FText.Draw(Bmp, w - 16 * K, top + 8 * K, 'BEAM', Round(18 * K), c, taRightJustify);
    end;
  end;
  { menu rows: ambient toggle + back }
  for i := 4 to High(FItems) do
  begin
    y := F.MenuY * h + (i - 4) * F.MenuSpacing * K;
    s := FItems[i].Caption;
    if FItems[i].Value <> '' then s := s + '   < ' + FItems[i].Value + ' >';
    if i = FSel then
      FText.Draw(Bmp, w / 2, y, s, Round(F.MenuSize * K * 1.05), ColorForMode(F.MenuSelMode, F.MenuColor, FTime * 0.3), taCenter)
    else
      FText.Draw(Bmp, w / 2, y, s, Round(F.MenuSize * K), F.MenuColor, taCenter);
  end;
  if FBannerTime > 0 then
  begin
    c := FBannerCol; c.alpha := Round(255 * Min(1, FBannerTime));
    FText.Draw(Bmp, w / 2, h * 0.965, FBanner, Round(20 * K), c, taCenter);
  end;
end;

end.

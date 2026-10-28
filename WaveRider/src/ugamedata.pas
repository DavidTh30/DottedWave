{ WaveRider game data: objects, levels, screen effects (+ SFX bank and song).

  Everything the game shows or plays is data. Files live in <data>/ :
    objects.ini  levels.ini  screens.ini  sfx.ini  music.ini
  Missing files fall back to the built-in defaults below, so the game always
  runs, and every editor in WaveRider Studio writes exactly these files. }
unit uGameData;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, IniFiles, BGRABitmapTypes, uParams, uSynth, uMusic, uLightFx, uAnime;

const
  ROLE_NAMES   = 'Collect|Hazard|Bonus';
  EFFECT_NAMES = 'Score|ClearHazards|Shield|Magnet|SlowMo|DoubleScore|ExtraLife|Fever|Nova|Damage|LightBeam|GratingPower|DiamondLight';
  MOTION_NAMES = 'Fall|Sine|ZigZag|Homing|Orbit|Fast|Drift';
  STYLE_NAMES  = 'Orb|Ring|Void|Triangle|Star|Pixel|Comet|Prism|Gem|Grating';
  CMODE_NAMES  = 'Fixed|HueCycle|Pearl|Holo|Oil|Rainbow|Beetle';
  DIFF_NAMES   = 'Easy|Normal|Hard|Expert|Insane';
  MESH_NAMES   = 'Original|Calm Silk|Storm|Dense Fabric|Sound Wave|Iridescent Pearl|Holographic|Oil Slick';
  PALETTE_NAMES = 'Rainbow|Pearl|Oil Slick|Holographic|Beetle|Mono';

  { roles }
  RL_COLLECT = 0; RL_HAZARD = 1; RL_BONUS = 2;
  { effects }
  EF_SCORE = 0; EF_CLEAR = 1; EF_SHIELD = 2; EF_MAGNET = 3; EF_SLOWMO = 4; EF_DOUBLE = 5;
  EF_LIFE = 6; EF_FEVER = 7; EF_NOVA = 8; EF_DAMAGE = 9; EF_BEAM = 10; EF_GRATING = 11; EF_DIAMOND = 12;
  { motions }
  MO_FALL = 0; MO_SINE = 1; MO_ZIGZAG = 2; MO_HOMING = 3; MO_ORBIT = 4; MO_FAST = 5; MO_DRIFT = 6;
  { styles }
  ST_ORB = 0; ST_RING = 1; ST_VOID = 2; ST_DIAMOND = 3; ST_STAR = 4; ST_PIXEL = 5; ST_COMET = 6;
  ST_PRISM = 7; ST_GEM = 8; ST_GRATING = 9;
  DATA_VERSION = 6;
  { color modes }
  CM_FIXED = 0; CM_HUE = 1; CM_PEARL = 2; CM_HOLO = 3; CM_OIL = 4; CM_RAINBOW = 5; CM_BEETLE = 6;

type
  TObjDef = record
    Name, Caption: string;
    Role, Effect, Motion, Style, ColorMode: Integer;
    Radius, Speed, MotionAmp, MotionFreq: Single;
    Score: Integer;
    Duration, Power: Single;
    Color1, Color2: TBGRAPixel;
    GlowSize, GlowAlpha, PulseRate, Spin: Single;
    WellRadius, WellHeight, WellDarken: Single;
    RingSpeed, RingWidth, RingStrength, RingDecay: Single;
    Particles: Integer;
    ParticleSpeed, ParticleSize: Single;
    Shake, Flash, MusicSweep: Single;
    Sfx: string;
    SfxPitch: Single;
    Letter: string;
    PixelArt: string;      { rows separated by '/': . empty, 1 color1, 2 color2, W white, K black }
    PixelScale: Single;
  end;
  TObjDefs = array of TObjDef;

  TLevelDef = record
    Name, Subtitle: string;
    Difficulty: Integer;
    MeshPreset: Integer;
    Lines: Integer;            { 0 = preset }
    Amplitude: Single;         { 0 = preset }
    IriBase: Single;
    IriPalette: Integer;
    Pixel: Boolean;
    PixelSize: Integer;
    Posterize: Integer;        { 0 = off, else levels per channel }
    BgColor, DotColor: TBGRAPixel;
    Vignette: Single;
    Duration: Single;          { s, 0 = endless }
    Star1, Star2, Star3: Integer;
    SpeedStart, SpeedEnd: Single;
    CollectRate, HazardRate, BonusRate, RateRamp, ChainChance: Single;
    CollectMix, HazardMix, BonusMix: string;
    MusicSection: Integer;
    Lives: Integer;
    LightScene: Integer;       { 0 none, 1.. = light kind + 1 (background optics) }
    LightX, LightY, LightScale, LightIntensity: Single;
    { anime: a character drawn by the dots of the mesh }
    Anime: Integer;            { 0 none, 1 Nova, 2 Kai, 3 Duo, 4 Image }
    AnimeImage: string;        { file in data/anime/ when Anime = Image }
    AnimeMix, AnimeX, AnimeY, AnimeScale, AnimePan: Single;
    AnimeCutIn: Boolean;
  end;
  TLevelDefs = array of TLevelDef;

  TScreenId = (scMain, scLevels, scOptions, scPause, scGameOver, scComplete, scHud, scReady, scLight);

  TScreenFx = record
    Title, Subtitle: string;
    TitleSize, TitleY: Single;
    DotSpacing, DotSize: Single;
    DotRound: Boolean;
    DotWave, DotWaveFreq, DotWaveSpeed: Single;
    Shimmer, ShimmerSpeed: Single;
    Palette: Integer;
    Saturation, HueSpeed, HueScale, Glow: Single;
    BgPreset: Integer;
    BgIri, BgDim, BgSpeed: Single;
    MenuY, MenuSize, MenuSpacing: Single;
    MenuColor: TBGRAPixel;
    MenuSelMode: Integer;      { color mode for the selected item }
    MenuDotted: Boolean;
    MenuGlow: Single;
    TextColor: TBGRAPixel;
    Particles: Integer;
    LightFx: Integer;          { 0 none, 1.. = light kind + 1 }
    LightX, LightY, LightSize, LightIntensity: Single;
  end;

  { TGameData }

  TGameData = class
  public
    DataDir: string;
    Objects: TObjDefs;
    Levels: TLevelDefs;
    Screens: array[TScreenId] of TScreenFx;
    Sfx: TSfxDefs;
    Song: TSong;
    Light: TLightDefs;
    constructor Create(const ADataDir: string);
    procedure LoadAll;
    procedure SaveAll;
    procedure LoadObjects; procedure SaveObjects;
    procedure LoadLevels; procedure SaveLevels;
    procedure LoadScreens; procedure SaveScreens;
    procedure LoadSfx; procedure SaveSfx;
    procedure LoadSong; procedure SaveSong;
    procedure LoadLight; procedure SaveLight;
    function LightFile: string;
    function FindObject(const AName: string): Integer;
    function FindLevel(const AName: string): Integer;
    function ObjectsFile: string;
    function LevelsFile: string;
    function ScreensFile: string;
    function SfxFile: string;
    function SongFile: string;
  end;

const
  SCREEN_KEYS: array[TScreenId] of string = ('Main', 'Levels', 'Options', 'Pause', 'GameOver', 'Complete', 'Hud', 'Ready', 'Light');
  SCREEN_NAMES: array[TScreenId] of string = ('Main menu', 'Level select', 'Options', 'Pause', 'Game over',
    'Level complete', 'HUD (in game)', 'Ready / countdown', 'Light lab');

function DefaultObject(const AName: string): TObjDef;
function DefaultObjects: TObjDefs;
function DefaultLevel: TLevelDef;
function DefaultLevels: TLevelDefs;
function DefaultScreen(AId: TScreenId): TScreenFx;
procedure DescribeObject(var B: TPBuilder; var O: TObjDef);
procedure DescribeLevel(var B: TPBuilder; var L: TLevelDef);
procedure DescribeScreen(var B: TPBuilder; var S: TScreenFx);
function FindDataDir: string;

implementation

function FindDataDir: string;
var
  exe: string;
begin
  exe := ExtractFilePath(ParamStr(0));
  { bin/ and studio/bin/ layouts both resolve to WaveRider/data }
  if DirectoryExists(exe + '..' + PathDelim + 'data') then
    Result := ExpandFileName(exe + '..' + PathDelim + 'data') + PathDelim
  else if DirectoryExists(exe + '..' + PathDelim + '..' + PathDelim + 'data') then
    Result := ExpandFileName(exe + '..' + PathDelim + '..' + PathDelim + 'data') + PathDelim
  else
    Result := exe + 'data' + PathDelim;
end;

{ ---------------- objects ---------------- }

function DefaultObject(const AName: string): TObjDef;
begin
  Result := Default(TObjDef);
  Result.Name := AName;
  Result.Caption := UpperCase(AName);
  Result.Role := RL_COLLECT;
  Result.Effect := EF_SCORE;
  Result.Motion := MO_FALL;
  Result.Style := ST_ORB;
  Result.ColorMode := CM_HUE;
  Result.Radius := 14;
  Result.Speed := 1;
  Result.MotionAmp := 20;
  Result.MotionFreq := 2;
  Result.Score := 10;
  Result.Duration := 8;
  Result.Power := 1;
  Result.Color1 := BGRA(255, 255, 255);
  Result.Color2 := BGRA(120, 200, 255);
  Result.GlowSize := 34;
  Result.GlowAlpha := 1;
  Result.PulseRate := 8;
  Result.WellRadius := 28;
  Result.WellHeight := 0.3;
  Result.WellDarken := -1.2;
  Result.RingSpeed := 520;
  Result.RingWidth := 26;
  Result.RingStrength := 0.55;
  Result.RingDecay := 2.2;
  Result.Particles := 14;
  Result.ParticleSpeed := 260;
  Result.ParticleSize := 3;
  Result.Sfx := 'collect';
  Result.SfxPitch := 1;
  Result.PixelScale := 4;
end;

function DefaultObjects: TObjDefs;

  procedure Add(const O: TObjDef);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := O;
  end;

var
  o: TObjDef;
begin
  Result := nil;
  { ---- collectibles ---- }
  o := DefaultObject('Spark'); o.Caption := 'SPARK'; o.Motion := MO_SINE; o.MotionAmp := 18; o.MotionFreq := 2.2;
  o.Radius := 13;
  Add(o);

  o := DefaultObject('Prism'); o.Caption := 'PRISM'; o.Score := 40; o.Motion := MO_ZIGZAG; o.MotionAmp := 70;
  o.MotionFreq := 1.4; o.Style := ST_DIAMOND; o.ColorMode := CM_HOLO; o.Radius := 15; o.Speed := 1.15;
  o.Sfx := 'prism'; o.GlowSize := 40; o.Particles := 22; o.RingStrength := 0.7; o.Spin := 2;
  Add(o);

  o := DefaultObject('Coin'); o.Caption := 'COIN'; o.Score := 20; o.Style := ST_PIXEL; o.ColorMode := CM_FIXED;
  o.Color1 := BGRA(255, 200, 40); o.Color2 := BGRA(170, 100, 10); o.Motion := MO_SINE; o.MotionAmp := 10;
  o.PixelArt := '..1111../.122221./12W22221/12W22221/12222221/12222221/.122221./..1111..';
  o.PixelScale := 4; o.GlowSize := 26; o.Sfx := 'collect'; o.SfxPitch := 1.2; o.Radius := 15;
  Add(o);

  { ---- hazards ---- }
  o := DefaultObject('Void'); o.Caption := 'VOID'; o.Role := RL_HAZARD; o.Effect := EF_DAMAGE; o.Style := ST_VOID;
  o.Motion := MO_DRIFT; o.MotionAmp := 40; o.MotionFreq := 0.9; o.Radius := 27; o.Speed := 0.85;
  o.ColorMode := CM_HUE; o.WellRadius := 84; o.WellHeight := -1.5; o.WellDarken := 0.92; o.Score := 0;
  o.Particles := 18; o.Sfx := 'hit'; o.GlowSize := 0; o.Shake := 1; o.Flash := 0.6;
  o.RingSpeed := 380; o.RingWidth := 30; o.RingStrength := 0.7; o.RingDecay := 2;
  Add(o);

  o := DefaultObject('Seeker'); o.Caption := 'SEEKER'; o.Role := RL_HAZARD; o.Effect := EF_DAMAGE;
  o.Style := ST_VOID; o.Motion := MO_HOMING; o.Power := 140; o.Radius := 22; o.Speed := 0.7;
  o.ColorMode := CM_FIXED; o.Color1 := BGRA(255, 60, 80); o.WellRadius := 66; o.WellHeight := -1.2;
  o.WellDarken := 0.85; o.Score := 0; o.Sfx := 'hit'; o.GlowSize := 30; o.Shake := 1; o.Flash := 0.6;
  Add(o);

  o := DefaultObject('Comet'); o.Caption := 'COMET'; o.Role := RL_HAZARD; o.Effect := EF_DAMAGE;
  o.Style := ST_COMET; o.Motion := MO_FAST; o.Speed := 2.3; o.Radius := 13; o.ColorMode := CM_FIXED;
  o.Color1 := BGRA(200, 230, 255); o.WellRadius := 40; o.WellHeight := 0.8; o.WellDarken := -1.5;
  o.Score := 0; o.Sfx := 'hit'; o.GlowSize := 36; o.Shake := 0.8; o.Flash := 0.5;
  Add(o);

  o := DefaultObject('Twin'); o.Caption := 'TWIN'; o.Role := RL_HAZARD; o.Effect := EF_DAMAGE;
  o.Style := ST_VOID; o.Motion := MO_ORBIT; o.MotionAmp := 55; o.MotionFreq := 2.4; o.Radius := 18;
  o.Speed := 0.8; o.WellRadius := 56; o.WellHeight := -1.2; o.WellDarken := 0.9; o.Score := 0;
  o.Sfx := 'hit'; o.GlowSize := 0; o.Shake := 1; o.Flash := 0.6; o.ColorMode := CM_OIL;
  Add(o);

  o := DefaultObject('Glitch'); o.Caption := 'GLITCH'; o.Role := RL_HAZARD; o.Effect := EF_DAMAGE;
  o.Style := ST_PIXEL; o.Motion := MO_ZIGZAG; o.MotionAmp := 50; o.MotionFreq := 1.8; o.Radius := 18;
  o.ColorMode := CM_FIXED; o.Color1 := BGRA(255, 40, 90); o.Color2 := BGRA(90, 0, 40);
  o.PixelArt := '.111111./11111111/1KK11KK1/1KK11KK1/11111111/111KK111/.1.11.1./.1....1.';
  o.WellRadius := 50; o.WellHeight := -1.0; o.WellDarken := 0.6; o.Score := 0; o.Sfx := 'hit';
  o.GlowSize := 24; o.Shake := 1; o.Flash := 0.6;
  Add(o);

  { ---- bonuses ---- }
  o := DefaultObject('Pulse'); o.Caption := 'PULSE'; o.Role := RL_BONUS; o.Effect := EF_CLEAR; o.Style := ST_RING;
  o.Letter := 'P'; o.Score := 50; o.Radius := 18; o.ColorMode := CM_HUE; o.WellRadius := 45; o.WellHeight := 0.6;
  o.WellDarken := -1.8; o.RingSpeed := 1100; o.RingWidth := 60; o.RingStrength := 1.1; o.RingDecay := 1;
  o.Particles := 40; o.ParticleSpeed := 600; o.Flash := 0.35; o.Shake := 0.4; o.Sfx := 'pulse'; o.MusicSweep := 1;
  Add(o);

  o := DefaultObject('Shield'); o.Caption := 'SHIELD'; o.Role := RL_BONUS; o.Effect := EF_SHIELD; o.Style := ST_RING;
  o.Letter := 'S'; o.Duration := 8; o.Score := 25; o.ColorMode := CM_FIXED; o.Color1 := BGRA(80, 220, 255);
  o.Sfx := 'shield'; o.MusicSweep := 0.6; o.Radius := 17;
  Add(o);

  o := DefaultObject('Magnet'); o.Caption := 'MAGNET'; o.Role := RL_BONUS; o.Effect := EF_MAGNET; o.Style := ST_RING;
  o.Letter := 'M'; o.Duration := 8; o.Power := 280; o.Score := 25; o.ColorMode := CM_FIXED;
  o.Color1 := BGRA(255, 80, 220); o.Sfx := 'magnet'; o.MusicSweep := 0.6; o.Radius := 17;
  Add(o);

  o := DefaultObject('SlowMo'); o.Caption := 'SLOW-MO'; o.Role := RL_BONUS; o.Effect := EF_SLOWMO; o.Style := ST_RING;
  o.Letter := 'T'; o.Duration := 6; o.Power := 0.55; o.Score := 25; o.ColorMode := CM_FIXED;
  o.Color1 := BGRA(90, 140, 255); o.Sfx := 'slowmo'; o.MusicSweep := 0.4; o.Radius := 17;
  Add(o);

  o := DefaultObject('Double'); o.Caption := 'DOUBLE SCORE'; o.Role := RL_BONUS; o.Effect := EF_DOUBLE;
  o.Style := ST_RING; o.Letter := '2x'; o.Duration := 10; o.Power := 2; o.Score := 25; o.ColorMode := CM_FIXED;
  o.Color1 := BGRA(255, 200, 40); o.Sfx := 'double'; o.MusicSweep := 0.7; o.Radius := 17;
  Add(o);

  o := DefaultObject('OneUp'); o.Caption := '1-UP'; o.Role := RL_BONUS; o.Effect := EF_LIFE; o.Style := ST_PIXEL;
  o.ColorMode := CM_FIXED; o.Color1 := BGRA(90, 255, 140); o.Color2 := BGRA(20, 120, 60); o.Score := 100;
  o.PixelArt := '.11..11./11111111/1W111111/11111111/.111111./..1111../...11...';
  o.Sfx := 'life'; o.MusicSweep := 0.8; o.Radius := 16;
  Add(o);

  o := DefaultObject('Star'); o.Caption := 'STAR'; o.Role := RL_BONUS; o.Effect := EF_SCORE; o.Style := ST_STAR;
  o.Score := 500; o.ColorMode := CM_PEARL; o.Color1 := BGRA(255, 230, 120); o.Spin := 1.5; o.Radius := 18;
  o.GlowSize := 48; o.Particles := 40; o.ParticleSpeed := 500; o.Sfx := 'star'; o.MusicSweep := 0.8;
  o.RingStrength := 0.9; o.RingSpeed := 800;
  Add(o);

  o := DefaultObject('Fever'); o.Caption := 'FEVER'; o.Role := RL_BONUS; o.Effect := EF_FEVER; o.Style := ST_STAR;
  o.Letter := 'F'; o.Duration := 6; o.Score := 100; o.ColorMode := CM_RAINBOW; o.Spin := 3; o.Radius := 18;
  o.GlowSize := 52; o.Particles := 50; o.Sfx := 'fever'; o.MusicSweep := 1; o.Flash := 0.3;
  Add(o);

  o := DefaultObject('Nova'); o.Caption := 'NOVA'; o.Role := RL_BONUS; o.Effect := EF_NOVA; o.Style := ST_PIXEL;
  o.ColorMode := CM_FIXED; o.Color1 := BGRA(255, 120, 40); o.Color2 := BGRA(255, 240, 120); o.Score := 150;
  o.PixelArt := '...11.../..1221../.122221./12222221/12222221/.122221./..1221../...11...';
  o.RingSpeed := 1300; o.RingWidth := 80; o.RingStrength := 1.4; o.RingDecay := 0.9; o.Particles := 70;
  o.ParticleSpeed := 800; o.Flash := 0.6; o.Shake := 0.8; o.Sfx := 'nova'; o.MusicSweep := 1; o.Radius := 17;
  Add(o);

  { ---- grating power units: collect them to charge the grating weapon ---- }
  o := DefaultObject('GratingCell'); o.Caption := 'GRATING'; o.Effect := EF_GRATING; o.Style := ST_GRATING;
  o.Power := 1; o.Score := 5; o.ColorMode := CM_HOLO; o.Motion := MO_SINE; o.MotionAmp := 14; o.MotionFreq := 2.6;
  o.Radius := 13; o.GlowSize := 30; o.Particles := 10; o.Sfx := 'collect'; o.SfxPitch := 1.45;
  o.RingStrength := 0.35;
  Add(o);

  { ---- diamond light: 5 s of spectral fire that pulls score items in ---- }
  o := DefaultObject('Diamond'); o.Caption := 'DIAMOND LIGHT'; o.Role := RL_BONUS; o.Effect := EF_DIAMOND;
  o.Style := ST_GEM; o.Letter := ''; o.Duration := 5; o.Power := 1; o.Score := 40; o.ColorMode := CM_PEARL;
  o.Spin := 1.6; o.Radius := 18; o.GlowSize := 50; o.Particles := 40; o.ParticleSpeed := 520; o.Flash := 0.3;
  o.Sfx := 'prism'; o.SfxPitch := 0.8; o.MusicSweep := 1; o.RingStrength := 0.9; o.RingSpeed := 900;
  Add(o);

  { ---- light ---- }
  o := DefaultObject('Spectrum'); o.Caption := 'LIGHT BEAM'; o.Role := RL_BONUS; o.Effect := EF_BEAM;
  o.Style := ST_PRISM; o.Duration := 5; o.Score := 50; o.ColorMode := CM_HOLO; o.Spin := 1.2; o.Radius := 18;
  o.GlowSize := 46; o.Particles := 36; o.ParticleSpeed := 520; o.Flash := 0.4; o.Sfx := 'beam'; o.MusicSweep := 1;
  o.RingStrength := 0.9; o.RingSpeed := 900;
  Add(o);

  o := DefaultObject('Gem'); o.Caption := 'GEM'; o.Score := 60; o.Style := ST_STAR; o.ColorMode := CM_PEARL;
  o.Motion := MO_SINE; o.MotionAmp := 30; o.MotionFreq := 1.6; o.Spin := 1.4; o.Radius := 15; o.GlowSize := 38;
  o.Particles := 24; o.Sfx := 'prism'; o.SfxPitch := 1.15;
  Add(o);
end;

procedure DescribeObject(var B: TPBuilder; var O: TObjDef);
begin
  B.G('Identity');
  B.S('name', 'Name (id)', @O.Name, 'Referenced by levels (spawn mixes)');
  B.S('caption', 'Caption', @O.Caption, 'Shown in the HUD when picked up');
  B.E('role', 'Role', @O.Role, ROLE_NAMES);
  B.E('effect', 'Effect', @O.Effect, EFFECT_NAMES);
  B.I('score', 'Score', @O.Score, 0, 100000);
  B.F('duration', 'Duration (s)', @O.Duration, 0, 60, 1, 'Timed bonuses: shield, magnet, slow-mo, double, fever');
  B.F('power', 'Power', @O.Power, 0, 2000, 2, 'Magnet radius / slow-mo factor / score multiplier / homing speed');
  B.G('Motion');
  B.E('motion', 'Motion', @O.Motion, MOTION_NAMES);
  B.F('speed', 'Fall speed x', @O.Speed, 0.1, 4, 2);
  B.F('motionAmp', 'Motion amplitude', @O.MotionAmp, 0, 300, 1);
  B.F('motionFreq', 'Motion frequency', @O.MotionFreq, 0, 10, 2);
  B.F('radius', 'Radius', @O.Radius, 4, 80, 1, 'Collision radius (reference px)');
  B.G('Look');
  B.E('style', 'Style', @O.Style, STYLE_NAMES);
  B.E('colorMode', 'Color mode', @O.ColorMode, CMODE_NAMES);
  B.C('color1', 'Color 1', @O.Color1);
  B.C('color2', 'Color 2', @O.Color2);
  B.S('letter', 'Letter', @O.Letter, 'Drawn in the center (bonuses)');
  B.F('glowSize', 'Glow size', @O.GlowSize, 0, 120, 1);
  B.F('glowAlpha', 'Glow strength', @O.GlowAlpha, 0, 2, 2);
  B.F('pulseRate', 'Pulse rate', @O.PulseRate, 0, 30, 1);
  B.F('spin', 'Spin', @O.Spin, -10, 10, 2);
  B.S('pixelArt', 'Pixel art', @O.PixelArt, 'Rows split by "/": . empty, 1 color1, 2 color2, W white, K black');
  B.F('pixelScale', 'Pixel scale', @O.PixelScale, 1, 12, 1);
  B.G('Surface effect (mesh)');
  B.F('wellRadius', 'Well radius', @O.WellRadius, 0, 300, 1, 'Deformation of the dotted surface around the object');
  B.F('wellHeight', 'Well height', @O.WellHeight, -3, 3, 2, 'Negative = pit, positive = bump');
  B.F('wellDarken', 'Well darken', @O.WellDarken, -3, 1, 2, 'Positive swallows light, negative makes dots glow');
  B.G('Pickup / hit effect');
  B.F('ringSpeed', 'Ring speed', @O.RingSpeed, 0, 2000, 0);
  B.F('ringWidth', 'Ring width', @O.RingWidth, 5, 200, 1);
  B.F('ringStrength', 'Ring strength', @O.RingStrength, -3, 3, 2);
  B.F('ringDecay', 'Ring decay', @O.RingDecay, 0.2, 6, 2);
  B.I('particles', 'Particles', @O.Particles, 0, 200);
  B.F('particleSpeed', 'Particle speed', @O.ParticleSpeed, 0, 1500, 0);
  B.F('particleSize', 'Particle size', @O.ParticleSize, 1, 12, 1);
  B.F('shake', 'Screen shake', @O.Shake, 0, 2, 2);
  B.F('flash', 'Screen flash', @O.Flash, 0, 1, 2);
  B.F('musicSweep', 'Music sweep', @O.MusicSweep, 0, 1, 2, 'Filter sweep + echo throw in the music');
  B.S('sfx', 'Sound', @O.Sfx, 'Name in sfx.ini');
  B.F('sfxPitch', 'Sound pitch', @O.SfxPitch, 0.25, 4, 2);
end;

{ ---------------- levels ---------------- }

function DefaultLevel: TLevelDef;
begin
  Result := Default(TLevelDef);
  Result.Name := 'New Level';
  Result.Subtitle := '';
  Result.Difficulty := 1;
  Result.MeshPreset := 0;
  Result.IriBase := 0;
  Result.IriPalette := 0;
  Result.PixelSize := 4;
  Result.BgColor := BGRA(0, 0, 0);
  Result.DotColor := BGRA(242, 242, 242);
  Result.Vignette := 0.45;
  Result.Duration := 60;
  Result.Star1 := 1000; Result.Star2 := 2500; Result.Star3 := 5000;
  Result.SpeedStart := 240; Result.SpeedEnd := 420;
  Result.CollectRate := 1.4; Result.HazardRate := 0.5; Result.BonusRate := 0.05; Result.RateRamp := 1.8;
  Result.ChainChance := 0.25;
  Result.CollectMix := 'Spark:1';
  Result.HazardMix := 'Void:1';
  Result.BonusMix := 'Pulse:1';
  Result.MusicSection := 1;
  Result.Lives := 3;
  Result.LightScene := 0;
  Result.LightX := 0.5;
  Result.LightY := 0.32;
  Result.LightScale := 110;
  Result.LightIntensity := 0.55;
  Result.Anime := 0;
  Result.AnimeMix := 0.9;
  Result.AnimeX := 0.5;
  Result.AnimeY := 0.5;
  Result.AnimeScale := 0.78;
  Result.AnimePan := 1;
  Result.AnimeCutIn := True;
end;

procedure ApplyLightDefaults(var L: TLevelDef; AScene: Boolean);
begin
  { light scene behind some levels }
  if AScene then
  begin
    if SameText(L.Name, 'Pearl Drift') then begin L.LightScene := 0; end
    else if SameText(L.Name, 'Holo Rush') then begin L.LightScene := 0; end
    else if SameText(L.Name, 'Oil Slick') then begin L.LightScene := 0; end
    else if SameText(L.Name, 'Neon Arcade') then begin L.LightScene := 0; end
    else if SameText(L.Name, 'The Maelstrom') then begin L.LightScene := 0; end
    else if SameText(L.Name, 'Endless') then begin L.LightScene := 0; end;
  end;
  { the diffraction grating is a weapon now, never a static backdrop }
  L.LightScene := 0;   { every optic has a gameplay role now: none is scenery }
  { grating power units in every level }
  if Pos('gratingcell', LowerCase(L.CollectMix)) = 0 then
    L.CollectMix := Trim(L.CollectMix + ' GratingCell:2');
  { light bonus / gem from Normal difficulty up }
  if Pos('diamond', LowerCase(L.BonusMix)) = 0 then
    L.BonusMix := Trim(L.BonusMix + ' Diamond:1');
  if (L.Difficulty >= 1) and (Pos('spectrum', LowerCase(L.BonusMix)) = 0) then
    L.BonusMix := Trim(L.BonusMix + ' Spectrum:1');
  if (L.Difficulty >= 2) and (Pos('gem', LowerCase(L.CollectMix)) = 0) then
    L.CollectMix := Trim(L.CollectMix + ' Gem:1');
end;

function DefaultLevels: TLevelDefs;

  procedure Add(const L: TLevelDef);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := L;
  end;

var
  l: TLevelDef;
  i: Integer;
begin
  Result := nil;

  l := DefaultLevel; l.Name := 'Calm Waters'; l.Subtitle := 'Learn to ride the dots'; l.Difficulty := 0;
  l.MeshPreset := 0; l.Duration := 45; l.SpeedStart := 200; l.SpeedEnd := 300; l.HazardRate := 0.3;
  l.BonusMix := 'Pulse:2 Shield:1 Star:1'; l.Star1 := 600; l.Star2 := 1500; l.Star3 := 3000; l.MusicSection := 0;
  Add(l);

  l := DefaultLevel; l.Name := 'Pearl Drift'; l.Subtitle := 'Combo lights up the pearl'; l.Difficulty := 0;
  l.MeshPreset := 5; l.IriBase := 0.3; l.IriPalette := 1; l.Duration := 60; l.SpeedStart := 220; l.SpeedEnd := 340;
  l.CollectMix := 'Spark:5 Prism:1 Gem:1'; l.BonusMix := 'Pulse:2 Shield:1 Star:1 Double:1 Spectrum:1';
  l.Star1 := 1200; l.Star2 := 3000; l.Star3 := 6000; l.MusicSection := 1;
  l.LightScene := 0;
  Add(l);

  l := DefaultLevel; l.Name := '8-Bit Tide'; l.Subtitle := 'Pixel art waves'; l.Difficulty := 1;
  l.MeshPreset := 4; l.Pixel := True; l.PixelSize := 4; l.Posterize := 4; l.IriBase := 0.2; l.IriPalette := 0;
  l.Duration := 60; l.SpeedStart := 240; l.SpeedEnd := 380;
  l.CollectMix := 'Coin:4 Spark:1'; l.HazardMix := 'Glitch:2 Void:1'; l.BonusMix := 'OneUp:1 Pulse:2 Double:1';
  l.BgColor := BGRA(6, 4, 20); l.DotColor := BGRA(140, 220, 255); l.MusicSection := 2;
  l.Star1 := 1200; l.Star2 := 3000; l.Star3 := 6000;
  Add(l);

  l := DefaultLevel; l.Name := 'Silk Storm'; l.Subtitle := 'Seekers hunt the light'; l.Difficulty := 1;
  l.MeshPreset := 1; l.Amplitude := 110; l.Duration := 75; l.SpeedStart := 260; l.SpeedEnd := 440;
  l.HazardRate := 0.6; l.HazardMix := 'Void:3 Seeker:1'; l.BonusMix := 'Pulse:2 Shield:2 Magnet:1 Star:1';
  l.CollectMix := 'Spark:6 Prism:1'; l.MusicSection := 2; l.Star1 := 2000; l.Star2 := 4500; l.Star3 := 8000;
  Add(l);

  l := DefaultLevel; l.Name := 'Holo Rush'; l.Subtitle := 'Comets incoming'; l.Difficulty := 2;
  l.MeshPreset := 6; l.IriBase := 0.6; l.IriPalette := 3; l.Duration := 75; l.SpeedStart := 300; l.SpeedEnd := 520;
  l.HazardRate := 0.75; l.HazardMix := 'Void:2 Comet:2 Seeker:1'; l.CollectMix := 'Spark:4 Prism:2';
  l.BonusMix := 'Pulse:2 Shield:1 Magnet:1 SlowMo:1 Double:1 Star:1'; l.BgColor := BGRA(5, 2, 10);
  l.MusicSection := 5; l.Star1 := 2500; l.Star2 := 6000; l.Star3 := 11000;
  Add(l);

  l := DefaultLevel; l.Name := 'Pixel Abyss'; l.Subtitle := 'Glitches in the dark'; l.Difficulty := 2;
  l.MeshPreset := 0; l.Pixel := True; l.PixelSize := 5; l.Posterize := 3; l.Duration := 80;
  l.SpeedStart := 280; l.SpeedEnd := 500; l.HazardRate := 0.8; l.HazardMix := 'Glitch:3 Void:2 Twin:1';
  l.CollectMix := 'Coin:3 Spark:2'; l.BonusMix := 'OneUp:1 Pulse:2 Shield:1 SlowMo:1 Nova:1';
  l.DotColor := BGRA(255, 120, 200); l.BgColor := BGRA(10, 0, 12); l.MusicSection := 3;
  l.Star1 := 2500; l.Star2 := 6000; l.Star3 := 10000;
  Add(l);

  l := DefaultLevel; l.Name := 'Oil Slick'; l.Subtitle := 'Twin voids orbit'; l.Difficulty := 2;
  l.MeshPreset := 7; l.IriBase := 0.7; l.IriPalette := 2; l.Duration := 90; l.SpeedStart := 300; l.SpeedEnd := 560;
  l.HazardRate := 0.8; l.HazardMix := 'Void:2 Twin:2 Seeker:1'; l.CollectMix := 'Spark:4 Prism:2';
  l.BonusMix := 'Pulse:2 Shield:1 Magnet:1 Fever:1 Double:1'; l.BgColor := BGRA(3, 3, 6); l.MusicSection := 5;
  l.Star1 := 3000; l.Star2 := 7000; l.Star3 := 13000;
  Add(l);

  l := DefaultLevel; l.Name := 'Dense Fabric'; l.Subtitle := 'Threads of danger'; l.Difficulty := 3;
  l.MeshPreset := 3; l.Duration := 90; l.SpeedStart := 340; l.SpeedEnd := 620; l.HazardRate := 1.0;
  l.HazardMix := 'Void:2 Seeker:2 Comet:2 Twin:1'; l.CollectMix := 'Spark:3 Prism:2';
  l.BonusMix := 'Pulse:2 Shield:2 SlowMo:1 Fever:1 OneUp:1 Nova:1'; l.MusicSection := 6;
  l.Star1 := 4000; l.Star2 := 9000; l.Star3 := 16000;
  Add(l);

  l := DefaultLevel; l.Name := 'Neon Arcade'; l.Subtitle := '8-bit at full speed'; l.Difficulty := 3;
  l.MeshPreset := 6; l.Pixel := True; l.PixelSize := 3; l.Posterize := 5; l.IriBase := 0.9; l.IriPalette := 0;
  l.Duration := 90; l.SpeedStart := 380; l.SpeedEnd := 680; l.HazardRate := 1.1;
  l.HazardMix := 'Glitch:3 Comet:2 Seeker:1'; l.CollectMix := 'Coin:3 Prism:1';
  l.BonusMix := 'OneUp:1 Pulse:2 Fever:1 Double:1 Nova:1 Magnet:1'; l.MusicSection := 7;
  l.Star1 := 5000; l.Star2 := 11000; l.Star3 := 20000;
  Add(l);

  l := DefaultLevel; l.Name := 'The Maelstrom'; l.Subtitle := 'Everything, all at once'; l.Difficulty := 4;
  l.MeshPreset := 2; l.Amplitude := 170; l.IriBase := 0.4; l.IriPalette := 2; l.Duration := 120;
  l.SpeedStart := 420; l.SpeedEnd := 760; l.HazardRate := 1.3; l.RateRamp := 2.2;
  l.HazardMix := 'Void:3 Seeker:2 Comet:2 Twin:2 Glitch:1'; l.CollectMix := 'Spark:3 Prism:2 Coin:1';
  l.BonusMix := 'Pulse:2 Shield:2 Magnet:1 SlowMo:1 Double:1 OneUp:1 Fever:1 Nova:1 Star:1';
  l.MusicSection := 7; l.Star1 := 8000; l.Star2 := 18000; l.Star3 := 32000;
  Add(l);

  { ---- anime levels: original characters drawn by the dotted mesh ---- }
  l := DefaultLevel; l.Name := 'Anime Rush'; l.Subtitle := 'Chibi party on the dots'; l.Difficulty := 1;
  l.MeshPreset := 3; l.Lines := 170; l.Amplitude := 45; l.Anime := AN_PARTY; l.AnimeScale := 0.62; l.AnimeY := 0.42;
  l.BgColor := BGRA(6, 4, 14); l.DotColor := BGRA(230, 225, 255); l.IriBase := 0.15; l.IriPalette := 1;
  l.Duration := 70; l.SpeedStart := 240; l.SpeedEnd := 400; l.HazardRate := 0.55;
  l.CollectMix := 'Spark:5 Prism:1 GratingCell:2'; l.HazardMix := 'Void:3 Seeker:1';
  l.BonusMix := 'Pulse:2 Shield:1 Star:1 Spectrum:1'; l.MusicSection := 2;
  l.Star1 := 2000; l.Star2 := 4500; l.Star3 := 8000;
  Add(l);

  l := DefaultLevel; l.Name := 'Neon Idol'; l.Subtitle := 'Neko steals the show'; l.Difficulty := 2;
  l.MeshPreset := 3; l.Lines := 170; l.Amplitude := 50; l.Anime := AN_NEKO; l.AnimeScale := 0.72; l.AnimeY := 0.45;
  l.BgColor := BGRA(14, 2, 16); l.DotColor := BGRA(255, 220, 240); l.IriBase := 0.3; l.IriPalette := 3;
  l.Duration := 80; l.SpeedStart := 300; l.SpeedEnd := 520; l.HazardRate := 0.8;
  l.CollectMix := 'Spark:4 Gem:1 GratingCell:2'; l.HazardMix := 'Void:2 Comet:2 Twin:1';
  l.BonusMix := 'Pulse:2 Fever:1 Double:1 Spectrum:1 Star:1'; l.MusicSection := 5;
  l.Star1 := 3000; l.Star2 := 7000; l.Star3 := 12000;
  Add(l);

  l := DefaultLevel; l.Name := 'Blade Wind'; l.Subtitle := 'Ao says peace!'; l.Difficulty := 3;
  l.MeshPreset := 3; l.Lines := 170; l.Amplitude := 60; l.Anime := AN_AO; l.AnimeScale := 0.72; l.AnimeY := 0.45;
  l.BgColor := BGRA(2, 10, 16); l.DotColor := BGRA(210, 255, 250); l.IriBase := 0.25; l.IriPalette := 2;
  l.Duration := 90; l.SpeedStart := 340; l.SpeedEnd := 640; l.HazardRate := 1.05;
  l.CollectMix := 'Spark:3 Prism:2 GratingCell:2'; l.HazardMix := 'Void:2 Seeker:2 Comet:2 Glitch:1';
  l.BonusMix := 'Pulse:2 Shield:2 SlowMo:1 Nova:1 Spectrum:1'; l.MusicSection := 7;
  l.Star1 := 4000; l.Star2 := 9000; l.Star3 := 16000;
  Add(l);

  l := DefaultLevel; l.Name := 'Endless'; l.Subtitle := 'How long can you ride?'; l.Difficulty := 4;
  l.MeshPreset := 5; l.IriBase := 0.2; l.IriPalette := 1; l.Duration := 0; l.SpeedStart := 260; l.SpeedEnd := 820;
  l.RateRamp := 3; l.HazardRate := 0.6;
  l.HazardMix := 'Void:3 Seeker:2 Comet:2 Twin:1 Glitch:1'; l.CollectMix := 'Spark:4 Prism:1 Coin:1';
  l.BonusMix := 'Pulse:2 Shield:2 Magnet:1 SlowMo:1 Double:1 OneUp:1 Fever:1 Nova:1 Star:1';
  l.MusicSection := 1; l.Star1 := 5000; l.Star2 := 15000; l.Star3 := 40000;
  Add(l);
  for i := 0 to High(Result) do ApplyLightDefaults(Result[i], True);
end;

procedure DescribeLevel(var B: TPBuilder; var L: TLevelDef);
begin
  B.G('Level');
  B.S('name', 'Name', @L.Name);
  B.S('subtitle', 'Subtitle', @L.Subtitle);
  B.E('difficulty', 'Difficulty', @L.Difficulty, DIFF_NAMES);
  B.F('duration', 'Duration (s)', @L.Duration, 0, 900, 0, '0 = endless');
  B.I('lives', 'Lives', @L.Lives, 1, 9);
  B.I('star1', 'Score for 1 star', @L.Star1, 0, 1000000);
  B.I('star2', 'Score for 2 stars', @L.Star2, 0, 1000000);
  B.I('star3', 'Score for 3 stars', @L.Star3, 0, 1000000);
  B.G('Style');
  B.E('mesh', 'Mesh preset', @L.MeshPreset, MESH_NAMES);
  B.I('lines', 'Lines override', @L.Lines, 0, 300, '0 = keep preset');
  B.F('amplitude', 'Amplitude override', @L.Amplitude, 0, 250, 1, '0 = keep preset');
  B.F('iriBase', 'Base iridescence', @L.IriBase, 0, 1, 2, 'Combo adds on top');
  B.E('iriPalette', 'Iridescent palette', @L.IriPalette, PALETTE_NAMES);
  B.C('bg', 'Background', @L.BgColor);
  B.C('dots', 'Dot color', @L.DotColor);
  B.F('vignette', 'Vignette', @L.Vignette, 0, 1.5, 2);
  B.B('pixel', 'Pixel art mode', @L.Pixel);
  B.I('pixelSize', 'Pixel size', @L.PixelSize, 2, 12);
  B.I('posterize', 'Posterize levels', @L.Posterize, 0, 16, '0 = off. Low values = retro palette');
  B.G('Pace');
  B.F('speedStart', 'Speed start', @L.SpeedStart, 50, 1200, 0, 'Surface flow, reference px / s');
  B.F('speedEnd', 'Speed end', @L.SpeedEnd, 50, 1500, 0);
  B.F('collectRate', 'Collectibles / s', @L.CollectRate, 0, 8, 2);
  B.F('hazardRate', 'Hazards / s', @L.HazardRate, 0, 8, 2);
  B.F('bonusRate', 'Bonuses / s', @L.BonusRate, 0, 2, 3);
  B.F('rateRamp', 'Rate ramp (x at end)', @L.RateRamp, 0.2, 6, 2);
  B.F('chain', 'Chain chance', @L.ChainChance, 0, 1, 2, 'Collectibles spawn as a curved chain');
  B.S('collectMix', 'Collect mix', @L.CollectMix, 'Object:weight ... e.g. "Spark:5 Prism:1"');
  B.S('hazardMix', 'Hazard mix', @L.HazardMix);
  B.S('bonusMix', 'Bonus mix', @L.BonusMix);
  B.G('Music');
  B.I('musicSection', 'Start section', @L.MusicSection, 0, 63);
  B.G('Light FX (background optics)');
  B.E('lightScene', 'Light scene', @L.LightScene, LIGHT_SCENES, 'Prism / Newton / grating / diamond lit behind the level');
  B.F('lightX', 'Light X (0..1)', @L.LightX, -0.5, 1.5, 3);
  B.F('lightY', 'Light Y (0..1)', @L.LightY, -0.5, 1.5, 3);
  B.F('lightScale', 'Light scale', @L.LightScale, 20, 400, 0);
  B.F('lightIntensity', 'Light intensity', @L.LightIntensity, 0, 2, 2);
  B.G('Anime (character drawn by the dots)');
  B.E('anime', 'Character', @L.Anime, ANIME_NAMES, 'Mimi / Kuma / Neko / Ao / Party are built-in chibis. Image = your file or folder in data/anime/');
  B.S('animeImage', 'Image file', @L.AnimeImage, 'PNG / JPG in data/anime/ (transparent background works best)');
  B.F('animeMix', 'Dot mix', @L.AnimeMix, 0, 1, 2, 'How strongly the dots take the picture');
  B.F('animeX', 'Center X (0..1)', @L.AnimeX, -0.5, 1.5, 3);
  B.F('animeY', 'Center Y (0..1)', @L.AnimeY, -0.5, 1.5, 3);
  B.F('animeScale', 'Height (screen)', @L.AnimeScale, 0.1, 2, 2);
  B.F('animePan', 'Camera pan', @L.AnimePan, 0, 3, 2, 'Slow anime-style camera drift / zoom');
  B.B('animeCutIn', 'Cut-ins on combo / bonus', @L.AnimeCutIn);
end;

{ ---------------- screens ---------------- }

function DefaultScreen(AId: TScreenId): TScreenFx;
begin
  Result := Default(TScreenFx);
  Result.TitleSize := 92;
  Result.TitleY := 0.24;
  Result.DotSpacing := 3.2;
  Result.DotSize := 2.4;
  Result.DotRound := False;
  Result.DotWave := 3;
  Result.DotWaveFreq := 0.05;
  Result.DotWaveSpeed := 3;
  Result.Shimmer := 0.6;
  Result.ShimmerSpeed := 0.5;
  Result.Palette := 1;
  Result.Saturation := 0.8;
  Result.HueSpeed := 0.08;
  Result.HueScale := 1.2;
  Result.Glow := 0.5;
  Result.BgPreset := 0;
  Result.BgIri := 0.1;
  Result.BgDim := 0.3;
  Result.BgSpeed := 120;
  Result.MenuY := 0.5;
  Result.MenuSize := 34;
  Result.MenuSpacing := 62;
  Result.MenuColor := BGRA(200, 200, 210);
  Result.MenuSelMode := CM_PEARL;
  Result.MenuDotted := True;
  Result.MenuGlow := 0.6;
  Result.TextColor := BGRA(190, 190, 200);
  Result.Particles := 40;
  Result.LightFx := 0;
  Result.LightX := 0.5;
  Result.LightY := 0.86;
  Result.LightSize := 70;
  Result.LightIntensity := 0.8;
  case AId of
    scMain:
      begin
        Result.Title := 'WAVE RIDER';
        Result.Subtitle := 'Ride the dotted light';
        Result.LightFx := 0;
        Result.BgPreset := 5;
        Result.BgIri := 0.25;
      end;
    scLevels:
      begin
        Result.Title := 'SELECT LEVEL'; Result.TitleSize := 56; Result.TitleY := 0.07;
        Result.MenuY := 0.2; Result.MenuSize := 26; Result.MenuSpacing := 46; Result.BgDim := 0.45;
        Result.MenuDotted := False;
      end;
    scOptions:
      begin
        Result.Title := 'OPTIONS'; Result.TitleSize := 64; Result.TitleY := 0.12; Result.MenuY := 0.34;
        Result.BgDim := 0.45;
      end;
    scPause:
      begin
        Result.Title := 'PAUSED'; Result.TitleSize := 72; Result.TitleY := 0.28; Result.MenuY := 0.48;
        Result.BgDim := 0.6; Result.Palette := 3; Result.Particles := 0;
      end;
    scGameOver:
      begin
        Result.Title := 'GAME OVER'; Result.TitleSize := 74; Result.TitleY := 0.22; Result.MenuY := 0.62;
        Result.BgDim := 0.5; Result.Palette := 2; Result.Shimmer := 0.9;
      end;
    scComplete:
      begin
        Result.Title := 'LEVEL CLEAR'; Result.TitleSize := 70; Result.TitleY := 0.2; Result.MenuY := 0.64;
        Result.BgDim := 0.45; Result.Palette := 0; Result.HueSpeed := 0.2; Result.Saturation := 1.3;
      end;
    scHud:
      begin
        Result.Title := ''; Result.TitleSize := 46; Result.MenuSize := 22; Result.BgDim := 0;
        Result.Particles := 0; Result.MenuDotted := False;
      end;
    scLight:
      begin
        Result.Title := 'LIGHT LAB'; Result.TitleSize := 50; Result.TitleY := 0.02;
        Result.Subtitle := 'Choose the light of your beam';
        Result.MenuSize := 24; Result.MenuSpacing := 52; Result.MenuY := 0.885;
        Result.BgDim := 0.6; Result.Particles := 20; Result.BgPreset := 0; Result.BgIri := 0;
      end;
    scReady:
      begin
        Result.Title := 'READY'; Result.TitleSize := 110; Result.TitleY := 0.36; Result.BgDim := 0.2;
        Result.Palette := 3; Result.Particles := 0;
      end;
  end;
end;

procedure DescribeScreen(var B: TPBuilder; var S: TScreenFx);
begin
  B.G('Title (dotted iridescent)');
  B.S('title', 'Title', @S.Title);
  B.S('subtitle', 'Subtitle', @S.Subtitle);
  B.F('titleSize', 'Title size', @S.TitleSize, 10, 220, 0);
  B.F('titleY', 'Title Y (0..1)', @S.TitleY, 0, 1, 3);
  B.F('dotSpacing', 'Dot spacing', @S.DotSpacing, 1.5, 12, 2, 'Grid step of the dotted letters (reference px)');
  B.F('dotSize', 'Dot size', @S.DotSize, 0.5, 10, 2);
  B.B('dotRound', 'Round dots', @S.DotRound);
  B.F('dotWave', 'Dot wave', @S.DotWave, 0, 30, 1, 'Vertical wave through the letters');
  B.F('dotWaveFreq', 'Dot wave freq', @S.DotWaveFreq, 0, 0.5, 3);
  B.F('dotWaveSpeed', 'Dot wave speed', @S.DotWaveSpeed, 0, 20, 2);
  B.F('shimmer', 'Shimmer', @S.Shimmer, 0, 1, 2, 'Pearl light sweep');
  B.F('shimmerSpeed', 'Shimmer speed', @S.ShimmerSpeed, 0, 4, 2);
  B.E('palette', 'Palette', @S.Palette, PALETTE_NAMES);
  B.F('saturation', 'Saturation', @S.Saturation, 0, 1.5, 2);
  B.F('hueSpeed', 'Hue speed', @S.HueSpeed, 0, 2, 3);
  B.F('hueScale', 'Hue scale', @S.HueScale, 0, 6, 2);
  B.F('glow', 'Glow', @S.Glow, 0, 1.5, 2);
  B.C('textColor', 'Text color', @S.TextColor);
  B.G('Background');
  B.E('bgPreset', 'Mesh preset', @S.BgPreset, MESH_NAMES);
  B.F('bgIri', 'Iridescence', @S.BgIri, 0, 1, 2);
  B.F('bgDim', 'Dim', @S.BgDim, 0, 1, 2);
  B.F('bgSpeed', 'Flow speed', @S.BgSpeed, 0, 800, 0);
  B.I('particles', 'Ambient pixels', @S.Particles, 0, 300);
  B.G('Menu');
  B.F('menuY', 'Menu Y (0..1)', @S.MenuY, 0, 1, 3);
  B.F('menuSize', 'Item size', @S.MenuSize, 8, 90, 0);
  B.F('menuSpacing', 'Item spacing', @S.MenuSpacing, 10, 160, 0);
  B.C('menuColor', 'Item color', @S.MenuColor);
  B.E('menuSelMode', 'Selected color', @S.MenuSelMode, CMODE_NAMES);
  B.B('menuDotted', 'Dotted selected item', @S.MenuDotted);
  B.F('menuGlow', 'Selection glow', @S.MenuGlow, 0, 1.5, 2);
  B.G('Light FX');
  B.E('lightFx', 'Light scene', @S.LightFx, LIGHT_SCENES, 'Optics drawn behind this screen');
  B.F('lightX', 'Light X (0..1)', @S.LightX, -0.5, 1.5, 3);
  B.F('lightY', 'Light Y (0..1)', @S.LightY, -0.5, 1.5, 3);
  B.F('lightSize', 'Light size', @S.LightSize, 20, 400, 0);
  B.F('lightIntensity', 'Light intensity', @S.LightIntensity, 0, 2, 2);
end;

{ ---------------- TGameData ---------------- }

constructor TGameData.Create(const ADataDir: string);
var
  s: TScreenId;
  i: Integer;
begin
  inherited Create;
  DataDir := IncludeTrailingPathDelimiter(ADataDir);
  Objects := DefaultObjects;
  Levels := DefaultLevels;
  for s := Low(TScreenId) to High(TScreenId) do Screens[s] := DefaultScreen(s);
  Sfx := DefaultSfxBank;
  Song := DefaultSong;
  for i := 0 to 3 do Light[i] := DefaultLightDef(i);
end;

function TGameData.ObjectsFile: string; begin Result := DataDir + 'objects.ini'; end;
function TGameData.LevelsFile: string;  begin Result := DataDir + 'levels.ini'; end;
function TGameData.ScreensFile: string; begin Result := DataDir + 'screens.ini'; end;
function TGameData.SfxFile: string;     begin Result := DataDir + 'sfx.ini'; end;
function TGameData.SongFile: string;    begin Result := DataDir + 'music.ini'; end;
function TGameData.LightFile: string;   begin Result := DataDir + 'light.ini'; end;

procedure TGameData.LoadObjects;
var
  ini: TMemIniFile;
  i, n, j, ver: Integer;
  b: TPBuilder;
  defs: TObjDefs;
  nm: string;
begin
  if not FileExists(ObjectsFile) then Exit;
  defs := DefaultObjects;
  ini := TMemIniFile.Create(ObjectsFile);
  try
    ver := ini.ReadInteger('Objects', 'Version', 1);
    n := ini.ReadInteger('Objects', 'Count', 0);
    SetLength(Objects, n);
    for i := 0 to n - 1 do
    begin
      { start from the built-in object with the same name: new fields get sensible values }
      nm := ini.ReadString('Object' + IntToStr(i), 'name', '');
      Objects[i] := DefaultObject('Object' + IntToStr(i));
      for j := 0 to High(defs) do
        if SameText(defs[j].Name, nm) then Objects[i] := defs[j];
      b.Clear;
      DescribeObject(b, Objects[i]);
      ReadDescs(ini, 'Object' + IntToStr(i), b.List);
      { the diamond look belongs to the Diamond Light bonus only }
      if (Objects[i].Style = ST_GEM) and (Objects[i].Effect <> EF_DIAMOND) then Objects[i].Style := ST_STAR;
    end;
  finally
    ini.Free;
  end;
  { migration: objects added in newer versions }
  if ver < DATA_VERSION then
    for j := 0 to High(defs) do
      if FindObject(defs[j].Name) < 0 then
      begin
        SetLength(Objects, Length(Objects) + 1);
        Objects[High(Objects)] := defs[j];
      end;
end;

procedure TGameData.SaveObjects;
var
  ini: TMemIniFile;
  i: Integer;
  b: TPBuilder;
begin
  ForceDirectories(DataDir);
  ini := TMemIniFile.Create(ObjectsFile);
  try
    ini.Clear;
    ini.WriteInteger('Objects', 'Version', DATA_VERSION);
    ini.WriteInteger('Objects', 'Count', Length(Objects));
    for i := 0 to High(Objects) do
    begin
      b.Clear;
      DescribeObject(b, Objects[i]);
      WriteDescs(ini, 'Object' + IntToStr(i), b.List);
    end;
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

procedure TGameData.LoadLevels;
var
  ini: TMemIniFile;
  i, n, j, ver: Integer;
  b: TPBuilder;
  defs: TLevelDefs;
  nm: string;
begin
  if not FileExists(LevelsFile) then Exit;
  defs := DefaultLevels;
  ini := TMemIniFile.Create(LevelsFile);
  try
    ver := ini.ReadInteger('Levels', 'Version', 1);
    n := ini.ReadInteger('Levels', 'Count', 0);
    SetLength(Levels, n);
    for i := 0 to n - 1 do
    begin
      nm := ini.ReadString('Level' + IntToStr(i), 'name', '');
      Levels[i] := DefaultLevel;
      for j := 0 to High(defs) do
        if SameText(defs[j].Name, nm) then Levels[i] := defs[j];
      b.Clear;
      DescribeLevel(b, Levels[i]);
      ReadDescs(ini, 'Level' + IntToStr(i), b.List);
      { migration: add the light bonus / gem to the mixes of older files }
      if ver < DATA_VERSION then ApplyLightDefaults(Levels[i], False);
      Levels[i].LightScene := 0;
    end;
  finally
    ini.Free;
  end;
  { migration: anime levels arrive before the last (Endless) level }
  if ver < 4 then
    for j := 0 to High(defs) do
      if (defs[j].Anime > 0) and (FindLevel(defs[j].Name) < 0) then
      begin
        SetLength(Levels, Length(Levels) + 1);
        n := High(Levels);
        if n > 0 then
        begin
          Levels[n] := Levels[n - 1];
          Levels[n - 1] := defs[j];
        end
        else
          Levels[n] := defs[j];
      end;
end;

function TGameData.FindLevel(const AName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(Levels) do
    if SameText(Levels[i].Name, AName) then Exit(i);
  Result := -1;
end;

procedure TGameData.SaveLevels;
var
  ini: TMemIniFile;
  i: Integer;
  b: TPBuilder;
begin
  ForceDirectories(DataDir);
  ini := TMemIniFile.Create(LevelsFile);
  try
    ini.Clear;
    ini.WriteInteger('Levels', 'Version', DATA_VERSION);
    ini.WriteInteger('Levels', 'Count', Length(Levels));
    for i := 0 to High(Levels) do
    begin
      b.Clear;
      DescribeLevel(b, Levels[i]);
      WriteDescs(ini, 'Level' + IntToStr(i), b.List);
    end;
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

procedure TGameData.LoadScreens;
var
  ini: TMemIniFile;
  s: TScreenId;
  b: TPBuilder;
begin
  if not FileExists(ScreensFile) then Exit;
  ini := TMemIniFile.Create(ScreensFile);
  try
    for s := Low(TScreenId) to High(TScreenId) do
    begin
      b.Clear;
      DescribeScreen(b, Screens[s]);
      ReadDescs(ini, SCREEN_KEYS[s], b.List);
      Screens[s].LightFx := 0;   { optics are gameplay, never screen decoration }
    end;
  finally
    ini.Free;
  end;
end;

procedure TGameData.SaveScreens;
var
  ini: TMemIniFile;
  s: TScreenId;
  b: TPBuilder;
begin
  ForceDirectories(DataDir);
  ini := TMemIniFile.Create(ScreensFile);
  try
    ini.Clear;
    for s := Low(TScreenId) to High(TScreenId) do
    begin
      b.Clear;
      DescribeScreen(b, Screens[s]);
      WriteDescs(ini, SCREEN_KEYS[s], b.List);
    end;
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

procedure TGameData.LoadSfx;
var
  bank, defs: TSfxDefs;
  i: Integer;
begin
  bank := LoadSfxBank(SfxFile);
  if Length(bank) = 0 then Exit;
  { sounds added in newer versions (e.g. "beam") }
  defs := DefaultSfxBank;
  for i := 0 to High(defs) do
    if FindSfx(bank, defs[i].Name) < 0 then
    begin
      SetLength(bank, Length(bank) + 1);
      bank[High(bank)] := defs[i];
    end;
  Sfx := bank;
end;

procedure TGameData.SaveSfx;
begin
  SaveSfxBank(SfxFile, Sfx);
end;

procedure TGameData.LoadSong;
var
  s: TSong;
begin
  if uMusic.LoadSong(SongFile, s) then Song := s;
end;

procedure TGameData.SaveSong;
begin
  uMusic.SaveSong(SongFile, Song);
end;

procedure TGameData.LoadLight;
begin
  LoadLightDefs(LightFile, Light);
end;

procedure TGameData.SaveLight;
begin
  SaveLightDefs(LightFile, Light);
end;

procedure TGameData.LoadAll;
begin
  LoadObjects;
  LoadLevels;
  LoadScreens;
  LoadSfx;
  LoadSong;
  LoadLight;
end;

procedure TGameData.SaveAll;
begin
  SaveObjects;
  SaveLevels;
  SaveScreens;
  SaveSfx;
  SaveSong;
  SaveLight;
end;

function TGameData.FindObject(const AName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(Objects) do
    if SameText(Objects[i].Name, AName) then Exit(i);
  Result := -1;
end;

end.

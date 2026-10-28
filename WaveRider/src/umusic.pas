{ WaveRider music: song model, real-time sequencer, game-reactive FX.

  Song
    Tracks[8]   instrument = TSynthParams + mix / reactivity settings
    Patterns[]  32 steps (2 bars of 16ths) per track, cell = note / velocity / length
    Sections[]  arrangement: pattern, repeats, chord progression (transpose per
                repeat), energy (0..1)

  Game reactivity (set from the game thread, read by the audio thread):
    Intensity  0..1   combo -> layers fade in, master filter opens, wobble doubles,
                      sidechain pump deepens
    Fever      0..1   fever bonus -> 16th trance gate + extra drive + wide echo
    Sweep      0..1   bonus pickup -> filter sweep up + echo throw (decays)
    Muffle     0..1   pause menu -> low-pass + volume dip
    TimeScale  0.5..1 slow-mo bonus -> tape slow-down (tempo + pitch) }
unit uMusic;

{$mode objfpc}{$H+}
{$Q-}{$R-}

interface

uses
  Classes, SysUtils, Math, IniFiles, uParams, uSynth;

const
  MAX_TRACKS = 8;
  PAT_STEPS = 32;
  MAX_POLY = 6;
  CHORD_NAMES = 'Single|Minor|Major|Power|Minor7|Sus2|Octave';
  NOTE_NAMES: array[0..11] of string = ('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B');

type
  TStepCell = record
    Note: Byte;      { 0 = empty, else MIDI note }
    Vel: Byte;       { 1..9 }
    Len: Byte;       { steps }
  end;

  TPattern = record
    Name: string;
    Cells: array[0..MAX_TRACKS - 1, 0..PAT_STEPS - 1] of TStepCell;
  end;

  TInstrument = record
    Name: string;
    Synth: TSynthParams;
    Gain: Single;
    Pan: Single;
    Transposable: Boolean;
    Chord: Integer;
    IntensityMin: Single;    { layer fades in when energy+intensity reaches this }
    IntensityCutoff: Single; { octaves of cutoff opened by intensity }
    IntensityLfo: Single;    { LFO rate multiplier at full intensity (wobble x2) }
    Sidechain: Single;       { 0..1 duck from kick }
    IsKick: Boolean;
    Mute: Boolean;
    Solo: Boolean;
  end;

  TSection = record
    Name: string;
    Pattern: Integer;
    Repeats: Integer;
    Progression: string;     { transposes applied per repeat, cycled: "0 -4 3 -2" }
    Energy: Single;
  end;

  TSong = record
    Name: string;
    Bpm: Single;
    Swing: Single;
    MasterGain: Single;
    Tracks: array[0..MAX_TRACKS - 1] of TInstrument;
    Patterns: array of TPattern;
    Sections: array of TSection;
  end;
  PSong = ^TSong;

  { TSongPlayer - runs inside the audio thread }

  TSongPlayer = class
  private
    FVoices: array[0..MAX_TRACKS - 1, 0..MAX_POLY - 1] of TVoice;
    FSynthCopy: array[0..MAX_TRACKS - 1] of TSynthParams;
    FStepPos: Double;          { samples into current step }
    FStep: Integer;            { 0..31 }
    FSection, FRepeat: Integer;
    FDuck: Single;
    FLayer: array[0..MAX_TRACKS - 1] of Single;
    FMasterIc1, FMasterIc2: array[0..1] of Single;
    FEcho: array of Single;    { stereo interleaved }
    FEchoPos: Integer;
    FGatePh: Double;
    FAge: Int64;
    FSmoothCut: Single;
    procedure TriggerStep;
    function SamplesPerStep: Double;
    function CurrentTranspose: Integer;
  public
    Song: PSong;
    Playing: Boolean;
    LoopSection: Integer;      { >=0: loop only this section (editor) }
    Intensity, Fever, Sweep, Muffle, TimeScale: Single;
    Volume: Single;
    constructor Create;
    procedure Reset;
    procedure SeekSection(AIndex: Integer);
    procedure Render(Buf: PSingle; Frames: Integer);   { adds stereo samples }
    procedure PreviewNote(ATrack: Integer; ANote: Integer);
    function PositionText: string;
    property Section: Integer read FSection;
    property Step: Integer read FStep;
    property RepeatIndex: Integer read FRepeat;
  end;

function NoteName(N: Integer): string;
function ChordNotes(AChord: Integer; out Offs: array of Integer): Integer;
function DefaultSong: TSong;
procedure DescribeInstrument(var B: TPBuilder; var I: TInstrument);
procedure DescribeSection(var B: TPBuilder; var S: TSection);
procedure SaveSong(const AFile: string; const S: TSong);
function LoadSong(const AFile: string; out S: TSong): Boolean;
function PatternRowToText(const P: TPattern; ATrack: Integer): string;
procedure PatternRowFromText(var P: TPattern; ATrack: Integer; const AText: string);
function SongLengthSeconds(const S: TSong): Single;

implementation

function NoteName(N: Integer): string;
begin
  if N <= 0 then Exit('---');
  Result := NOTE_NAMES[N mod 12] + IntToStr(N div 12 - 1);
end;

function ChordNotes(AChord: Integer; out Offs: array of Integer): Integer;
begin
  Offs[0] := 0;
  case AChord of
    1: begin Offs[1] := 3; Offs[2] := 7; Result := 3; end;
    2: begin Offs[1] := 4; Offs[2] := 7; Result := 3; end;
    3: begin Offs[1] := 7; Offs[2] := 12; Result := 3; end;
    4: begin Offs[1] := 3; Offs[2] := 7; Offs[3] := 10; Result := 4; end;
    5: begin Offs[1] := 2; Offs[2] := 7; Result := 3; end;
    6: begin Offs[1] := 12; Result := 2; end;
  else
    Result := 1;
  end;
end;

procedure DescribeInstrument(var B: TPBuilder; var I: TInstrument);
begin
  B.G('Track');
  B.S('name', 'Name', @I.Name);
  B.F('gain', 'Gain', @I.Gain, 0, 2, 2);
  B.F('pan', 'Pan', @I.Pan, -1, 1, 2);
  B.B('transposable', 'Follows progression', @I.Transposable, 'Off for drums');
  B.E('chord', 'Chord', @I.Chord, CHORD_NAMES);
  B.B('kick', 'Is kick (drives sidechain)', @I.IsKick);
  B.B('mute', 'Mute', @I.Mute);
  B.G('Game reactivity');
  B.F('intMin', 'Layer threshold', @I.IntensityMin, 0, 1.5, 2, 'Track fades in when section energy + combo intensity reaches this');
  B.F('intCutoff', 'Intensity -> cutoff (oct)', @I.IntensityCutoff, 0, 6, 2, 'Combo opens this track''s filter');
  B.F('intLfo', 'Intensity -> wobble x', @I.IntensityLfo, 1, 4, 2, 'LFO rate multiplier at full combo');
  B.F('sidechain', 'Sidechain duck', @I.Sidechain, 0, 1, 2, 'Pumping against the kick');
  B.G('');
  DescribeSynth(B, I.Synth, 'syn.');
end;

procedure DescribeSection(var B: TPBuilder; var S: TSection);
begin
  B.G('Section');
  B.S('name', 'Name', @S.Name);
  B.I('pattern', 'Pattern #', @S.Pattern, 0, 63);
  B.I('repeats', 'Repeats', @S.Repeats, 1, 64);
  B.S('progression', 'Progression (semis)', @S.Progression, 'Transpose per repeat, cycled. "0 -4 3 -2" = i-VI-III-VII');
  B.F('energy', 'Energy', @S.Energy, 0, 1, 2, 'Base intensity of this section');
end;

{ ---------------- default song ---------------- }

function DefaultSong: TSong;
const
  KICK = 0; SNARE = 1; HAT = 2; SUB = 3; GROWL = 4; PAD = 5; ARP = 6; LEAD = 7;
var
  s: TSong;
  p: Integer;

  function NewPattern(const AName: string): Integer;
  begin
    SetLength(s.Patterns, Length(s.Patterns) + 1);
    Result := High(s.Patterns);
    s.Patterns[Result] := Default(TPattern);
    s.Patterns[Result].Name := AName;
  end;

  procedure N(APat, ATrack, AStep, ANote: Integer; AVel: Integer = 7; ALen: Integer = 1);
  begin
    if (AStep < 0) or (AStep >= PAT_STEPS) then Exit;
    s.Patterns[APat].Cells[ATrack, AStep].Note := ANote;
    s.Patterns[APat].Cells[ATrack, AStep].Vel := AVel;
    s.Patterns[APat].Cells[ATrack, AStep].Len := ALen;
  end;

  procedure Every(APat, ATrack, AFirst, AStepBy, ANote: Integer; AVel: Integer = 7; ALen: Integer = 1);
  var
    i: Integer;
  begin
    i := AFirst;
    while i < PAT_STEPS do
    begin
      N(APat, ATrack, i, ANote, AVel, ALen);
      Inc(i, AStepBy);
    end;
  end;

  procedure AddSection(const AName: string; APat, ARep: Integer; AEnergy: Single; const AProg: string = '0 -4 3 -2');
  begin
    SetLength(s.Sections, Length(s.Sections) + 1);
    with s.Sections[High(s.Sections)] do
    begin
      Name := AName; Pattern := APat; Repeats := ARep; Energy := AEnergy; Progression := AProg;
    end;
  end;

  procedure Inst(AIdx: Integer; const AName: string; const ASyn: TSynthParams; AGain, APan: Single;
    ATrans: Boolean; AChord: Integer; AIntMin, AIntCut, AIntLfo, ASide: Single);
  begin
    s.Tracks[AIdx] := Default(TInstrument);
    with s.Tracks[AIdx] do
    begin
      Name := AName; Synth := ASyn; Gain := AGain; Pan := APan; Transposable := ATrans; Chord := AChord;
      IntensityMin := AIntMin; IntensityCutoff := AIntCut; IntensityLfo := AIntLfo; Sidechain := ASide;
    end;
  end;

var
  y: TSynthParams;
  i: Integer;
const
  { A minor riff material (root A). Bass notes around A1 = 33 }
  LeadHook: array[0..15] of Integer = (69, 0, 72, 0, 76, 0, 74, 72, 0, 69, 0, 67, 69, 0, 0, 0);
begin
  s := Default(TSong);
  s.Name := 'Pearl Pressure';
  s.Bpm := 140;
  s.Swing := 0;
  s.MasterGain := 0.9;

  { --- instruments --- }
  y := DefaultSynth; y.Wave := 0; y.PitchEnv := 36; y.PitchDecay := 0.04; y.Decay := 0.32; y.Release := 0.1;
  y.Drive := 3.5; y.SubLevel := 0.25; y.Volume := 1;
  Inst(KICK, 'Kick', y, 1.0, 0, False, 0, 0, 0, 1, 0);
  s.Tracks[KICK].IsKick := True;

  y := DefaultSynth; y.Wave := 4; y.NoiseMix := 0; y.FilterType := 2; y.Cutoff := 1900; y.Resonance := 0.35;
  y.Decay := 0.2; y.Release := 0.08; y.Drive := 2.5; y.Volume := 0.75;
  Inst(SNARE, 'Clap', y, 0.8, 0, False, 0, 0.15, 0, 1, 0.2);

  y := DefaultSynth; y.Wave := 4; y.FilterType := 1; y.Cutoff := 7500; y.Decay := 0.045; y.Release := 0.02;
  y.Volume := 0.35;
  Inst(HAT, 'Hats', y, 0.55, 0.25, False, 0, 0.2, 0, 1, 0.3);

  y := DefaultSynth; y.Wave := 0; y.SubLevel := 0.5; y.Attack := 0.004; y.Decay := 0.5; y.Sustain := 0.85;
  y.Release := 0.06; y.Drive := 2.2; y.Cutoff := 500; y.Volume := 0.95; y.Octave := 0;
  Inst(SUB, 'Sub Bass', y, 1.0, 0, True, 0, 0, 1.0, 1, 0.85);

  y := DefaultSynth; y.Wave := 1; y.Detune := 16; y.Attack := 0.005; y.Decay := 0.4; y.Sustain := 0.8;
  y.Release := 0.05; y.Cutoff := 260; y.Resonance := 0.62; y.LfoSync := True; y.LfoRate := 0.5;
  y.LfoCutoff := 3.4; y.Drive := 7; y.SubLevel := 0.4; y.Volume := 0.55; y.Octave := 1;
  Inst(GROWL, 'Growl Bass', y, 0.85, 0, True, 0, 0.6, 1.2, 2, 0.7);

  y := DefaultSynth; y.Wave := 1; y.Detune := 22; y.Attack := 0.35; y.Decay := 1.5; y.Sustain := 0.75;
  y.Release := 0.9; y.Cutoff := 1100; y.Resonance := 0.2; y.Volume := 0.3; y.LfoRate := 0.15; y.LfoCutoff := 0.6;
  Inst(PAD, 'Pad', y, 0.6, 0, True, 1, 0, 1.6, 1, 0.65);

  y := DefaultSynth; y.Wave := 2; y.Decay := 0.16; y.Release := 0.06; y.Cutoff := 1800; y.FilterEnv := 2.2;
  y.FilterDecay := 0.08; y.Resonance := 0.35; y.Volume := 0.28; y.Octave := 1;
  Inst(ARP, 'Arp', y, 0.55, -0.3, True, 0, 0.35, 2.0, 1, 0.5);

  y := DefaultSynth; y.Wave := 1; y.Detune := 10; y.Attack := 0.01; y.Decay := 0.5; y.Sustain := 0.5;
  y.Release := 0.25; y.Cutoff := 2400; y.FilterEnv := 1.5; y.FilterDecay := 0.2; y.VibDepth := 0.15;
  y.VibRate := 5.5; y.Volume := 0.3;
  Inst(LEAD, 'Lead', y, 0.6, 0.2, True, 0, 0.75, 1.5, 1, 0.4);

  { --- patterns --- }
  { 0 Intro: half-time pulse, pad, sparse sub }
  p := NewPattern('Intro');
  N(p, KICK, 0, 36, 8); N(p, KICK, 16, 36, 7);
  Every(p, HAT, 4, 8, 60, 4);
  N(p, SUB, 0, 33, 6, 14); N(p, SUB, 16, 33, 6, 14);
  N(p, PAD, 0, 57, 6, 32);
  for i := 0 to 7 do N(p, ARP, i * 4 + 2, 69 + (i mod 3) * 3, 4);

  { 1 Build: four on the floor, snare rolls up in bar 2 }
  p := NewPattern('Build');
  Every(p, KICK, 0, 4, 36, 8);
  N(p, SNARE, 4, 60, 6); N(p, SNARE, 12, 60, 6);
  for i := 16 to 31 do if (i mod 2 = 0) or (i >= 24) then N(p, SNARE, i, 60, 3 + (i - 16) div 3);
  Every(p, HAT, 2, 4, 60, 5);
  Every(p, SUB, 0, 4, 33, 7, 3);
  N(p, PAD, 0, 57, 6, 32);
  for i := 0 to 15 do N(p, ARP, i * 2, 69 + ((i * 7) mod 12), 5);

  { 2 Drop A: 4/4 bass house drop }
  p := NewPattern('Drop A');
  Every(p, KICK, 0, 4, 36, 9);
  Every(p, SNARE, 4, 8, 60, 8);
  Every(p, HAT, 2, 4, 60, 6);
  for i := 0 to 7 do
  begin
    N(p, SUB, i * 4, 33, 8, 2);
    N(p, GROWL, i * 4 + 2, 33 + IfThen(i mod 4 = 3, 3, 0), 8, 2);
  end;
  N(p, GROWL, 14, 36, 8, 1); N(p, GROWL, 30, 31, 8, 2);
  N(p, PAD, 0, 57, 5, 4); N(p, PAD, 6, 57, 5, 2); N(p, PAD, 16, 57, 5, 4); N(p, PAD, 22, 57, 5, 2);
  for i := 0 to 31 do N(p, ARP, i, 69 + ((i * 5) mod 12), 4 + (i mod 2));
  for i := 0 to 15 do if LeadHook[i] > 0 then N(p, LEAD, i, LeadHook[i], 7, 2);
  for i := 0 to 15 do if LeadHook[i] > 0 then N(p, LEAD, 16 + i, LeadHook[i] - IfThen(i > 8, 2, 0), 6, 2);

  { 3 Break: no kick, pad + arp + long sub }
  p := NewPattern('Break');
  N(p, SUB, 0, 33, 5, 32);
  N(p, PAD, 0, 57, 7, 32);
  for i := 0 to 15 do N(p, ARP, i * 2, 69 + ((i * 3) mod 12), 5);
  N(p, LEAD, 0, 76, 5, 8); N(p, LEAD, 8, 74, 5, 8); N(p, LEAD, 16, 72, 5, 12);

  { 4 Drop B: half-time dubstep wobble }
  p := NewPattern('Drop B');
  N(p, KICK, 0, 36, 9); N(p, KICK, 10, 36, 7); N(p, KICK, 16, 36, 9); N(p, KICK, 19, 36, 6);
  N(p, SNARE, 8, 60, 9); N(p, SNARE, 24, 60, 9);
  Every(p, HAT, 0, 2, 60, 4);
  N(p, SUB, 0, 33, 8, 8); N(p, SUB, 10, 33, 7, 6); N(p, SUB, 16, 36, 8, 8); N(p, SUB, 26, 31, 7, 6);
  N(p, GROWL, 0, 33, 9, 6); N(p, GROWL, 8, 33, 9, 2); N(p, GROWL, 10, 36, 9, 6);
  N(p, GROWL, 16, 33, 9, 6); N(p, GROWL, 24, 38, 9, 3); N(p, GROWL, 27, 36, 9, 5);
  N(p, PAD, 0, 57, 5, 32);
  for i := 0 to 7 do N(p, ARP, i * 4, 81 - (i mod 4) * 2, 5);
  for i := 0 to 15 do if LeadHook[i] > 0 then N(p, LEAD, i * 2, LeadHook[i], 7, 2);

  { 5 Outro }
  p := NewPattern('Outro');
  N(p, KICK, 0, 36, 6);
  N(p, SUB, 0, 33, 5, 32);
  N(p, PAD, 0, 57, 5, 32);
  for i := 0 to 7 do N(p, ARP, i * 4, 69 + (i mod 4) * 3, 3);

  { --- arrangement: ~5 minutes at 140 bpm (2 bars = 3.43 s) --- }
  AddSection('Intro', 0, 8, 0.1);
  AddSection('Build', 1, 8, 0.4);
  AddSection('Drop A', 2, 16, 0.85);
  AddSection('Break', 3, 8, 0.2);
  AddSection('Build 2', 1, 4, 0.5);
  AddSection('Drop B', 4, 16, 0.95);
  AddSection('Break 2', 3, 4, 0.3, '0 3 -2 -4');
  AddSection('Drop A2', 2, 16, 1.0, '0 3 -2 -4');
  AddSection('Outro', 5, 8, 0.15);
  Result := s;
end;

{ ---------------- serialization ---------------- }

function PatternRowToText(const P: TPattern; ATrack: Integer): string;
var
  i: Integer;
  c: TStepCell;
begin
  Result := '';
  for i := 0 to PAT_STEPS - 1 do
  begin
    c := P.Cells[ATrack, i];
    if i > 0 then Result := Result + ' ';
    if c.Note = 0 then Result := Result + '.'
    else Result := Result + Format('%d:%d:%d', [c.Note, c.Vel, c.Len]);
  end;
end;

procedure PatternRowFromText(var P: TPattern; ATrack: Integer; const AText: string);
var
  sl, f: TStringList;
  i: Integer;
begin
  sl := TStringList.Create;
  f := TStringList.Create;
  try
    sl.Delimiter := ' ';
    sl.StrictDelimiter := True;
    sl.DelimitedText := Trim(AText);
    f.Delimiter := ':';
    f.StrictDelimiter := True;
    for i := 0 to Min(sl.Count, PAT_STEPS) - 1 do
    begin
      P.Cells[ATrack, i] := Default(TStepCell);
      if (sl[i] = '.') or (sl[i] = '') then Continue;
      f.DelimitedText := sl[i];
      P.Cells[ATrack, i].Note := EnsureRange(StrToIntDef(f[0], 0), 0, 127);
      if f.Count > 1 then P.Cells[ATrack, i].Vel := EnsureRange(StrToIntDef(f[1], 7), 1, 9) else P.Cells[ATrack, i].Vel := 7;
      if f.Count > 2 then P.Cells[ATrack, i].Len := EnsureRange(StrToIntDef(f[2], 1), 1, 64) else P.Cells[ATrack, i].Len := 1;
    end;
  finally
    f.Free;
    sl.Free;
  end;
end;

procedure SaveSong(const AFile: string; const S: TSong);
var
  ini: TMemIniFile;
  i, t: Integer;
  b: TPBuilder;
  tmp: TSong;
begin
  ForceDirectories(ExtractFilePath(AFile));
  tmp := S;
  ini := TMemIniFile.Create(AFile);
  try
    ini.Clear;
    ini.WriteString('Song', 'Name', tmp.Name);
    ini.WriteString('Song', 'Bpm', FloatToInv(tmp.Bpm, 2));
    ini.WriteString('Song', 'Swing', FloatToInv(tmp.Swing, 3));
    ini.WriteString('Song', 'MasterGain', FloatToInv(tmp.MasterGain, 3));
    ini.WriteInteger('Song', 'Patterns', Length(tmp.Patterns));
    ini.WriteInteger('Song', 'Sections', Length(tmp.Sections));
    for t := 0 to MAX_TRACKS - 1 do
    begin
      b.Clear;
      DescribeInstrument(b, tmp.Tracks[t]);
      WriteDescs(ini, 'Track' + IntToStr(t), b.List);
    end;
    for i := 0 to High(tmp.Patterns) do
    begin
      ini.WriteString('Pattern' + IntToStr(i), 'name', tmp.Patterns[i].Name);
      for t := 0 to MAX_TRACKS - 1 do
        ini.WriteString('Pattern' + IntToStr(i), 't' + IntToStr(t), PatternRowToText(tmp.Patterns[i], t));
    end;
    for i := 0 to High(tmp.Sections) do
    begin
      b.Clear;
      DescribeSection(b, tmp.Sections[i]);
      WriteDescs(ini, 'Section' + IntToStr(i), b.List);
    end;
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

function LoadSong(const AFile: string; out S: TSong): Boolean;
var
  ini: TMemIniFile;
  i, t, n: Integer;
  b: TPBuilder;
begin
  S := DefaultSong;
  Result := FileExists(AFile);
  if not Result then Exit;
  ini := TMemIniFile.Create(AFile);
  try
    S.Name := ini.ReadString('Song', 'Name', S.Name);
    S.Bpm := EnsureRange(InvToFloat(ini.ReadString('Song', 'Bpm', ''), S.Bpm), 40, 240);
    S.Swing := EnsureRange(InvToFloat(ini.ReadString('Song', 'Swing', ''), S.Swing), 0, 0.5);
    S.MasterGain := EnsureRange(InvToFloat(ini.ReadString('Song', 'MasterGain', ''), S.MasterGain), 0, 2);
    for t := 0 to MAX_TRACKS - 1 do
    begin
      b.Clear;
      DescribeInstrument(b, S.Tracks[t]);
      ReadDescs(ini, 'Track' + IntToStr(t), b.List);
    end;
    n := ini.ReadInteger('Song', 'Patterns', Length(S.Patterns));
    SetLength(S.Patterns, n);
    for i := 0 to n - 1 do
    begin
      S.Patterns[i] := Default(TPattern);
      S.Patterns[i].Name := ini.ReadString('Pattern' + IntToStr(i), 'name', 'Pattern ' + IntToStr(i));
      for t := 0 to MAX_TRACKS - 1 do
        PatternRowFromText(S.Patterns[i], t, ini.ReadString('Pattern' + IntToStr(i), 't' + IntToStr(t), ''));
    end;
    n := ini.ReadInteger('Song', 'Sections', Length(S.Sections));
    SetLength(S.Sections, n);
    for i := 0 to n - 1 do
    begin
      S.Sections[i] := Default(TSection);
      S.Sections[i].Repeats := 1;
      b.Clear;
      DescribeSection(b, S.Sections[i]);
      ReadDescs(ini, 'Section' + IntToStr(i), b.List);
    end;
  finally
    ini.Free;
  end;
end;

function SongLengthSeconds(const S: TSong): Single;
var
  i, bars: Integer;
begin
  bars := 0;
  for i := 0 to High(S.Sections) do
    Inc(bars, S.Sections[i].Repeats * 2);
  Result := bars * 4 * 60 / Max(1, S.Bpm);
end;

{ ---------------- player ---------------- }

constructor TSongPlayer.Create;
begin
  inherited Create;
  LoopSection := -1;
  TimeScale := 1;
  Volume := 1;
  SetLength(FEcho, SAMPLE_RATE * 2 * 2);
  FSmoothCut := 1;
  Reset;
end;

procedure TSongPlayer.Reset;
var
  t, v: Integer;
begin
  for t := 0 to MAX_TRACKS - 1 do
  begin
    for v := 0 to MAX_POLY - 1 do FVoices[t, v].Active := False;
    FLayer[t] := 0;
  end;
  FStep := -1;
  FStepPos := 0;
  FSection := 0;
  FRepeat := 0;
  FDuck := 0;
  if LoopSection >= 0 then FSection := LoopSection;
end;

procedure TSongPlayer.SeekSection(AIndex: Integer);
begin
  Reset;
  if (Song <> nil) and (Length(Song^.Sections) > 0) then
    FSection := EnsureRange(AIndex, 0, High(Song^.Sections));
end;

function TSongPlayer.SamplesPerStep: Double;
begin
  Result := SAMPLE_RATE * 60 / Max(30, Song^.Bpm * TimeScale) / 4;
end;

function TSongPlayer.CurrentTranspose: Integer;
var
  sl: TStringList;
  prog: string;
begin
  Result := 0;
  if (FSection < 0) or (FSection > High(Song^.Sections)) then Exit;
  prog := Trim(Song^.Sections[FSection].Progression);
  if prog = '' then Exit;
  sl := TStringList.Create;
  try
    sl.Delimiter := ' ';
    sl.StrictDelimiter := False;
    sl.DelimitedText := prog;
    if sl.Count > 0 then Result := StrToIntDef(sl[FRepeat mod sl.Count], 0);
  finally
    sl.Free;
  end;
end;

procedure TSongPlayer.TriggerStep;
var
  t, v, best, k, n, tr, pat: Integer;
  c: TStepCell;
  offs: array[0..3] of Integer;
  oldest: Int64;
  gate: Double;
  anySolo: Boolean;
begin
  if Length(Song^.Sections) = 0 then Exit;
  Inc(FStep);
  if FStep >= PAT_STEPS then
  begin
    FStep := 0;
    Inc(FRepeat);
    if FRepeat >= Max(1, Song^.Sections[FSection].Repeats) then
    begin
      FRepeat := 0;
      if LoopSection >= 0 then FSection := EnsureRange(LoopSection, 0, High(Song^.Sections))
      else
      begin
        Inc(FSection);
        if FSection > High(Song^.Sections) then FSection := 0;
      end;
    end;
  end;
  pat := Song^.Sections[FSection].Pattern;
  if (pat < 0) or (pat > High(Song^.Patterns)) then Exit;
  tr := CurrentTranspose;
  anySolo := False;
  for t := 0 to MAX_TRACKS - 1 do anySolo := anySolo or Song^.Tracks[t].Solo;

  for t := 0 to MAX_TRACKS - 1 do
  begin
    c := Song^.Patterns[pat].Cells[t, FStep];
    if c.Note = 0 then Continue;
    if Song^.Tracks[t].Mute or (anySolo and not Song^.Tracks[t].Solo) then Continue;
    if Song^.Tracks[t].IsKick then FDuck := 1;
    n := ChordNotes(Song^.Tracks[t].Chord, offs);
    gate := c.Len * SamplesPerStep / SAMPLE_RATE * 0.92;
    for k := 0 to n - 1 do
    begin
      { voice allocation: free voice, else steal the oldest }
      best := 0;
      oldest := High(Int64);
      for v := 0 to MAX_POLY - 1 do
      begin
        if not FVoices[t, v].Active then begin best := v; Break; end;
        if FVoices[t, v].Age < oldest then begin oldest := FVoices[t, v].Age; best := v; end;
      end;
      VoiceStart(FVoices[t, best],
        c.Note + offs[k] + Song^.Tracks[t].Synth.Octave * 12 + IfThen(Song^.Tracks[t].Transposable, tr, 0),
        c.Vel / 9, gate);
      Inc(FAge);
      FVoices[t, best].Age := FAge;
    end;
  end;
end;

procedure TSongPlayer.PreviewNote(ATrack: Integer; ANote: Integer);
begin
  if (ATrack < 0) or (ATrack >= MAX_TRACKS) then Exit;
  VoiceStart(FVoices[ATrack, 0], ANote + Song^.Tracks[ATrack].Synth.Octave * 12, 0.8, 0.3);
  FLayer[ATrack] := 1;
end;

function TSongPlayer.PositionText: string;
begin
  if (Song = nil) or (FSection > High(Song^.Sections)) then Exit('-');
  Result := Format('%s  %d/%d  step %d', [Song^.Sections[FSection].Name, FRepeat + 1,
    Song^.Sections[FSection].Repeats, Max(0, FStep) + 1]);
end;

procedure TSongPlayer.Render(Buf: PSingle; Frames: Integer);
var
  f, t, v, echoLen, d: Integer;
  sps, energy, lvl, target, x, l, r, mono, lp, pm, cm, bpm, panL, panR, duckMul, gate, cut, g, k, a1, a2, a3,
  v1, v2, v3, echoSend, fb, inst: Single;
  ch: Integer;
begin
  if (Song = nil) or (Length(Song^.Sections) = 0) then Exit;
  if not Playing then
  begin
    { stopped: only let preview notes ring out }
    target := 0;
    for t := 0 to MAX_TRACKS - 1 do
      for v := 0 to MAX_POLY - 1 do
        if FVoices[t, v].Active then target := 1;
    if target = 0 then Exit;
  end;
  sps := SamplesPerStep;
  bpm := Song^.Bpm * TimeScale;
  pm := TimeScale;
  echoLen := Length(FEcho) div 2;

  { per-buffer: smoothed game parameters }
  if FSection <= High(Song^.Sections) then energy := Song^.Sections[FSection].Energy else energy := 0.5;
  inst := Min(1, Intensity + Fever);

  { per-track instrument copies with intensity applied (wobble rate) }
  for t := 0 to MAX_TRACKS - 1 do
  begin
    FSynthCopy[t] := Song^.Tracks[t].Synth;
    FSynthCopy[t].LfoRate := FSynthCopy[t].LfoRate * (1 + (Song^.Tracks[t].IntensityLfo - 1) * IfThen(inst > 0.65, 1, 0));
    target := EnsureRange((energy + inst * 0.75 - Song^.Tracks[t].IntensityMin) * 5, 0, 1);
    if (Song^.Tracks[t].IntensityMin <= 0) or not Playing then target := 1;
    FLayer[t] := FLayer[t] + (target - FLayer[t]) * 0.08;
  end;

  { master low-pass: closed in intros / pause, opened by energy + combo + bonus sweep }
  target := Power(2, 3.2 + 6.2 * EnsureRange(0.25 + energy * 0.35 + inst * 0.6 + Sweep * 0.5, 0, 1));
  target := target * 250 * (1 - Muffle * 0.92);
  FSmoothCut := FSmoothCut + (target - FSmoothCut) * 0.15;
  cut := EnsureRange(FSmoothCut, 80, 19000);
  g := Tan(Pi * cut / SAMPLE_RATE);
  k := 2 - 2 * 0.25;
  a1 := 1 / (1 + g * (g + k)); a2 := g * a1; a3 := g * a2;
  echoSend := Sweep * 0.6 + Fever * 0.35;
  fb := 0.45 + Fever * 0.2;
  d := Round(sps * 3);                              { dotted 8th echo }
  if d >= echoLen then d := echoLen - 1;

  for f := 0 to Frames - 1 do
  begin
    FStepPos := FStepPos + 1;
    if Playing and ((FStep < 0) or (FStepPos >= sps * (1 + IfThen(FStep mod 2 = 0, Song^.Swing, -Song^.Swing)))) then
    begin
      FStepPos := 0;
      TriggerStep;
    end;
    FDuck := FDuck * 0.99975;
    l := 0; r := 0;
    for t := 0 to MAX_TRACKS - 1 do
    begin
      if FLayer[t] < 0.001 then
      begin
        { still advance voices silently so they end naturally }
        Continue;
      end;
      cm := Power(2, Song^.Tracks[t].IntensityCutoff * inst);
      mono := 0;
      for v := 0 to MAX_POLY - 1 do
        if FVoices[t, v].Active then
          mono := mono + VoiceSample(FVoices[t, v], FSynthCopy[t], bpm, pm, cm);
      if mono = 0 then Continue;
      duckMul := 1 - Song^.Tracks[t].Sidechain * Min(1, FDuck * (1.2 + inst * 0.6));
      mono := mono * Song^.Tracks[t].Gain * FLayer[t] * duckMul;
      panL := Sqrt(0.5 * (1 - Song^.Tracks[t].Pan));
      panR := Sqrt(0.5 * (1 + Song^.Tracks[t].Pan));
      l := l + mono * panL;
      r := r + mono * panR;
    end;

    { fever: 16th trance gate }
    if Fever > 0.01 then
    begin
      FGatePh := FGatePh + 1 / sps;
      if FGatePh >= 1 then FGatePh := FGatePh - 1;
      gate := 1 - Fever * 0.55 * IfThen(FGatePh > 0.55, 1, 0);
      l := l * gate; r := r * gate;
    end;

    { master filter (stereo TPT) }
    for ch := 0 to 1 do
    begin
      if ch = 0 then x := l else x := r;
      v3 := x - FMasterIc2[ch];
      v1 := a1 * FMasterIc1[ch] + a2 * v3;
      v2 := FMasterIc2[ch] + a2 * FMasterIc1[ch] + a3 * v3;
      FMasterIc1[ch] := 2 * v1 - FMasterIc1[ch];
      FMasterIc2[ch] := 2 * v2 - FMasterIc2[ch];
      if ch = 0 then l := v2 else r := v2;
    end;

    { echo throw (ping-pong) }
    lp := FEcho[((FEchoPos - d + echoLen) mod echoLen) * 2];
    mono := FEcho[((FEchoPos - d + echoLen) mod echoLen) * 2 + 1];
    FEcho[FEchoPos * 2] := (l * echoSend) + mono * fb;
    FEcho[FEchoPos * 2 + 1] := (r * echoSend) + lp * fb;
    FEchoPos := (FEchoPos + 1) mod echoLen;
    l := l + lp * 0.6;
    r := r + mono * 0.6;

    x := Song^.MasterGain * Volume * (1 - Muffle * 0.35) * (1 + Fever * 0.15);
    Buf[f * 2] := Buf[f * 2] + l * x;
    Buf[f * 2 + 1] := Buf[f * 2 + 1] + r * x;
  end;
end;

end.

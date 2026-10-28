{ WaveRider synth core.

  One voice architecture shared by sound effects and music instruments:

    OSC (sine/saw/square/triangle/noise, polyBLEP) x2 (detune)
      + SUB sine (one octave down) + NOISE mix
    -> pitch: note + pitch-envelope (808 drop) + slide + vibrato + LFO + arpeggio
    -> TPT state-variable filter (LP/HP/BP) with envelope + LFO (wobble)
    -> drive (tanh) -> bit-crush / sample-hold -> ADSR amp -> volume

  Sound effects are 1-2 layers of this voice rendered offline into a sample
  buffer (+ optional echo). Music instruments run the same voice in real time. }
unit uSynth;

{$mode objfpc}{$H+}
{$Q-}{$R-}

interface

uses
  Classes, SysUtils, Math, IniFiles, uParams;

const
  SAMPLE_RATE = 44100;
  WAVE_NAMES = 'Sine|Saw|Square|Triangle|Noise';
  FILTER_NAMES = 'LowPass|HighPass|BandPass';

type
  TSampleBuf = array of Single;

  TSynthParams = record
    Wave: Integer;
    Detune: Single;          { cents, second oscillator }
    NoiseMix: Single;
    SubLevel: Single;
    BaseNote: Single;        { MIDI note (SFX); instruments use pattern notes + Octave }
    Octave: Integer;         { instrument octave offset }
    PitchEnv: Single;        { semitones added at onset }
    PitchDecay: Single;      { s }
    Slide: Single;           { semitones / s }
    VibDepth, VibRate: Single;
    Attack, Decay, Sustain, Release: Single;
    Duration: Single;        { SFX gate time }
    FilterType: Integer;
    Cutoff: Single;          { Hz }
    Resonance: Single;       { 0..0.97 }
    FilterEnv: Single;       { octaves }
    FilterDecay: Single;     { s }
    LfoRate: Single;         { Hz, or cycles per beat when LfoSync }
    LfoSync: Boolean;
    LfoCutoff: Single;       { octaves }
    LfoPitch: Single;        { semitones }
    LfoAmp: Single;          { 0..1 tremolo }
    Drive: Single;           { 1 = clean }
    Crush: Integer;          { bits, 0 = off }
    Downsample: Integer;     { sample hold factor, 1 = off }
    Arp: string;             { semitone offsets "0 4 7 12" }
    ArpRate: Single;         { steps / s }
    Volume: Single;
    Pan: Single;
  end;

  TSfxDef = record
    Name: string;
    A, B: TSynthParams;
    UseB: Boolean;
    EchoTime, EchoFeedback, EchoMix: Single;
    Gain: Single;
  end;
  TSfxDefs = array of TSfxDef;

  { Runtime voice }
  TVoice = record
    Active: Boolean;
    Gate: Boolean;
    Note: Single;
    Vel: Single;
    T: Double;               { seconds since note on }
    TRel: Double;            { seconds since release }
    EnvRel: Single;          { env level at release }
    Env: Single;
    Ph1, Ph2, PhSub, PhLfo: Double;
    Ic1, Ic2: Single;
    CoefCount: Integer;
    A1, A2, A3, K: Single;
    Hold: Single;
    HoldCount: Integer;
    Rnd: LongWord;
    GateLen: Double;         { auto release after (s); <=0 manual }
    Freq: Single;            { current oscillator frequency (control rate) }
    Lfo: Single;             { current LFO value (control rate) }
    Age: Int64;
  end;
  PVoice = ^TVoice;

function DefaultSynth: TSynthParams;
procedure DescribeSynth(var B: TPBuilder; var P: TSynthParams; const APrefix: string);

procedure VoiceStart(var V: TVoice; ANote, AVel: Single; AGateLen: Double);
procedure VoiceRelease(var V: TVoice);
{ Renders one sample. Bpm used for synced LFO; PitchMul for tape-speed fx;
  CutoffMul extra filter multiplier (music intensity). }
function VoiceSample(var V: TVoice; const P: TSynthParams; Bpm, PitchMul, CutoffMul: Single): Single;

function DefaultSfx(const AName: string): TSfxDef;
procedure DescribeSfx(var B: TPBuilder; var S: TSfxDef);
function RenderSfx(const S: TSfxDef): TSampleBuf;

procedure SaveSfxBank(const AFile: string; const Bank: TSfxDefs);
function LoadSfxBank(const AFile: string): TSfxDefs;
function DefaultSfxBank: TSfxDefs;
function FindSfx(const Bank: TSfxDefs; const AName: string): Integer;

procedure WriteWav(const AFile: string; const Samples: array of Single; AChannels: Integer);

implementation

function NoteToFreq(N: Single): Single; inline;
begin
  Result := 440 * Power(2, (N - 69) / 12);
end;

function DefaultSynth: TSynthParams;
begin
  Result := Default(TSynthParams);
  Result.Wave := 0;
  Result.BaseNote := 57;
  Result.PitchDecay := 0.05;
  Result.VibRate := 5;
  Result.Attack := 0.002;
  Result.Decay := 0.3;
  Result.Sustain := 0;
  Result.Release := 0.1;
  Result.Duration := 0.2;
  Result.FilterType := 0;
  Result.Cutoff := 18000;
  Result.Resonance := 0.1;
  Result.FilterDecay := 0.2;
  Result.LfoRate := 2;
  Result.Drive := 1;
  Result.Downsample := 1;
  Result.ArpRate := 20;
  Result.Volume := 0.8;
end;

procedure DescribeSynth(var B: TPBuilder; var P: TSynthParams; const APrefix: string);
var
  g: string;
begin
  g := B.Group;
  B.G(g + 'Oscillator');
  B.E(APrefix + 'wave', 'Wave', @P.Wave, WAVE_NAMES);
  B.F(APrefix + 'detune', 'Detune (cents)', @P.Detune, 0, 60, 1, 'Second oscillator detune - thick supersaw style');
  B.F(APrefix + 'noise', 'Noise mix', @P.NoiseMix, 0, 1, 2);
  B.F(APrefix + 'sub', 'Sub level', @P.SubLevel, 0, 1.5, 2, 'Sine one octave below: heavy bass weight');
  B.F(APrefix + 'note', 'Base note (MIDI)', @P.BaseNote, 12, 108, 1, 'SFX pitch. 33 = A1 (55 Hz), 45 = A2, 57 = A3');
  B.I(APrefix + 'octave', 'Octave (instr.)', @P.Octave, -3, 3);
  B.G(g + 'Pitch');
  B.F(APrefix + 'pitchEnv', 'Pitch env (semi)', @P.PitchEnv, -48, 48, 1, '808 / kick drop: start this many semitones above');
  B.F(APrefix + 'pitchDecay', 'Pitch decay (s)', @P.PitchDecay, 0.005, 2, 3);
  B.F(APrefix + 'slide', 'Slide (semi/s)', @P.Slide, -96, 96, 1);
  B.F(APrefix + 'vibDepth', 'Vibrato depth', @P.VibDepth, 0, 2, 2);
  B.F(APrefix + 'vibRate', 'Vibrato rate (Hz)', @P.VibRate, 0.1, 20, 1);
  B.S(APrefix + 'arp', 'Arpeggio (semis)', @P.Arp, 'e.g. "0 4 7 12" - empty = off');
  B.F(APrefix + 'arpRate', 'Arp rate (steps/s)', @P.ArpRate, 1, 60, 1);
  B.G(g + 'Amp envelope');
  B.F(APrefix + 'attack', 'Attack (s)', @P.Attack, 0.0005, 3, 4);
  B.F(APrefix + 'decay', 'Decay (s)', @P.Decay, 0.005, 6, 3);
  B.F(APrefix + 'sustain', 'Sustain', @P.Sustain, 0, 1, 2);
  B.F(APrefix + 'release', 'Release (s)', @P.Release, 0.005, 6, 3);
  B.F(APrefix + 'duration', 'Duration (SFX gate s)', @P.Duration, 0.01, 4, 3);
  B.G(g + 'Filter');
  B.E(APrefix + 'filter', 'Filter type', @P.FilterType, FILTER_NAMES);
  B.F(APrefix + 'cutoff', 'Cutoff (Hz)', @P.Cutoff, 20, 18000, 0);
  B.F(APrefix + 'res', 'Resonance', @P.Resonance, 0, 0.97, 2);
  B.F(APrefix + 'fenv', 'Filter env (oct)', @P.FilterEnv, -8, 8, 2);
  B.F(APrefix + 'fdecay', 'Filter decay (s)', @P.FilterDecay, 0.005, 4, 3);
  B.G(g + 'LFO / wobble');
  B.F(APrefix + 'lfoRate', 'LFO rate', @P.LfoRate, 0.05, 32, 2, 'Hz, or cycles per beat when synced');
  B.B(APrefix + 'lfoSync', 'LFO tempo sync', @P.LfoSync);
  B.F(APrefix + 'lfoCutoff', 'LFO -> cutoff (oct)', @P.LfoCutoff, 0, 8, 2, 'Dubstep wobble');
  B.F(APrefix + 'lfoPitch', 'LFO -> pitch (semi)', @P.LfoPitch, 0, 12, 2);
  B.F(APrefix + 'lfoAmp', 'LFO -> amp', @P.LfoAmp, 0, 1, 2);
  B.G(g + 'Character');
  B.F(APrefix + 'drive', 'Drive', @P.Drive, 1, 30, 1, 'Saturation - makes bass heavy and loud');
  B.I(APrefix + 'crush', 'Bit crush (bits)', @P.Crush, 0, 16, '0 = off. 4-6 = 8-bit pixel sound');
  B.I(APrefix + 'downsample', 'Sample hold', @P.Downsample, 1, 32);
  B.F(APrefix + 'volume', 'Volume', @P.Volume, 0, 2, 2);
  B.F(APrefix + 'pan', 'Pan', @P.Pan, -1, 1, 2);
  B.G(g);
end;

procedure VoiceStart(var V: TVoice; ANote, AVel: Single; AGateLen: Double);
var
  seed: LongWord;
begin
  seed := V.Rnd;
  V := Default(TVoice);
  V.Rnd := seed xor $9E3779B9 + LongWord(Round(ANote * 7919));
  if V.Rnd = 0 then V.Rnd := 12345;
  V.Active := True;
  V.Gate := True;
  V.Note := ANote;
  V.Vel := AVel;
  V.GateLen := AGateLen;
  V.Hold := 0;
end;

procedure VoiceRelease(var V: TVoice);
begin
  if V.Gate then
  begin
    V.Gate := False;
    V.TRel := 0;
    V.EnvRel := V.Env;
  end;
end;

function PolyBlep(t, dt: Double): Double; inline;
begin
  if t < dt then
  begin
    t := t / dt;
    Result := t + t - t * t - 1;
  end
  else if t > 1 - dt then
  begin
    t := (t - 1) / dt;
    Result := t * t + t + t + 1;
  end
  else
    Result := 0;
end;

function Osc(AWave: Integer; Ph, Dt: Double; var Rnd: LongWord): Single; inline;
var
  t2: Double;
begin
  case AWave of
    0: Result := Sin(2 * Pi * Ph);
    1: Result := 2 * Ph - 1 - PolyBlep(Ph, Dt);
    2: begin
         if Ph < 0.5 then Result := 1 else Result := -1;
         t2 := Ph + 0.5;
         if t2 >= 1 then t2 := t2 - 1;
         Result := Result + PolyBlep(Ph, Dt) - PolyBlep(t2, Dt);
       end;
    3: Result := 4 * Abs(Ph - 0.5) - 1;
  else
    begin
      Rnd := Rnd xor (Rnd shl 13);
      Rnd := Rnd xor (Rnd shr 17);
      Rnd := Rnd xor (Rnd shl 5);
      Result := (Rnd and $FFFF) / 32768 - 1;
    end;
  end;
end;

function ArpOffset(const AArp: string; AStep: Integer): Single;
var
  i, n, start, idx: Integer;
  parts: array[0..15] of Single;
  s: string;
begin
  Result := 0;
  if AArp = '' then Exit;
  n := 0;
  i := 1;
  while (i <= Length(AArp)) and (n < 16) do
  begin
    while (i <= Length(AArp)) and (AArp[i] in [' ', ',', ';']) do Inc(i);
    start := i;
    while (i <= Length(AArp)) and not (AArp[i] in [' ', ',', ';']) do Inc(i);
    if i > start then
    begin
      s := Copy(AArp, start, i - start);
      parts[n] := InvToFloat(s, 0);
      Inc(n);
    end;
  end;
  if n = 0 then Exit;
  idx := AStep mod n;
  Result := parts[idx];
end;

function VoiceSample(var V: TVoice; const P: TSynthParams; Bpm, PitchMul, CutoffMul: Single): Single;
const
  DT = 1 / SAMPLE_RATE;
  CTRL = 8;                  { control-rate divider for pitch / LFO / filter }
var
  semis, freq, f2, lfoHz, x, env, cut, g, levels, v1, v2, v3: Single;
  dPh: Double;
begin
  Result := 0;
  if not V.Active then Exit;

  { auto release }
  if V.Gate and (V.GateLen > 0) and (V.T >= V.GateLen) then VoiceRelease(V);

  { LFO phase (audio rate, cheap) }
  if P.LfoSync then lfoHz := P.LfoRate * Bpm / 60 else lfoHz := P.LfoRate;
  V.PhLfo := V.PhLfo + lfoHz * DT;
  if V.PhLfo >= 1 then V.PhLfo := V.PhLfo - Trunc(V.PhLfo);

  { control rate: pitch, LFO value, filter coefficients }
  if V.CoefCount <= 0 then
  begin
    V.Lfo := Sin(2 * Pi * V.PhLfo);
    semis := P.PitchEnv * Exp(-V.T / Max(0.001, P.PitchDecay)) + P.Slide * V.T
           + P.VibDepth * Sin(2 * Pi * P.VibRate * V.T) + P.LfoPitch * V.Lfo;
    if P.Arp <> '' then
      semis := semis + ArpOffset(P.Arp, Trunc(V.T * P.ArpRate));
    freq := NoteToFreq(V.Note + semis) * PitchMul;
    V.Freq := EnsureRange(freq, 8, 19000);

    cut := P.Cutoff * CutoffMul * Power(2, P.FilterEnv * Exp(-V.T / Max(0.001, P.FilterDecay)) + P.LfoCutoff * V.Lfo);
    cut := EnsureRange(cut, 20, SAMPLE_RATE * 0.45);
    g := Tan(Pi * cut / SAMPLE_RATE);
    V.K := 2 - 2 * EnsureRange(P.Resonance, 0, 0.97);
    V.A1 := 1 / (1 + g * (g + V.K));
    V.A2 := g * V.A1;
    V.A3 := g * V.A2;
    V.CoefCount := CTRL;
  end;
  Dec(V.CoefCount);
  freq := V.Freq;

  { oscillators }
  dPh := freq * DT;
  V.Ph1 := V.Ph1 + dPh;
  if V.Ph1 >= 1 then V.Ph1 := V.Ph1 - Trunc(V.Ph1);
  x := Osc(P.Wave, V.Ph1, dPh, V.Rnd);
  if (P.Detune > 0) and (P.Wave <> 4) then
  begin
    f2 := freq * (1 + P.Detune * 0.000577623);       { 2^(c/1200) ~ 1 + c*ln2/1200 }
    V.Ph2 := V.Ph2 + f2 * DT;
    if V.Ph2 >= 1 then V.Ph2 := V.Ph2 - Trunc(V.Ph2);
    x := 0.5 * (x + Osc(P.Wave, V.Ph2, f2 * DT, V.Rnd));
  end;
  if P.NoiseMix > 0 then
    x := x * (1 - P.NoiseMix) + P.NoiseMix * Osc(4, 0, 0, V.Rnd);
  if P.SubLevel > 0 then
  begin
    V.PhSub := V.PhSub + dPh * 0.5;
    if V.PhSub >= 1 then V.PhSub := V.PhSub - Trunc(V.PhSub);
    x := x + P.SubLevel * Sin(2 * Pi * V.PhSub);
  end;

  { filter (TPT state-variable) }
  if not ((P.FilterType = 0) and (P.Cutoff >= 17999) and (P.FilterEnv = 0) and (P.LfoCutoff = 0) and (CutoffMul >= 1)) then
  begin
    v3 := x - V.Ic2;
    v1 := V.A1 * V.Ic1 + V.A2 * v3;
    v2 := V.Ic2 + V.A2 * V.Ic1 + V.A3 * v3;
    V.Ic1 := 2 * v1 - V.Ic1;
    V.Ic2 := 2 * v2 - V.Ic2;
    case P.FilterType of
      0: x := v2;
      1: x := x - V.K * v1 - v2;
    else
      x := v1;
    end;
  end;

  { drive }
  if P.Drive > 1.01 then
    x := Tanh(x * P.Drive) / Tanh(P.Drive);

  { bit crush / sample hold }
  if P.Downsample > 1 then
  begin
    if V.HoldCount <= 0 then
    begin
      V.Hold := x;
      V.HoldCount := P.Downsample;
    end;
    Dec(V.HoldCount);
    x := V.Hold;
  end;
  if P.Crush > 0 then
  begin
    levels := Power(2, P.Crush - 1);
    x := Round(x * levels) / levels;
  end;

  { amp envelope }
  if V.Gate then
  begin
    if V.T < P.Attack then env := V.T / P.Attack
    else env := P.Sustain + (1 - P.Sustain) * Exp(-(V.T - P.Attack) * 5 / Max(0.001, P.Decay));
    if (P.Sustain <= 0) and (V.T >= P.Attack) and (env < 0.0003) then V.Active := False;
  end
  else
  begin
    env := V.EnvRel * Exp(-V.TRel * 5 / Max(0.001, P.Release));
    V.TRel := V.TRel + DT;
    if env < 0.0003 then V.Active := False;
  end;
  V.Env := env;
  if P.LfoAmp > 0 then env := env * (1 - P.LfoAmp * (0.5 + 0.5 * V.Lfo));

  V.T := V.T + DT;
  Result := x * env * P.Volume * V.Vel;
end;

{ ---------------- SFX ---------------- }

function DefaultSfx(const AName: string): TSfxDef;
begin
  Result := Default(TSfxDef);
  Result.Name := AName;
  Result.A := DefaultSynth;
  Result.B := DefaultSynth;
  Result.B.Wave := 0;
  Result.B.BaseNote := 33;
  Result.UseB := False;
  Result.EchoTime := 0.18;
  Result.EchoFeedback := 0.35;
  Result.EchoMix := 0;
  Result.Gain := 1;
end;

procedure DescribeSfx(var B: TPBuilder; var S: TSfxDef);
begin
  B.G('Sound');
  B.S('name', 'Name', @S.Name);
  B.F('gain', 'Gain', @S.Gain, 0, 3, 2);
  B.F('echoMix', 'Echo mix', @S.EchoMix, 0, 1, 2);
  B.F('echoTime', 'Echo time (s)', @S.EchoTime, 0.02, 1, 3);
  B.F('echoFb', 'Echo feedback', @S.EchoFeedback, 0, 0.9, 2);
  B.B('useB', 'Use layer B (bass layer)', @S.UseB);
  B.G('A: ');
  DescribeSynth(B, S.A, 'a.');
  B.G('B: ');
  DescribeSynth(B, S.B, 'b.');
end;

function RenderLayer(const P: TSynthParams; out Buf: TSampleBuf): Integer;
var
  v: TVoice;
  n, i: Integer;
begin
  n := Round((P.Duration + P.Release * 1.5 + P.Attack + 0.02) * SAMPLE_RATE);
  n := EnsureRange(n, 64, SAMPLE_RATE * 6);
  SetLength(Buf, n);
  v := Default(TVoice);
  v.Rnd := 2463534242;
  VoiceStart(v, P.BaseNote, 1, P.Duration);
  for i := 0 to n - 1 do
  begin
    Buf[i] := VoiceSample(v, P, 120, 1, 1);
    if not v.Active then
    begin
      SetLength(Buf, i + 1);
      Break;
    end;
  end;
  Result := Length(Buf);
end;

function RenderSfx(const S: TSfxDef): TSampleBuf;
var
  a, b: TSampleBuf;
  n, i, d, tail: Integer;
  peak: Single;
begin
  RenderLayer(S.A, a);
  n := Length(a);
  if S.UseB then
  begin
    RenderLayer(S.B, b);
    n := Max(n, Length(b));
  end;
  tail := 0;
  if S.EchoMix > 0 then
    tail := Round(S.EchoTime * SAMPLE_RATE * Min(12, Ln(0.01) / Ln(Max(0.05, S.EchoFeedback))));
  SetLength(Result, Min(n + tail, SAMPLE_RATE * 8));
  for i := 0 to High(Result) do
  begin
    Result[i] := 0;
    if i < Length(a) then Result[i] := a[i];
    if S.UseB and (i < Length(b)) then Result[i] := Result[i] + b[i];
  end;
  if S.EchoMix > 0 then
  begin
    d := Max(1, Round(S.EchoTime * SAMPLE_RATE));
    for i := d to High(Result) do
      Result[i] := Result[i] + Result[i - d] * S.EchoFeedback * S.EchoMix * 1.5;
  end;
  peak := 0;
  for i := 0 to High(Result) do
  begin
    Result[i] := Result[i] * S.Gain;
    peak := Max(peak, Abs(Result[i]));
  end;
  { soft limit anything hotter than full scale }
  if peak > 1 then
    for i := 0 to High(Result) do
      Result[i] := Tanh(Result[i]);
end;

function FindSfx(const Bank: TSfxDefs; const AName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(Bank) do
    if SameText(Bank[i].Name, AName) then Exit(i);
  Result := -1;
end;

procedure SaveSfxBank(const AFile: string; const Bank: TSfxDefs);
var
  ini: TMemIniFile;
  i: Integer;
  b: TPBuilder;
  tmp: TSfxDef;
begin
  ForceDirectories(ExtractFilePath(AFile));
  ini := TMemIniFile.Create(AFile);
  try
    ini.Clear;
    ini.WriteInteger('Bank', 'Count', Length(Bank));
    for i := 0 to High(Bank) do
    begin
      tmp := Bank[i];
      b.Clear;
      DescribeSfx(b, tmp);
      WriteDescs(ini, 'Sfx' + IntToStr(i), b.List);
    end;
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

function LoadSfxBank(const AFile: string): TSfxDefs;
var
  ini: TMemIniFile;
  i, n: Integer;
  b: TPBuilder;
begin
  Result := nil;
  if not FileExists(AFile) then Exit;
  ini := TMemIniFile.Create(AFile);
  try
    n := ini.ReadInteger('Bank', 'Count', 0);
    SetLength(Result, n);
    for i := 0 to n - 1 do
    begin
      Result[i] := DefaultSfx('sfx' + IntToStr(i));
      b.Clear;
      DescribeSfx(b, Result[i]);
      ReadDescs(ini, 'Sfx' + IntToStr(i), b.List);
    end;
  finally
    ini.Free;
  end;
end;

{ Heavy-bass default bank. Layer A = character, layer B = sub / thump. }
function DefaultSfxBank: TSfxDefs;

  procedure Add(const S: TSfxDef);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := S;
  end;

  function Kick(ANote, AEnv, ADecay, ADrive: Single): TSynthParams;
  begin
    Result := DefaultSynth;
    Result.Wave := 0;
    Result.BaseNote := ANote;
    Result.PitchEnv := AEnv;
    Result.PitchDecay := 0.045;
    Result.Decay := ADecay;
    Result.Duration := ADecay;
    Result.Release := ADecay * 0.5;
    Result.Drive := ADrive;
    Result.SubLevel := 0.3;
    Result.Volume := 1.0;
  end;

var
  s: TSfxDef;
begin
  Result := nil;

  s := DefaultSfx('collect');
  s.A.Wave := 2; s.A.BaseNote := 81; s.A.Decay := 0.14; s.A.Duration := 0.12; s.A.Arp := '0 7 12';
  s.A.ArpRate := 28; s.A.Cutoff := 5000; s.A.FilterEnv := 1.5; s.A.FilterDecay := 0.08; s.A.Volume := 0.32;
  s.UseB := True; s.B := Kick(45, 18, 0.16, 2.5); s.B.Volume := 0.75;
  Add(s);

  s := DefaultSfx('collect_hi');
  s.A.Wave := 1; s.A.Detune := 14; s.A.BaseNote := 88; s.A.Decay := 0.2; s.A.Duration := 0.16;
  s.A.Arp := '0 4 7 12 16'; s.A.ArpRate := 34; s.A.Cutoff := 7000; s.A.Volume := 0.28;
  s.UseB := True; s.B := Kick(40, 24, 0.22, 3); s.B.Volume := 0.85;
  s.EchoMix := 0.35; s.EchoTime := 0.107;
  Add(s);

  s := DefaultSfx('prism');
  s.A.Wave := 3; s.A.BaseNote := 84; s.A.Decay := 0.35; s.A.Duration := 0.3; s.A.Arp := '0 12 7 19';
  s.A.ArpRate := 22; s.A.Volume := 0.4; s.EchoMix := 0.4;
  s.UseB := True; s.B := Kick(38, 24, 0.3, 3);
  Add(s);

  s := DefaultSfx('hit');
  s.A.Wave := 4; s.A.FilterType := 0; s.A.Cutoff := 900; s.A.FilterEnv := 3; s.A.FilterDecay := 0.15;
  s.A.Decay := 0.45; s.A.Duration := 0.35; s.A.Drive := 6; s.A.Volume := 0.7;
  s.UseB := True; s.B := Kick(31, 30, 0.7, 6); s.B.Volume := 1.1;
  s.Gain := 1.1;
  Add(s);

  s := DefaultSfx('pulse');
  s.A := Kick(28, 36, 1.4, 4); s.A.PitchDecay := 0.12; s.A.SubLevel := 0.6; s.A.Volume := 1.1;
  s.UseB := True; s.B.Wave := 4; s.B.FilterType := 2; s.B.Cutoff := 3000; s.B.Resonance := 0.6;
  s.B.FilterEnv := -4; s.B.FilterDecay := 0.6; s.B.Decay := 0.9; s.B.Duration := 0.6; s.B.Volume := 0.45;
  Add(s);

  s := DefaultSfx('shield');
  s.A.Wave := 1; s.A.Detune := 25; s.A.BaseNote := 57; s.A.Slide := 24; s.A.Attack := 0.02; s.A.Decay := 0.6;
  s.A.Duration := 0.5; s.A.Cutoff := 800; s.A.FilterEnv := 3; s.A.FilterDecay := 0.5; s.A.Volume := 0.45;
  s.UseB := True; s.B := Kick(33, 12, 0.6, 2); s.EchoMix := 0.3;
  Add(s);

  s := DefaultSfx('magnet');
  s.A.Wave := 0; s.A.BaseNote := 45; s.A.LfoRate := 14; s.A.LfoPitch := 3; s.A.Decay := 0.8; s.A.Duration := 0.6;
  s.A.Drive := 5; s.A.SubLevel := 0.5; s.A.Volume := 0.8;
  Add(s);

  s := DefaultSfx('slowmo');
  s.A.Wave := 1; s.A.BaseNote := 64; s.A.Slide := -30; s.A.Duration := 0.9; s.A.Decay := 1.2; s.A.Sustain := 0.4;
  s.A.Cutoff := 1500; s.A.Resonance := 0.5; s.A.Volume := 0.45;
  s.UseB := True; s.B := Kick(36, 0, 1.2, 3); s.B.Slide := -10;
  Add(s);

  s := DefaultSfx('double');
  s.A.Wave := 2; s.A.BaseNote := 76; s.A.Arp := '0 0 12 12'; s.A.ArpRate := 16; s.A.Decay := 0.4;
  s.A.Duration := 0.3; s.A.Crush := 6; s.A.Volume := 0.35;
  s.UseB := True; s.B := Kick(36, 24, 0.3, 4);
  Add(s);

  s := DefaultSfx('life');
  s.A.Wave := 3; s.A.BaseNote := 72; s.A.Arp := '0 4 7 12 16 19 24'; s.A.ArpRate := 18; s.A.Decay := 0.7;
  s.A.Duration := 0.5; s.A.Volume := 0.45; s.EchoMix := 0.45;
  s.UseB := True; s.B := Kick(33, 12, 0.5, 2);
  Add(s);

  s := DefaultSfx('star');
  s.A.Wave := 1; s.A.Detune := 18; s.A.BaseNote := 69; s.A.Arp := '0 7 12 19 24'; s.A.ArpRate := 24;
  s.A.Decay := 0.6; s.A.Duration := 0.4; s.A.Cutoff := 6000; s.A.Volume := 0.35; s.EchoMix := 0.5;
  s.UseB := True; s.B := Kick(29, 36, 0.9, 5);
  Add(s);

  s := DefaultSfx('fever');
  s.A.Wave := 1; s.A.Detune := 30; s.A.BaseNote := 45; s.A.Slide := 36; s.A.Duration := 1.0; s.A.Decay := 1.2;
  s.A.Sustain := 0.6; s.A.Cutoff := 400; s.A.FilterEnv := 5; s.A.FilterDecay := 1.0; s.A.Resonance := 0.6;
  s.A.Drive := 4; s.A.Volume := 0.5;
  s.UseB := True; s.B := Kick(28, 40, 1.4, 6);
  Add(s);

  s := DefaultSfx('nova');
  s.A.Wave := 4; s.A.Cutoff := 300; s.A.FilterEnv := 6; s.A.FilterDecay := 0.3; s.A.Decay := 1.4;
  s.A.Duration := 1.0; s.A.Crush := 5; s.A.Downsample := 4; s.A.Volume := 0.8;
  s.UseB := True; s.B := Kick(26, 40, 1.6, 8); s.B.Volume := 1.1;
  Add(s);

  s := DefaultSfx('levelup');
  s.A.Wave := 1; s.A.Detune := 22; s.A.BaseNote := 57; s.A.Slide := 18; s.A.Duration := 1.1; s.A.Attack := 0.3;
  s.A.Decay := 1.5; s.A.Sustain := 0.7; s.A.Cutoff := 300; s.A.FilterEnv := 0; s.A.LfoRate := 0.4;
  s.A.LfoCutoff := 4; s.A.Volume := 0.4;
  s.UseB := True; s.B := Kick(28, 36, 1.2, 5); s.EchoMix := 0.3;
  Add(s);

  s := DefaultSfx('complete');
  s.A.Wave := 1; s.A.Detune := 16; s.A.BaseNote := 69; s.A.Arp := '0 4 7 11 12 16 19 24'; s.A.ArpRate := 12;
  s.A.Duration := 1.2; s.A.Decay := 1.6; s.A.Sustain := 0.5; s.A.Cutoff := 5000; s.A.Volume := 0.35; s.EchoMix := 0.5;
  s.UseB := True; s.B := Kick(33, 24, 1.5, 4);
  Add(s);

  s := DefaultSfx('gameover');
  s.A := Kick(40, 0, 2.0, 6); s.A.Slide := -14; s.A.Duration := 1.6; s.A.SubLevel := 0.8;
  s.UseB := True; s.B.Wave := 4; s.B.Cutoff := 600; s.B.FilterEnv := -3; s.B.FilterDecay := 1.5;
  s.B.Decay := 1.8; s.B.Duration := 1.4; s.B.Volume := 0.4;
  Add(s);

  s := DefaultSfx('combo');
  s.A.Wave := 2; s.A.BaseNote := 79; s.A.Arp := '0 12'; s.A.ArpRate := 30; s.A.Decay := 0.25; s.A.Duration := 0.2;
  s.A.Volume := 0.3; s.A.Crush := 7;
  s.UseB := True; s.B := Kick(31, 30, 0.5, 5);
  Add(s);

  s := DefaultSfx('block');
  s.A.Wave := 3; s.A.BaseNote := 60; s.A.PitchEnv := 12; s.A.PitchDecay := 0.03; s.A.Decay := 0.3;
  s.A.Duration := 0.2; s.A.Drive := 3; s.A.Volume := 0.5;
  s.UseB := True; s.B := Kick(36, 18, 0.3, 3);
  Add(s);

  s := DefaultSfx('menu_move');
  s.A.Wave := 3; s.A.BaseNote := 86; s.A.Decay := 0.05; s.A.Duration := 0.03; s.A.Crush := 6; s.A.Volume := 0.25;
  s.UseB := True; s.B := Kick(48, 12, 0.08, 1.5); s.B.Volume := 0.5;
  Add(s);

  s := DefaultSfx('menu_select');
  s.A.Wave := 1; s.A.Detune := 12; s.A.BaseNote := 69; s.A.Arp := '0 7 12'; s.A.ArpRate := 26;
  s.A.Decay := 0.3; s.A.Duration := 0.15; s.A.Cutoff := 4000; s.A.Volume := 0.3;
  s.UseB := True; s.B := Kick(33, 30, 0.45, 4);
  Add(s);

  s := DefaultSfx('pause');
  s.A := Kick(36, -12, 0.4, 2); s.A.Slide := -20; s.A.Volume := 0.7;
  Add(s);

  s := DefaultSfx('beam');
  s.A.Wave := 1; s.A.Detune := 24; s.A.BaseNote := 57; s.A.Slide := 30; s.A.Attack := 0.01; s.A.Duration := 0.7;
  s.A.Decay := 1.0; s.A.Sustain := 0.5; s.A.Cutoff := 600; s.A.FilterEnv := 4; s.A.FilterDecay := 0.6;
  s.A.Resonance := 0.55; s.A.Arp := '0 7 12 19'; s.A.ArpRate := 24; s.A.Volume := 0.38;
  s.UseB := True; s.B := Kick(28, 40, 1.2, 6); s.B.SubLevel := 0.6;
  s.EchoMix := 0.45; s.EchoTime := 0.16;
  Add(s);

  s := DefaultSfx('charge');
  s.A.Wave := 3; s.A.BaseNote := 60; s.A.Decay := 0.09; s.A.Duration := 0.06; s.A.Volume := 0.22;
  s.UseB := True; s.B := Kick(40, 6, 0.1, 2); s.B.Volume := 0.45;
  Add(s);

  s := DefaultSfx('grate_fire');
  s.A.Wave := 1; s.A.Detune := 30; s.A.BaseNote := 76; s.A.Slide := -40; s.A.Duration := 0.5; s.A.Decay := 0.8;
  s.A.Cutoff := 9000; s.A.FilterEnv := -3; s.A.FilterDecay := 0.5; s.A.Arp := '0 12 7 19 24'; s.A.ArpRate := 30;
  s.A.Volume := 0.4;
  s.UseB := True; s.B := Kick(26, 44, 1.3, 7); s.B.SubLevel := 0.7; s.B.Volume := 1.1;
  s.EchoMix := 0.4; s.EchoTime := 0.12;
  Add(s);

  s := DefaultSfx('ready');
  s.A.Wave := 2; s.A.BaseNote := 72; s.A.Decay := 0.18; s.A.Duration := 0.1; s.A.Crush := 5; s.A.Volume := 0.3;
  s.UseB := True; s.B := Kick(36, 20, 0.25, 3);
  Add(s);
end;

procedure WriteWav(const AFile: string; const Samples: array of Single; AChannels: Integer);
var
  fs: TFileStream;
  dataBytes, i: Integer;
  s16: SmallInt;

  procedure W4(V: LongWord); begin fs.WriteBuffer(V, 4); end;
  procedure W2(V: Word); begin fs.WriteBuffer(V, 2); end;
  procedure Tag(const T: string); begin fs.WriteBuffer(T[1], 4); end;

begin
  dataBytes := Length(Samples) * 2;
  fs := TFileStream.Create(AFile, fmCreate);
  try
    Tag('RIFF'); W4(36 + dataBytes); Tag('WAVE');
    Tag('fmt '); W4(16); W2(1); W2(AChannels); W4(SAMPLE_RATE);
    W4(SAMPLE_RATE * AChannels * 2); W2(AChannels * 2); W2(16);
    Tag('data'); W4(dataBytes);
    for i := 0 to High(Samples) do
    begin
      s16 := Round(EnsureRange(Samples[i], -1, 1) * 32767);
      fs.WriteBuffer(s16, 2);
    end;
  finally
    fs.Free;
  end;
end;

end.
